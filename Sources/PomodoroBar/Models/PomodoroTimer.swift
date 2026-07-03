import Combine
import Foundation
import SwiftUI

/// The core Pomodoro timer state machine.
///
/// `@MainActor` + `@Observable` so SwiftUI views can observe it directly.
/// Ticking is driven by a Combine `Timer.publish` publisher on the main run
/// loop in `.common` mode (so it keeps ticking while the menu is open).
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
        return "Focus"
      case .shortBreak:
        return "Short Break"
      case .longBreak:
        return "Long Break"
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
  var remainingSeconds: Int
  var completedFocusSessions: Int

  /// Bumped every time a focus session completes. Views observe this via
  /// `.onChange` to trigger a one-shot completion animation; the value
  /// itself carries no meaning beyond "something changed."
  private(set) var focusCompletionTick: Int = 0

  @ObservationIgnored private var cancellable: AnyCancellable?

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
    self.remainingSeconds = settings.duration(for: .focus)
  }

  // MARK: - Derived Properties

  var totalSeconds: Int {
    settings.duration(for: phase)
  }

  var progress: Double {
    let denominator = Double(max(totalSeconds, 1))
    return Double(remainingSeconds) / denominator
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
    remainingSeconds = totalSeconds
    focusGuard.setTimerRunning(false)
  }

  func skip() {
    // Deliberate user action — no notification for a transition they caused.
    advancePhase(notify: false)
  }

  // MARK: - Ticker

  private func startTicker() {
    // Guard against double subscriptions.
    cancellable?.cancel()
    cancellable = nil

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
  }

  // MARK: - Private Tick / Phase Advance

  private func tick() {
    guard runState == .running else { return }

    // Focus gating: hold the countdown (and the tick sound) while waiting for a
    // focus app to become frontmost. Run state is unchanged so the UI can show
    // a "paused — open a focus app" banner.
    if isWaitingForFocusApp {
      return
    }

    if settings.tickEnabled {
      SoundManager.playTick()
    }

    remainingSeconds -= 1

    if remainingSeconds <= 0 {
      remainingSeconds = 0
      advancePhase(notify: true)
    }
  }

  /// Moves to the next phase. `notify` is true only for natural completions
  /// (countdown reached zero) — manual skips stay silent.
  private func advancePhase(notify: Bool) {
    // Phase we are leaving.
    let leavingPhase = phase

    // Record a completed focus session *before* mutating phase, so the
    // statistics entry reflects the just-finished focus block at its configured
    // length.
    if leavingPhase == .focus {
      statistics.recordFocusCompletion(minutes: settings.focusMinutes)
      completedFocusSessions += 1
      focusCompletionTick += 1
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
    remainingSeconds = settings.duration(for: nextPhase)

    // Phase-change sound.
    if settings.soundEnabled {
      SoundManager.playPhaseChange()
    }

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

    if notify, settings.notificationsEnabled {
      NotificationManager.postPhaseChange(
        finished: leavingPhase,
        next: nextPhase,
        nextMinutes: settings.duration(for: nextPhase) / 60,
        autoStarted: shouldAutoStart,
      )
    }
  }

  // MARK: - Deinit

  deinit {
    // Releasing `cancellable` cancels the Combine subscription automatically
    // (AnyCancellable.cancel() runs in its own deinit), so no main-actor
    // access is needed here.
  }
}