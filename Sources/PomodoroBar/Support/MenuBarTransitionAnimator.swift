import AppKit
import SwiftUI

/// Drives the menu bar tomato's phase-change animation frame by frame.
///
/// `MenuBarExtra` renders its label into an `NSStatusItem`, which re-renders
/// on state change but does not run implicit SwiftUI animations — so the
/// transition is animated the only way that reliably works there: an
/// observable `progress` value stepped by a foreground `Timer`, with the
/// label re-rendering each frame.
///
/// The animation itself is a pop-and-settle bounce — no rotation, and no
/// anticipatory squash before the pop either, both of which read as a
/// mechanical shake/twitch rather than an Apple-like spring at this size —
/// while the tomato body crossfades from the outgoing phase's colors to the
/// incoming ones. With Reduce Motion on, the bounce is dropped and only a
/// quick color fade remains.
///
/// On a *natural* phase completion (as opposed to a manual skip) the animator
/// enters an alarm state via `beginAlarm`: it nudges the tomato in periodic
/// bursts — one bounce, then a few seconds of calm, repeating — and re-plays
/// the chime for the first several bursts, until the popover opens and calls
/// `acknowledgeAlarm`. The 30fps frame timer only runs during a burst; between
/// bursts a single one-shot timer waits out the calm, so idle cost is ~nil.
@Observable
@MainActor
final class MenuBarTransitionAnimator {

  /// Normalized animation time, 0...1 while a transition is playing, `nil`
  /// when idle. Views read the derived `scale` / `stops` instead of
  /// interpreting this directly.
  private(set) var progress: Double?

  /// True from a natural phase completion until the popover acknowledges it.
  /// Drives the label's static attention cue (so the signal survives Reduce
  /// Motion) and gates the popover's flip-to-message on open.
  private(set) var isAlarming = false

  /// The phase being entered, so the popover can word its message. Set when
  /// an alarm begins; read by the popover before it calls `acknowledgeAlarm`.
  private(set) var pendingMessagePhase: PomodoroTimer.Phase?

  /// Invoked at the start of each audible burst with the incoming phase, so
  /// the app layer can play the matching chime. Kept as a callback to keep
  /// this type free of `AppSettings` / `SoundManager`.
  @ObservationIgnored var onNudge: ((PomodoroTimer.Phase) -> Void)?

  @ObservationIgnored private var fromBright: Color = .clear
  @ObservationIgnored private var fromDeep: Color = .clear
  @ObservationIgnored private var reduceMotion = false
  @ObservationIgnored private var frameTimer: Timer?
  @ObservationIgnored private var startDate = Date()

  // Alarm state.
  @ObservationIgnored private var calmTimer: Timer?
  @ObservationIgnored private var alarmIncomingPhase: PomodoroTimer.Phase?
  @ObservationIgnored private var alarmOutgoingStops: (bright: Color, deep: Color) = (.clear, .clear)
  @ObservationIgnored private var alarmIncomingStops: (bright: Color, deep: Color) = (.clear, .clear)
  @ObservationIgnored private var nudgeIndex = 0

  private static let frameInterval: TimeInterval = 1.0 / 30.0
  private static let duration: TimeInterval = 0.9
  private static let reducedMotionDuration: TimeInterval = 0.35

  /// Quiet gap between the end of one nudge and the start of the next.
  private static let calmSeconds: TimeInterval = 4.0

  /// The chime re-plays for this many bursts, then the tomato keeps nudging
  /// silently until acknowledged — insistent, without becoming noise.
  nonisolated static let maxAudibleNudges = 6

  var isAnimating: Bool {
    progress != nil
  }

  /// Current bounce scale for the tomato image; 1 when idle or when the user
  /// prefers reduced motion.
  var scale: Double {
    guard let progress, !reduceMotion else { return 1 }
    return Self.popScale(at: progress)
  }

  /// The tomato-body gradient stops to render right now: the outgoing colors
  /// blended toward `target` by the animation's color track, or `target`
  /// itself when no transition is playing.
  func stops(
    target: (bright: Color, deep: Color)
  ) -> (bright: Color, deep: Color) {
    guard let progress else { return target }
    let blend = reduceMotion ? progress : Self.colorBlend(at: progress)
    return (
      bright: Theme.mix(fromBright, target.bright, by: blend),
      deep: Theme.mix(fromDeep, target.deep, by: blend)
    )
  }

  /// Starts (or restarts) the phase-change transition, departing from the
  /// given phase's body colors. Honors the system Reduce Motion setting
  /// (read from `NSWorkspace` — this is triggered from the model layer,
  /// where no SwiftUI environment is available). Used for manual skips: a
  /// single one-shot bounce, no sustained alarm.
  func beginPhaseTransition(from oldPhase: PomodoroTimer.Phase) {
    begin(
      from: Theme.bodyStops(for: oldPhase),
      reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
    )
  }

