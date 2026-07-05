import Foundation
import Testing

@testable import PomodoroBar

// MARK: - Phase-change animation curves

/// The menu bar phase-change animation snaps back to steady rendering the
/// frame after it finishes, so every track must end exactly at its resting
/// value — otherwise the last animated frame would visibly jump.

@Suite("Pop scale track")
struct PopScaleTests {
  @Test("rests at 1 on both endpoints so the handoff to steady rendering is seamless")
  func endpoints() {
    #expect(MenuBarTransitionAnimator.popScale(at: 0) == 1)
    #expect(MenuBarTransitionAnimator.popScale(at: 1) == 1)
  }

  @Test("rises straight toward the pop, no anticipatory dip below 1")
  func noAnticipation() {
    for step in stride(from: 0.0, through: 0.45, by: 0.05) {
      #expect(MenuBarTransitionAnimator.popScale(at: step) >= 1)
    }
  }

  @Test("overshoots above 1 at the pop's peak")
  func overshoot() {
    #expect(MenuBarTransitionAnimator.popScale(at: 0.45) > 1)
  }

  @Test("stays inside the status item's headroom", arguments: Array(0...20))
  func bounded(step: Int) {
    let scale = MenuBarTransitionAnimator.popScale(at: Double(step) / 20)
    #expect(scale > 0.8)
    #expect(scale < 1.2)
  }

  @Test("clamps outside the 0...1 window instead of extrapolating")
  func clamped() {
    #expect(MenuBarTransitionAnimator.popScale(at: -0.5) == 1)
    #expect(MenuBarTransitionAnimator.popScale(at: 1.5) == 1)
  }
}

@Suite("Color blend track")
struct ColorBlendTests {
  @Test("starts on the outgoing color and ends fully on the incoming one")
  func endpoints() {
    #expect(MenuBarTransitionAnimator.colorBlend(at: 0) == 0)
    #expect(MenuBarTransitionAnimator.colorBlend(at: 1) == 1)
  }

  @Test("finishes the crossfade before the bounce settles")
  func finishesEarly() {
    #expect(MenuBarTransitionAnimator.colorBlend(at: 0.6) == 1)
  }

  @Test("is monotonically non-decreasing")
  func monotonic() {
    let samples = (0...40)
      .map { MenuBarTransitionAnimator.colorBlend(at: Double($0) / 40) }
    for (previous, next) in zip(samples, samples.dropFirst()) {
      #expect(next >= previous)
    }
  }
}

// MARK: - Phase-change trigger

/// The menu bar animation is triggered by `PomodoroTimer.onPhaseChange`
/// rather than a view-side `.onChange`, because `MenuBarExtra` labels never
/// receive view lifecycle events. This pins the model-side contract: the
/// hook fires on every transition, with the departing phase first.
@Suite("Phase-change hook")
@MainActor
struct PhaseChangeHookTests {
  @Test("fires with the departing and arriving phases on each transition")
  func firesOnSkip() {
    let settings = AppSettings()
    settings.soundEnabled = false
    settings.sessionsBeforeLongBreak = 4
    let timer = PomodoroTimer(
      settings: settings,
      focusGuard: FocusGuard(),
      statistics: StatisticsStore(),
    )
    var transitions:
      [(from: PomodoroTimer.Phase, to: PomodoroTimer.Phase, naturally: Bool)] = []
    timer.onPhaseChange = { transitions.append((from: $0, to: $1, naturally: $2)) }

    timer.skip()
    timer.skip()

    #expect(transitions.map(\.from) == [.focus, .shortBreak])
    #expect(transitions.map(\.to) == [.shortBreak, .focus])
    // Skips are manual, so the hook reports them as non-natural — that's what
    // keeps them a one-shot bounce instead of the sustained alarm.
    #expect(transitions.allSatisfy { !$0.naturally })
  }
}

// MARK: - Attention alarm

/// A natural completion escalates into a sustained alarm: the tomato nudges in
/// bursts and the chime re-plays for the first several, until the popover
/// acknowledges it.
@Suite("Alarm mode")
@MainActor
struct AlarmModeTests {
  @Test("begins ringing and remembers the phase being entered")
  func begins() {
    let animator = MenuBarTransitionAnimator()
    animator.beginAlarm(from: .focus, to: .shortBreak)
    defer { animator.acknowledgeAlarm() }
    #expect(animator.isAlarming)
    #expect(animator.pendingMessagePhase == .shortBreak)
  }

  @Test("acknowledging stops the alarm")
  func acknowledges() {
    let animator = MenuBarTransitionAnimator()
    animator.beginAlarm(from: .focus, to: .shortBreak)
    animator.acknowledgeAlarm()
    #expect(!animator.isAlarming)
  }

  @Test("fires the first chime immediately, with the incoming phase")
  func firstNudgeChimes() {
    let animator = MenuBarTransitionAnimator()
    var chimed: [PomodoroTimer.Phase] = []
    animator.onNudge = { chimed.append($0) }
    animator.beginAlarm(from: .shortBreak, to: .focus)
    animator.acknowledgeAlarm()
    #expect(chimed == [.focus])
  }
}

@Suite("Nudge cadence")
struct NudgeCadenceTests {
  @Test("the chime plays for the first several bursts, then falls silent")
  func audibleCap() {
    let cap = MenuBarTransitionAnimator.maxAudibleNudges
    #expect(MenuBarTransitionAnimator.shouldChime(nudgeIndex: 0))
    #expect(MenuBarTransitionAnimator.shouldChime(nudgeIndex: cap - 1))
    #expect(!MenuBarTransitionAnimator.shouldChime(nudgeIndex: cap))
    #expect(!MenuBarTransitionAnimator.shouldChime(nudgeIndex: -1))
  }
}
