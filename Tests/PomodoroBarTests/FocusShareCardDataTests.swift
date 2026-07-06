import Foundation
import Testing

@testable import PomodoroBar

// MARK: - Focus Card derivation
//
// `FocusShareCardData.make` and `FocusPersona.classify` are pure (records,
// date, calendar in; value out), so they're tested against fixed dates and a
// fixed UTC calendar — the same pattern as `StatisticsAggregatesTests`.

@Suite("Focus share card derivation")
struct FocusShareCardDataTests {
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

  // MARK: - Persona classification

  @Test("too few sessions classifies as sprouting regardless of peak")
  func sproutingBelowThreshold() {
    var hourly = [Int](repeating: 0, count: 24)
    hourly[7] = 100
    let persona = FocusPersona.classify(
      hourlyMinutes: hourly,
      sessionCount: FocusPersona.minimumSessionsForClassification - 1,
    )
    #expect(persona == .sprouting)
  }

  @Test("all-zero hours classifies as sprouting even with enough sessions")
  func sproutingWithoutMinutes() {
    let persona = FocusPersona.classify(
      hourlyMinutes: [Int](repeating: 0, count: 24),
      sessionCount: 10,
    )
    #expect(persona == .sprouting)
  }

  @Test(
    "peak hour maps to the matching persona",
    arguments: [
      (7, FocusPersona.earlyBird),
      (10, FocusPersona.morningMaker),
      (15, FocusPersona.afternoonAnchor),
      (19, FocusPersona.eveningCloser),
      (23, FocusPersona.nightOwl),
      (2, FocusPersona.nightOwl),
    ]
  )
  func personaByPeakHour(peakHour: Int, expected: FocusPersona) {
    var hourly = [Int](repeating: 5, count: 24)
    hourly[peakHour] = 100
    let persona = FocusPersona.classify(hourlyMinutes: hourly, sessionCount: 20)
    #expect(persona == expected)
  }

  // MARK: - Week-over-week delta

  @Test("delta is the rounded percent change vs the previous week")
  func deltaPercent() {
    #expect(FocusShareCardData.deltaPercent(current: 150, previous: 100) == 50)
    #expect(FocusShareCardData.deltaPercent(current: 50, previous: 100) == -50)
    #expect(FocusShareCardData.deltaPercent(current: 100, previous: 100) == 0)
  }

  @Test("delta is nil when the previous week had no focus")
  func deltaNilWithoutPreviousWeek() {
    #expect(FocusShareCardData.deltaPercent(current: 120, previous: 0) == nil)
  }

  @Test("make computes the delta from the two 7-day windows")
  func deltaFromRecords() {
    let records = [
      record(daysAgo: 0, minutes: 100),
      record(daysAgo: 3, minutes: 50),
      record(daysAgo: 8, minutes: 100),
    ]
    let card = FocusShareCardData.make(records: records, now: day(0), calendar: calendar)
    #expect(card.weekMinutes == 150)
    #expect(card.weekSessions == 2)
    #expect(card.weekDeltaPercent == 50)
  }

  // MARK: - Hourly and daily buckets

  @Test("hourly buckets sum minutes per hour of day")
  func hourlyBuckets() {
    let records = [
      record(daysAgo: 0, minutes: 25, hour: 9),
      record(daysAgo: 1, minutes: 50, hour: 9),
      record(daysAgo: 2, minutes: 25, hour: 22),
    ]
    let hourly = FocusShareCardData.hourlyMinutes(records: records, calendar: calendar)
    #expect(hourly.count == 24)
    #expect(hourly[9] == 75)
    #expect(hourly[22] == 25)
    #expect(hourly.reduce(0, +) == 100)
  }

  @Test("the 30-day strip is oldest to newest with today last")
  func thirtyDayStripOrder() {
    let records = [
      record(daysAgo: 0, minutes: 40),
      record(daysAgo: 29, minutes: 25),
      record(daysAgo: 30, minutes: 99), // outside the window
    ]
    let card = FocusShareCardData.make(records: records, now: day(0), calendar: calendar)
    #expect(card.last30DailyMinutes.count == 30)
    #expect(card.last30DailyMinutes.last == 40)
    #expect(card.last30DailyMinutes.first == 25)
    #expect(card.last30DailyMinutes.reduce(0, +) == 65)
  }

  @Test("totals, streak, and best day come from full history")
  func fullHistoryAggregates() {
    let records = [
      record(daysAgo: 0, minutes: 25),
      record(daysAgo: 1, minutes: 75),
      record(daysAgo: 1, minutes: 50, hour: 15),
    ]
    let card = FocusShareCardData.make(records: records, now: day(0), calendar: calendar)
    #expect(card.totalMinutes == 150)
    #expect(card.streak == 2)
    #expect(card.bestDayMinutes == 125)
  }
}
