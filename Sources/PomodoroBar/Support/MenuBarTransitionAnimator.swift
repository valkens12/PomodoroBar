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
/// The animation itself is a squash-and-pop bounce with a decaying wiggle,
/// while the tomato body crossfades from the outgoing phase's colors to the
/// incoming ones. With Reduce Motion on, the bounce and wiggle are dropped
/// and only a quick color fade remains.
@Observable
@MainActor
final class MenuBarTransitionAnimator {

  /// Normalized animation time, 0...1 while a transition is playing, `nil`
  /// when idle. Views read the derived `scale` / `wiggleDegrees` / `stops`
  /// instead of interpreting this directly.
  private(set) var progress: Double?

  @ObservationIgnored private var fromBright: Color = .clear
  @ObservationIgnored private var fromDeep: Color = .clear
  @ObservationIgnored private var reduceMotion = false
  @ObservationIgnored private var frameTimer: Timer?
  @ObservationIgnored private var startDate = Date()

  private static let frameInterval: TimeInterval = 1.0 / 30.0
  private static let duration: TimeInterval = 0.9
  private static let reducedMotionDuration: TimeInterval = 0.35

  var isAnimating: Bool {
    progress != nil
  }

  /// Current bounce scale for the tomato image; 1 when idle or when the user
  /// prefers reduced motion.
  var scale: Double {
    guard let progress, !reduceMotion else { return 1 }
    return Self.popScale(at: progress)
  }

  /// Current wiggle rotation in degrees; 0 when idle or under Reduce Motion.
  var wiggleDegrees: Double {
    guard let progress, !reduceMotion else { return 0 }
    return Self.wiggleDegrees(at: progress)
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
  /// where no SwiftUI environment is available).
  func beginPhaseTransition(from oldPhase: PomodoroTimer.Phase) {
    begin(
      from: Theme.bodyStops(for: oldPhase),
      reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
    )
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
      // All tracks end exactly at their resting values (scale 1, wiggle 0,
      // blend 1), so snapping back to the steady rendering is seamless.
      frameTimer?.invalidate()
      frameTimer = nil
      progress = nil
      return
    }
    progress = elapsed / duration
  }

  // MARK: - Animation Curves

  /// Squash-and-pop scale track: a quick anticipatory squash, an overshooting
  /// pop, a small undershoot, and a settle back to 1. Pure function of
  /// normalized time so it can be unit-tested.
  nonisolated static func popScale(at t: Double) -> Double {
    interpolate(
      t,
      keyframes: [
        (0.00, 1.00),
        (0.15, 0.84),
        (0.45, 1.16),
        (0.72, 0.96),
        (1.00, 1.00),
      ]
    )
  }

  /// Decaying side-to-side wiggle, in degrees. Zero at both endpoints.
  nonisolated static func wiggleDegrees(at t: Double) -> Double {
    let clamped = min(max(t, 0), 1)
    return sin(clamped * .pi * 3) * (1 - clamped) * 7
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
