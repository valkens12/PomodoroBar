import AppKit
import Combine
import Foundation
import SwiftUI

/// The core Pomodoro timer state machine.
///
/// `@MainActor` + `@Observable` so SwiftUI views can observe it directly.
/// Ticking is driven by a Combine `Timer.publish` publisher on the main run
/// loop in `.common` mode (so it keeps ticking while the menu is open), but
/// the countdown itself is wall-clock based: each tick subtracts the *real*
/// elapsed time since the previous tick (clamped, see `countableElapsed`),
/// so a stalled run loop or coalesced timer never silently stretches a
/// session.
///
/// System sleep pauses the session explicitly (`willSleepNotification` →
/// `pause()`) and resumes it on wake — time asleep never counts as focus
/// time, and the menu bar shows the dimmed/paused state for that span.
///
/// The countdown can be gated by `FocusGuard`: when focus gating is on and no
/// focus app is frontmost, `tick()` early-returns so the tomato pauses without
/// changing run state. Completed focus phases are recorded in `StatisticsStore`.
@Observable
@MainActor
final class PomodoroTimer {
  // MARK: - Phase

  enum Phase: String, CaseIterable, Identifiable {
    case focus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    var label: String {
      switch self {
      case .focus:
        return String(localized: "phase.focus", defaultValue: "Focus")
      case .shortBreak:
        return String(
          localized: "phase.shortBreak", defaultValue: "Short Break"
        )
      case .longBreak:
        return String(localized: "phase.longBreak", defaultValue: "Long Break")
      }
    }

    var systemImage: String {
      switch self {
      case .focus:
        return "brain.head.profile"
      case .shortBreak:
        return "cup.and.saucer"
      case .longBreak:
        return "leaf"
      }
    }
  }

  // MARK: - RunState

  enum RunState: String {
    case idle
    case running
    case paused
  }

  // MARK: - FocusWaitReason

  /// Why the countdown is currently held while `runState == .running`, so the
  /// UI can distinguish "wrong app entirely" from "right app (Safari), wrong
  /// tab" instead of a single undifferentiated "waiting" boolean.
  enum FocusWaitReason {
    case notWaiting
    case wrongApp
    case wrongTab
  }

  // MARK: - Stored Properties

  private let settings: AppSettings
  private let focusGuard: FocusGuard
  private let statistics: StatisticsStore

  var phase: Phase
  var runState: RunState
  var completedFocusSessions: Int

  /// Remaining time in the current phase, in seconds, as a continuous value.
  /// Stored as `TimeInterval` so wall-clock ticking can subtract fractional
  /// elapsed time without accumulating rounding drift; UI reads the derived
  /// `remainingSeconds` instead.
  private(set) var remainingTime: TimeInterval

  /// Bumped every time a focus session completes. Views observe this via
  /// `.onChange` to trigger a one-shot completion animation; the value
  /// itself carries no meaning beyond "something changed."
  private(set) var focusCompletionTick: Int = 0

  /// Invoked on every phase transition (natural completion or skip), after
  /// the new phase is in place. The menu bar label's phase-change animation
  /// hangs off this rather than `.onChange`, because a `MenuBarExtra` label
  /// never receives view lifecycle events — observation-driven re-renders
  /// work there, but `onChange`/`onAppear`/`task` never fire.
  @ObservationIgnored var onPhaseChange: ((_ from: Phase, _ to: Phase) -> Void)?

  @ObservationIgnored private var cancellable: AnyCancellable?

  /// Wall-clock timestamp of the previous tick, used to compute the real
  /// elapsed time each tick. Reset whenever the ticker (re)starts so the gap
  /// spent paused or idle is never counted.
  @ObservationIgnored private var lastTickDate: Date?

  /// True while the session was paused by `willSleepNotification` rather
  /// than the user, so `didWakeNotification` knows to resume it.
  @ObservationIgnored private var pausedForSleep = false

  @ObservationIgnored private var sleepObserverTokens: [NSObjectProtocol] = []

  // MARK: - Init