  /// Begins the sustained attention alarm for a natural phase completion:
  /// nudge now, then keep nudging in bursts until `acknowledgeAlarm`. Restarts
  /// cleanly if an earlier alarm is still ringing (e.g. an auto-started break
  /// rolled into focus before the user looked).
  func beginAlarm(from outgoing: PomodoroTimer.Phase, to incoming: PomodoroTimer.Phase) {
    frameTimer?.invalidate()
    frameTimer = nil
    calmTimer?.invalidate()
    calmTimer = nil

    alarmIncomingPhase = incoming
    alarmOutgoingStops = Theme.bodyStops(for: outgoing)
    alarmIncomingStops = Theme.bodyStops(for: incoming)
    reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    nudgeIndex = 0
    isAlarming = true
    pendingMessagePhase = incoming

    startBurst()
  }

  /// Stops the alarm — invoked when the popover opens (clicking the tomato is
  /// the only way to silence it). The popover reads `pendingMessagePhase`
  /// first, then calls this.
  func acknowledgeAlarm() {
    guard isAlarming else { return }
    frameTimer?.invalidate()
    frameTimer = nil
    calmTimer?.invalidate()
    calmTimer = nil
    progress = nil
    isAlarming = false
  }

  /// Fires one nudge: chime (for the first several bursts) plus a bounce. The
  /// first burst crossfades from the outgoing colors; later bursts stay on the
  /// incoming color, so only the bounce reads.
  private func startBurst() {
    guard isAlarming, let incoming = alarmIncomingPhase else { return }
    if Self.shouldChime(nudgeIndex: nudgeIndex) {
      onNudge?(incoming)
    }
    let from = nudgeIndex == 0 ? alarmOutgoingStops : alarmIncomingStops
    nudgeIndex += 1
    begin(from: from, reduceMotion: reduceMotion)
  }

  /// Schedules the next burst after the calm gap. One-shot timer in `.common`
  /// mode so it still fires while the popover has the run loop.
  private func scheduleNextBurst() {
    calmTimer?.invalidate()
    let timer = Timer(timeInterval: Self.calmSeconds, repeats: false) {
      [weak self] _ in
      MainActor.assumeIsolated {
        self?.startBurst()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    calmTimer = timer
  }

  /// Whether the chime plays on the burst at this (zero-based) index.
  nonisolated static func shouldChime(nudgeIndex: Int) -> Bool {
    nudgeIndex >= 0 && nudgeIndex < maxAudibleNudges
  }

  /// Starts (or restarts) a transition from the given outgoing body colors.
  func begin(
    from: (bright: Color, deep: Color),
    reduceMotion: Bool,
  ) {
    frameTimer?.invalidate()
    fromBright = from.bright
    fromDeep = from.deep
    self.reduceMotion = reduceMotion
    startDate = Date()
    progress = 0

    // `.common` mode so the animation keeps stepping while the popover or a
    // menu has the run loop in event-tracking mode (same reason the tick
    // timer uses it).
    let timer = Timer(timeInterval: Self.frameInterval, repeats: true) {
      [weak self] _ in
      MainActor.assumeIsolated {
        self?.step()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    frameTimer = timer
  }

  private func step() {
    let duration = reduceMotion ? Self.reducedMotionDuration : Self.duration
    let elapsed = Date().timeIntervalSince(startDate)
    guard elapsed < duration else {
      // All tracks end exactly at their resting values (scale 1, blend 1), so
      // snapping back to the steady rendering is seamless.
      frameTimer?.invalidate()
      frameTimer = nil
      progress = nil
      // Mid-alarm: wait out the calm gap, then nudge again.
      if isAlarming {
        scheduleNextBurst()
      }
      return
    }
    progress = elapsed / duration
  }

  // MARK: - Animation Curves

  /// Pop-and-settle scale track: rises straight into an overshooting pop, a
  /// small undershoot, and a settle back to 1 — no anticipatory squash before
  /// the rise starts, which at menu-bar size read as a twitch rather than a
  /// spring. Pure function of normalized time so it can be unit-tested.
  nonisolated static func popScale(at t: Double) -> Double {
    interpolate(
      t,
      keyframes: [
        (0.00, 1.00),
        (0.45, 1.16),
        (0.72, 0.96),
        (1.00, 1.00),
      ]
    )
  }

  /// Color crossfade track: eases from 0 to 1 over the first 60% of the
  /// animation, so the new phase color has fully arrived by the time the
  /// bounce settles.
  nonisolated static func colorBlend(at t: Double) -> Double {
    let clamped = min(max(t, 0), 1)
    let colorPhaseEnd = 0.6
    return smoothstep(min(clamped / colorPhaseEnd, 1))
  }

  /// Piecewise interpolation through `keyframes` (time, value) pairs, with a
  /// smoothstep ease inside each segment. Times must be ascending and span
  /// 0...1.
  private nonisolated static func interpolate(
    _ t: Double,
    keyframes: [(time: Double, value: Double)],
  ) -> Double {
    guard let first = keyframes.first, let last = keyframes.last else {
      return 1
    }
    if t <= first.time { return first.value }
    if t >= last.time { return last.value }
    for index in 1..<keyframes.count {
      let previous = keyframes[index - 1]
      let next = keyframes[index]
      if t <= next.time {
        let segment = (t - previous.time) / (next.time - previous.time)
        return previous.value
          + (next.value - previous.value) * smoothstep(segment)
      }
    }
    return last.value
  }

  private nonisolated static func smoothstep(_ x: Double) -> Double {
    x * x * (3 - 2 * x)
  }
}
