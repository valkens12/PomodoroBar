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

  @Test("squashes below 1 before the pop")
  func anticipatorySquash() {
    #expect(MenuBarTransitionAnimator.popScale(at: 0.15) < 1)
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

@Suite("Wiggle track")
struct WiggleTests {
  @Test("rests at 0 on both endpoints")
  func endpoints() {
    #expect(MenuBarTransitionAnimator.wiggleDegrees(at: 0) == 0)
    #expect(MenuBarTransitionAnimator.wiggleDegrees(at: 1) == 0)
  }

  @Test("actually swings mid-animation")
  func swings() {
    let peak = (0...20)
      .map { MenuBarTransitionAnimator.wiggleDegrees(at: Double($0) / 20) }
      .map(abs)
      .max() ?? 0
    #expect(peak > 2)
  }

  @Test("decays: later swings are smaller than earlier ones")
  func decays() {
    // The sine's crests sit near t = 1/6 and t = 5/6 (sin(t·3π) extremes).
    let early = abs(MenuBarTransitionAnimator.wiggleDegrees(at: 1.0 / 6.0))
    let late = abs(MenuBarTransitionAnimator.wiggleDegrees(at: 5.0 / 6.0))
    #expect(late < early)
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
    var transitions: [(from: PomodoroTimer.Phase, to: PomodoroTimer.Phase)] = []
    timer.onPhaseChange = { transitions.append((from: $0, to: $1)) }

    timer.skip()
    timer.skip()

    #expect(transitions.map(\.from) == [.focus, .shortBreak])
    #expect(transitions.map(\.to) == [.shortBreak, .focus])
  }
}