  init(
    settings: AppSettings,
    focusGuard: FocusGuard,
    statistics: StatisticsStore,
  ) {
    self.settings = settings
    self.focusGuard = focusGuard
    self.statistics = statistics
    self.phase = .focus
    self.runState = .idle
    self.completedFocusSessions = 0
    self.remainingTime = TimeInterval(settings.duration(for: .focus))
    startSleepMonitoring()
  }

  // MARK: - Derived Properties

  var totalSeconds: Int {
    settings.duration(for: phase)
  }

  /// Remaining whole seconds for display, rounded up so the countdown only
  /// shows 00:00 at the exact moment the phase flips (0.4s left reads 00:01).
  var remainingSeconds: Int {
    Int(remainingTime.rounded(.up))
  }

  var progress: Double {
    let denominator = Double(max(totalSeconds, 1))
    return remainingTime / denominator
  }

  var formattedRemaining: String {
    let total = max(remainingSeconds, 0)
    let minutes = total / 60
    let seconds = total % 60
    return String(format: "%02d:%02d", minutes, seconds)
  }

  var isRunning: Bool {
    runState == .running
  }

  /// True when the timer is notionally running but the countdown is suspended
  /// because no focus app is frontmost (or, for Safari, the wrong tab). UI
  /// surfaces a "paused" banner in this state.
  var isWaitingForFocusApp: Bool {
    focusWaitReason != .notWaiting
  }

  /// Why the countdown is currently held, if it is. See `FocusWaitReason`.
  var focusWaitReason: FocusWaitReason {
    guard runState == .running, focusGuard.enabled, !focusGuard.isFocusAppActive else {
      return .notWaiting
    }
    return focusGuard.isTabMismatch ? .wrongTab : .wrongApp
  }

  // MARK: - Public Actions

  func start() {
    guard runState != .running else { return }
    runState = .running
    startTicker()
    focusGuard.setTimerRunning(true)
  }

  func pause() {
    guard runState == .running else { return }
    runState = .paused
    stopTicker()
    focusGuard.setTimerRunning(false)
  }

  func resume() {
    guard runState == .paused else { return }
    runState = .running
    startTicker()
    focusGuard.setTimerRunning(true)
  }

  func toggleStartPause() {
    switch runState {
    case .idle, .paused:
      start()
    case .running:
      pause()
    }
  }

  func reset() {
    stopTicker()
    runState = .idle
    remainingTime = TimeInterval(totalSeconds)
    focusGuard.setTimerRunning(false)
  }

  func skip() {
    // Deliberate user action — no notification for a transition they caused,
    // no statistics credit for a session they abandoned.
    advancePhase(completedNaturally: false)
  }

  // MARK: - Ticker

  private func startTicker() {
    // Guard against double subscriptions.
    cancellable?.cancel()
    cancellable = nil

    lastTickDate = Date()
    cancellable = Timer
      .publish(every: 1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        MainActor.assumeIsolated {
          self?.tick()
        }
      }
  }

  private func stopTicker() {
    cancellable?.cancel()
    cancellable = nil
    lastTickDate = nil
  }

  // MARK: - Sleep / Wake

