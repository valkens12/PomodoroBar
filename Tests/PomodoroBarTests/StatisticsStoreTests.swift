import Foundation
import Testing

@testable import PomodoroBar

// MARK: - Streak, best day, and time-of-day heatmap
//
// All three are pure `nonisolated static` functions on `StatisticsStore`
// (records/date/calendar in, value out), so they're testable against fixed
// dates and a fixed UTC calendar without a live store or the wall clock —
// the same pattern `PomodoroTimer.focusWaitReason` uses.

@Suite("Statistics aggregates")
struct StatisticsAggregatesTests {
  private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    cal.firstWeekday = 1
    return cal
  }

  /// `offset` days from a fixed reference date (2026-01-01 UTC), at `hour`.
  private func day(_ offset: Int, hour: Int = 12) -> Date {
    let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    return calendar
      .date(byAdding: .day, value: offset, to: reference)!
      .addingTimeInterval(TimeInterval(hour * 3600))
  }

  private func record(daysAgo: Int, minutes: Int = 25, hour: Int = 12) -> FocusSessionRecord {
    FocusSessionRecord(id: UUID(), date: day(-daysAgo, hour: hour), minutes: minutes)
  }

  // MARK: - Streak

  @Test("no records means no streak")
  func emptyStreak() {
    let streak = StatisticsStore.currentStreak(records: [], today: day(0), calendar: calendar)
    #expect(streak == 0)
  }

  @Test("a single session today is a streak of one")
  func todayOnly() {
    let records = [record(daysAgo: 0)]
    let streak = StatisticsStore.currentStreak(records: records, today: day(0), calendar: calendar)
    #expect(streak == 1)
  }

  @Test("three consecutive days ending today streak to three")
  func threeConsecutiveDays() {
    let records = [record(daysAgo: 0), record(daysAgo: 1), record(daysAgo: 2)]
    let streak = StatisticsStore.currentStreak(records: records, today: day(0), calendar: calendar)
    #expect(streak == 3)
  }

  @Test("an in-progress today with no session yet still counts yesterday's streak")
  func todayInProgressDoesNotResetStreak() {
    let records = [record(daysAgo: 1), record(daysAgo: 2)]
    let streak = StatisticsStore.currentStreak(records: records, today: day(0), calendar: calendar)
    #expect(streak == 2)
  }

  @Test("a gap at yesterday breaks the streak down to just today")
  func gapBreaksStreak() {
    let records = [record(daysAgo: 0), record(daysAgo: 2)]
    let streak = StatisticsStore.currentStreak(records: records, today: day(0), calendar: calendar)
    #expect(streak == 1)
  }

  @Test("no session today or yesterday means the streak has lapsed")
  func lapsedStreakIsZero() {
    let records = [record(daysAgo: 3), record(daysAgo: 4)]
    let streak = StatisticsStore.currentStreak(records: records, today: day(0), calendar: calendar)
    #expect(streak == 0)
  }

  // MARK: - Best day

  @Test("no records means no best day")
  func noBestDay() {
    #expect(StatisticsStore.bestDay(records: [], calendar: calendar) == nil)
  }

  @Test("the day with the most total minutes wins, summed across its sessions")
  func bestDayPicksHighestTotal() {
    let records = [
      record(daysAgo: 5, minutes: 25),
      record(daysAgo: 5, minutes: 25), // same day as above: 50 total
      record(daysAgo: 2, minutes: 40),
    ]
    let best = StatisticsStore.bestDay(records: records, calendar: calendar)
    #expect(best?.minutes == 50)
  }

  // MARK: - Time-of-day heatmap

  @Test("always produces a full 7x24 grid, zero-filled where nothing happened")
  func fullGridEvenWhenEmpty() {
    let cells = StatisticsStore.timeOfDayHeatmap(records: [], calendar: calendar)
    #expect(cells.count == 7 * 24)
    #expect(cells.allSatisfy { $0.minutes == 0 })
  }

  @Test("buckets a session's minutes into its own weekday and hour")
  func bucketsIntoWeekdayAndHour() {
    let date = day(0, hour: 14)
    let expectedWeekday = calendar.component(.weekday, from: date)
    let records = [FocusSessionRecord(id: UUID(), date: date, minutes: 30)]

    let cells = StatisticsStore.timeOfDayHeatmap(records: records, calendar: calendar)
    let match = cells.first { $0.weekday == expectedWeekday && $0.hour == 14 }

    #expect(match?.minutes == 30)
    #expect(cells.filter { $0.minutes > 0 }.count == 1)
  }

  @Test("rows start from the calendar's first weekday")
  func respectsCalendarFirstWeekday() {
    var mondayFirst = calendar
    mondayFirst.firstWeekday = 2

    let cells = StatisticsStore.timeOfDayHeatmap(records: [], calendar: mondayFirst)

    #expect(cells.first?.weekday == 2) // Monday
    #expect(cells.last?.weekday == 1) // Sunday, wrapping back around
  }

  // MARK: - Procrastination

  private func trackedRecord(
    daysAgo: Int,
    procrastinationSeconds: Int?,
  ) -> FocusSessionRecord {
    FocusSessionRecord(
      id: UUID(),
      date: day(-daysAgo),
      minutes: 25,
      procrastinationSeconds: procrastinationSeconds,
    )
  }

  @Test("untracked sessions produce no procrastination total at all")
  func untrackedIsNilNotZero() {
    let records = [trackedRecord(daysAgo: 0, procrastinationSeconds: nil)]
    let total = StatisticsStore.procrastinationMinutes(records: records, from: day(-6))
    #expect(total == nil)
  }

  @Test("tracked seconds sum before converting to minutes, so short slips still count")
  func sumsSecondsBeforeTruncating() {
    // 50s + 40s = 90s = 1 minute; per-record truncation would read 0.
    let records = [
      trackedRecord(daysAgo: 0, procrastinationSeconds: 50),
      trackedRecord(daysAgo: 1, procrastinationSeconds: 40),
    ]
    let total = StatisticsStore.procrastinationMinutes(records: records, from: day(-6))
    #expect(total == 1)
  }

  @Test("records before the window and untracked records are both left out")
  func windowAndTrackingFilters() {
    let records = [
      trackedRecord(daysAgo: 0, procrastinationSeconds: 120),
      trackedRecord(daysAgo: 1, procrastinationSeconds: nil),
      trackedRecord(daysAgo: 30, procrastinationSeconds: 600), // outside window
    ]
    let total = StatisticsStore.procrastinationMinutes(records: records, from: day(-6))
    #expect(total == 2)
  }

  @Test("a tracked spotless session reads as zero, not as untracked")
  func trackedZeroIsZero() {
    let records = [trackedRecord(daysAgo: 0, procrastinationSeconds: 0)]
    let total = StatisticsStore.procrastinationMinutes(records: records, from: day(-6))
    #expect(total == 0)
  }
}

// MARK: - Record decoding

@Suite("Focus session record decoding")
struct FocusSessionRecordDecodingTests {
  @Test("records persisted before procrastination tracking still decode")
  func legacyRecordDecodes() throws {
    let legacyJSON = """
      {"id":"00000000-0000-0000-0000-000000000001","date":776476800,"minutes":25}
      """
    let record = try JSONDecoder().decode(
      FocusSessionRecord.self,
      from: Data(legacyJSON.utf8),
    )
    #expect(record.minutes == 25)
    #expect(record.procrastinationSeconds == nil)
  }

  @Test("procrastination seconds survive an encode/decode round trip")
  func roundTripsProcrastination() throws {
    let record = FocusSessionRecord(
      id: UUID(),
      date: Date(),
      minutes: 25,
      procrastinationSeconds: 90,
    )
    let decoded = try JSONDecoder().decode(
      FocusSessionRecord.self,
      from: JSONEncoder().encode(record),
    )
    #expect(decoded == record)
  }
}
