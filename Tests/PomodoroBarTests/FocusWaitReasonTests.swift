import Foundation
import Testing

@testable import PomodoroBar

// MARK: - Focus-gating wait decision

@Suite("Focus wait reason")
struct FocusWaitReasonTests {
  typealias Phase = PomodoroTimer.Phase
  typealias RunState = PomodoroTimer.RunState

  @Test("focus phase away from a focus app waits on the wrong app")
  func focusWrongApp() {
    let reason = PomodoroTimer.focusWaitReason(
      phase: .focus,
      runState: .running,
      gatingEnabled: true,
      isFocusAppActive: false,
      isTabMismatch: false,
    )
    #expect(reason == .wrongApp)
  }

  @Test("focus phase on the right app but wrong tab waits on the tab")
  func focusWrongTab() {
    let reason = PomodoroTimer.focusWaitReason(
      phase: .focus,
      runState: .running,
      gatingEnabled: true,
      isFocusAppActive: false,
      isTabMismatch: true,
    )
    #expect(reason == .wrongTab)
  }

  @Test("focus phase with an active focus app never waits")
  func focusActive() {
    let reason = PomodoroTimer.focusWaitReason(
      phase: .focus,
      runState: .running,
      gatingEnabled: true,
      isFocusAppActive: true,
      isTabMismatch: false,
    )
    #expect(reason == .notWaiting)
  }

  // The bug this covers: breaks are meant to run regardless of what's
  // frontmost, so gating must never hold a break — even with gating on, no
  // focus app active, and (spuriously) a tab mismatch.
  @Test(
    "breaks never wait on a focus app",
    arguments: [Phase.shortBreak, Phase.longBreak],
  )
  func breaksNeverWait(phase: Phase) {
    let reason = PomodoroTimer.focusWaitReason(
      phase: phase,
      runState: .running,
      gatingEnabled: true,
      isFocusAppActive: false,
      isTabMismatch: true,
    )
    #expect(reason == .notWaiting)
  }

  @Test("gating disabled never waits")
  func gatingDisabled() {
    let reason = PomodoroTimer.focusWaitReason(
      phase: .focus,
      runState: .running,
      gatingEnabled: false,
      isFocusAppActive: false,
      isTabMismatch: false,
    )
    #expect(reason == .notWaiting)
  }

  @Test(
    "a non-running timer never waits",
    arguments: [RunState.idle, RunState.paused],
  )
  func notRunning(runState: RunState) {
    let reason = PomodoroTimer.focusWaitReason(
      phase: .focus,
      runState: runState,
      gatingEnabled: true,
      isFocusAppActive: false,
      isTabMismatch: false,
    )
    #expect(reason == .notWaiting)
  }
}
