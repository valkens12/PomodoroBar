import Testing

@testable import PomodoroBar

@Suite("Alarm messages")
struct AlarmMessagesTests {
  @Test(
    "returns a non-empty playful line for every phase direction",
    arguments: PomodoroTimer.Phase.allCases,
  )
  func nonEmpty(phase: PomodoroTimer.Phase) {
    #expect(!AlarmMessages.random(for: phase).isEmpty)
  }
}
