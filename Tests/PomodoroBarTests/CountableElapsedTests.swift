import Foundation
import Testing

@testable import PomodoroBar

// MARK: - Wall-clock tick accounting

@Suite("Countable elapsed time per tick")
struct CountableElapsedTests {
  private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

  @Test("no predecessor counts a nominal one-second tick")
  func nilPredecessor() {
    #expect(PomodoroTimer.countableElapsed(since: nil, now: now) == 1)
  }

  @Test("a normal one-second gap counts as-is")
  func normalTick() {
    let last = now.addingTimeInterval(-1)
    #expect(PomodoroTimer.countableElapsed(since: last, now: now) == 1)
  }

  @Test("sub-second gaps count their real duration, not a full second")
  func shortTick() {
    let last = now.addingTimeInterval(-0.4)
    let elapsed = PomodoroTimer.countableElapsed(since: last, now: now)
    #expect(abs(elapsed - 0.4) < 0.0001)
  }

  @Test("a long stall is capped at two seconds so it can't burn the session")
  func cappedStall() {
    let last = now.addingTimeInterval(-3600)
    #expect(PomodoroTimer.countableElapsed(since: last, now: now) == 2)
  }

  @Test("a backwards clock counts a nominal one-second tick")
  func backwardsClock() {
    let last = now.addingTimeInterval(5)
    #expect(PomodoroTimer.countableElapsed(since: last, now: now) == 1)
  }
}