  /// System sleep must not count as focus time. Sleep pauses the session
  /// (visibly — dimmed menu bar, "Paused" in the popover if opened mid-nap)
  /// and wake resumes it, so a closed lid behaves like a deliberate pause
  /// instead of silently stretching the session.
  private func startSleepMonitoring() {
    let center = NSWorkspace.shared.notificationCenter
    let sleepToken = center.addObserver(
      forName: NSWorkspace.willSleepNotification,
      object: nil,
      queue: .main,
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.runState == .running else { return }
        self.pause()
        self.pausedForSleep = true
      }
    }
    let wakeToken = center.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main,
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.pausedForSleep else { return }
        self.pausedForSleep = false
        self.resume()
      }
    }
    sleepObserverTokens = [sleepToken, wakeToken]
  }

  // MARK: - Private Tick / Phase Advance

  /// The real elapsed time to subtract for a tick that observed `lastTick`
  /// as its predecessor. Clamped to [0, 2] seconds: a nil predecessor or a
  /// backwards clock counts a nominal 1s tick, and any longer gap (missed
  /// wake notification, suspended run loop) is capped so an unnoticed stall
  /// can never burn a large slice of the session in one tick.
  nonisolated static func countableElapsed(since lastTick: Date?, now: Date) -> TimeInterval {
    guard let lastTick else { return 1 }
    let elapsed = now.timeIntervalSince(lastTick)
    guard elapsed > 0 else { return 1 }
    return min(elapsed, 2)
  }

  private func tick() {
    guard runState == .running else { return }

    let now = Date()
    let elapsed = Self.countableElapsed(since: lastTickDate, now: now)
    lastTickDate = now

    // Focus gating: hold the countdown (and the tick sound) while waiting for a
    // focus app to become frontmost. Run state is unchanged so the UI can show
    // a "paused — open a focus app" banner.
    if isWaitingForFocusApp {
      return
    }

    if settings.tickEnabled {
      SoundManager.playTick()
    }

    remainingTime -= elapsed

    if remainingTime <= 0 {
      remainingTime = 0
      advancePhase(completedNaturally: true)
    }
  }

  /// Moves to the next phase. `completedNaturally` is true only when the
  /// countdown reached zero: natural completions notify, record statistics,
  /// and celebrate; manual skips advance the cycle silently and leave the
  /// abandoned session out of the history.
  private func advancePhase(completedNaturally: Bool) {
    // Phase we are leaving.
    let leavingPhase = phase

    if leavingPhase == .focus {
      // Record *before* mutating phase, so the statistics entry reflects the
      // just-finished focus block at its configured length. Skipped sessions
      // still advance the session dots (the long-break cadence stays
      // predictable) but earn no statistics and no celebration.
      if completedNaturally {
        statistics.recordFocusCompletion(minutes: settings.focusMinutes)
        focusCompletionTick += 1
      }
      completedFocusSessions += 1
    }

    // Determine the next phase.
    let nextPhase: Phase
    if leavingPhase == .focus {
      let isLongBreakDue =
        completedFocusSessions >= settings.sessionsBeforeLongBreak
      nextPhase = isLongBreakDue ? .longBreak : .shortBreak
    } else {
      // Finishing any break returns to focus.
      nextPhase = .focus
    }

    // If we just completed the long break, reset the focus-session counter so
    // a fresh cycle begins.
    if leavingPhase == .longBreak {
      completedFocusSessions = 0
    }

    phase = nextPhase
    remainingTime = TimeInterval(settings.duration(for: nextPhase))
    onPhaseChange?(leavingPhase, nextPhase)

    // Auto-start the next phase per user preferences.
    let shouldAutoStart: Bool
    switch nextPhase {
    case .focus:
      shouldAutoStart = settings.autoStartFocus
    case .shortBreak, .longBreak:
      shouldAutoStart = settings.autoStartBreaks
    }

    if shouldAutoStart {
      runState = .running
      startTicker()
    } else {
      stopTicker()
      runState = .idle
    }
    focusGuard.setTimerRunning(shouldAutoStart)

    // Sound routing: when a notification will be posted, the cue rides on the
    // notification itself (so it respects the user's per-app notification
    // sound preferences); the in-process NSSound is the fallback for
    // notification-less transitions.
    let willNotify =
      completedNaturally && settings.notificationsEnabled && NotificationManager.isSupported
    if settings.soundEnabled, !willNotify {
      SoundManager.playPhaseChange()
    }

    if willNotify {
      NotificationManager.postPhaseChange(
        finished: leavingPhase,
        next: nextPhase,
        nextMinutes: settings.duration(for: nextPhase) / 60,
        autoStarted: shouldAutoStart,
        withSound: settings.soundEnabled,
      )
    }
  }

  // MARK: - Deinit

  deinit {
    // Releasing `cancellable` cancels the Combine subscription automatically
    // (AnyCancellable.cancel() runs in its own deinit), so no main-actor
    // access is needed here. The sleep/wake observer closures capture self
    // weakly, so they can't keep a deallocated timer alive either — and in
    // practice the timer lives for the whole process anyway.
  }
}