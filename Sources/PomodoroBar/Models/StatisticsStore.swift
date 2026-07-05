import Foundation
import SwiftUI

/// One completed focus session, persisted across launches.
struct FocusSessionRecord: Identifiable, Codable, Hashable {
  let id: UUID
  let date: Date
  let minutes: Int
}

/// A single day's total focus minutes (date normalized to start-of-day).
struct DailyTotal: Identifiable {
  let id: Date
  let date: Date
  let minutes: Int
}

/// One weekday/hour bucket in the time-of-day heatmap: total focus minutes
/// across all history whose completion timestamp falls in that bucket.
/// Bucketed by completion time rather than session start/end — a session is
/// short relative to an hour, so this is a close-enough proxy without
/// needing to track session start times separately.
struct TimeOfDayCell: Identifiable {
  let id: Int
  /// Calendar weekday: 1 = Sunday ... 7 = Saturday.
  let weekday: Int
  let hour: Int
  let minutes: Int
}

/// Persists focus-session history in `UserDefaults` and exposes derived
/// aggregates for the Statistics tab.
@Observable
@MainActor
final class StatisticsStore {
  // MARK: - Constants

  private enum Key {
    static let focusRecords = "focusRecords"
  }

  // MARK: - Stored Properties

  private(set) var records: [FocusSessionRecord]

  /// Injectable so `-demoData` mode (see the `#if DEBUG` extension below)
  /// can point at its own isolated suite — persisted history for the real
  /// app always lives in `.standard`, and the two can never collide.
  private let defaults: UserDefaults

  // MARK: - Init

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.records = Self.loadRecords(from: defaults)
  }

  // MARK: - Public Actions

  func recordFocusCompletion(minutes: Int) {
    guard minutes > 0 else { return }
    records.append(
      FocusSessionRecord(
        id: UUID(),
        date: Date(),
        minutes: minutes,
      ),
    )
    persist()
  }

  func clearAll() {
    records.removeAll()
    persist()
  }

  // MARK: - Derived Aggregates

  var todayMinutes: Int {
    let start = Calendar.current.startOfDay(for: Date())
    return sumMinutes(from: start)
  }

  var weekMinutes: Int {
    let calendar = Calendar.current
    let start = calendar.startOfDay(
      for: calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
    )
    return sumMinutes(from: start)
  }

  var monthMinutes: Int {
    let calendar = Calendar.current
    let start = calendar.startOfDay(
      for: calendar.date(byAdding: .day, value: -29, to: Date()) ?? Date(),
    )
    return sumMinutes(from: start)
  }

  var todaySessions: Int {
    let start = Calendar.current.startOfDay(for: Date())
    return countSessions(from: start)
  }

  var weekSessions: Int {
    let calendar = Calendar.current
    let start = calendar.startOfDay(
      for: calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
    )
    return countSessions(from: start)
  }

  var monthSessions: Int {
    let calendar = Calendar.current
    let start = calendar.startOfDay(
      for: calendar.date(byAdding: .day, value: -29, to: Date()) ?? Date(),
    )
    return countSessions(from: start)
  }

  /// Last 7 days, oldest -> newest, day normalized to start-of-day.
  var lastSevenDays: [DailyTotal] {
    dailyTotals(dayCount: 7)
  }

  /// Last 30 days, oldest -> newest, day normalized to start-of-day.
  var lastThirtyDays: [DailyTotal] {
    dailyTotals(dayCount: 30)
  }

  /// Consecutive days, ending today, with at least one completed focus
  /// session — an in-progress today with no session yet doesn't reset it.
  var currentStreak: Int {
    Self.currentStreak(records: records, today: Date())
  }

  /// The single day with the most recorded focus minutes across all
  /// history, not just the rolling windows the summary cards use.
  var bestDay: DailyTotal? {
    Self.bestDay(records: records)
  }

  /// 7 x 24 grid of focus minutes by weekday and hour of day, across all
  /// history. See `TimeOfDayCell` for the bucketing caveat.
  var timeOfDayHeatmap: [TimeOfDayCell] {
    Self.timeOfDayHeatmap(records: records)
  }

  // MARK: - Helpers

  private func sumMinutes(from startDate: Date) -> Int {
    records
      .filter { $0.date >= startDate }
      .reduce(0) { $0 + $1.minutes }
  }

  private func countSessions(from startDate: Date) -> Int {
    records
      .filter { $0.date >= startDate }
      .count
  }

  private func dailyTotals(dayCount: Int) -> [DailyTotal] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let buckets = (0..<(dayCount)).reversed().map { offset in
      calendar.date(byAdding: .day, value: -offset, to: today) ?? today
    }

    let byDay = Self.minutesByDay(records: records, calendar: calendar)
    return buckets.map { day in
      DailyTotal(id: day, date: day, minutes: byDay[day, default: 0])
    }
  }

  // MARK: - Pure Aggregates
  //
  // Extracted as `nonisolated static` so they're testable against explicit
  // records/dates/calendars, without a live `StatisticsStore` or the wall
  // clock — the same pattern `PomodoroTimer.focusWaitReason` uses.

  private nonisolated static func minutesByDay(
    records: [FocusSessionRecord],
    calendar: Calendar,
  ) -> [Date: Int] {
    var byDay: [Date: Int] = [:]
    for record in records {
      let day = calendar.startOfDay(for: record.date)
      byDay[day, default: 0] += record.minutes
    }
    return byDay
  }

  nonisolated static func currentStreak(
    records: [FocusSessionRecord],
    today: Date,
    calendar: Calendar = .current,
  ) -> Int {
    let daysWithSessions = Set(records.map { calendar.startOfDay(for: $0.date) })
    guard !daysWithSessions.isEmpty else { return 0 }

    var cursor = calendar.startOfDay(for: today)
    if !daysWithSessions.contains(cursor) {
      // Today has no session yet: an otherwise-unbroken streak shouldn't
      // read as zero before the day is even over, so start counting from
      // yesterday instead.
      guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
        return 0
      }
      cursor = yesterday
    }

    var streak = 0
    while daysWithSessions.contains(cursor) {
      streak += 1
      guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
      cursor = previous
    }
    return streak
  }

  nonisolated static func bestDay(
    records: [FocusSessionRecord],
    calendar: Calendar = .current,
  ) -> DailyTotal? {
    let byDay = minutesByDay(records: records, calendar: calendar)
    guard let (day, minutes) = byDay.max(by: { $0.value < $1.value }) else { return nil }
    return DailyTotal(id: day, date: day, minutes: minutes)
  }

  nonisolated static func timeOfDayHeatmap(
    records: [FocusSessionRecord],
    calendar: Calendar = .current,
  ) -> [TimeOfDayCell] {
    var totals: [Int: Int] = [:] // key = weekday * 24 + hour
    for record in records {
      let comps = calendar.dateComponents([.weekday, .hour], from: record.date)
      guard let weekday = comps.weekday, let hour = comps.hour else { continue }
      totals[weekday * 24 + hour, default: 0] += record.minutes
    }

    // Rows in the calendar's own week order (e.g. Monday-first in most of
    // Europe), so the grid reads naturally instead of always starting Sunday.
    let firstWeekday = calendar.firstWeekday
    let orderedWeekdays = (0..<7).map { ((firstWeekday - 1 + $0) % 7) + 1 }

    return orderedWeekdays.flatMap { weekday in
      (0..<24).map { hour in
        TimeOfDayCell(
          id: weekday * 24 + hour,
          weekday: weekday,
          hour: hour,
          minutes: totals[weekday * 24 + hour, default: 0],
        )
      }
    }
  }

  // MARK: - Persistence

  private func persist() {
    do {
      let data = try JSONEncoder().encode(records)
      defaults.set(data, forKey: Key.focusRecords)
    } catch {
      // Encoding failures are non-fatal; in-memory state remains correct.
    }
  }

  private static func loadRecords(from defaults: UserDefaults) -> [FocusSessionRecord] {
    guard
      let data = defaults.data(forKey: Key.focusRecords)
    else {
      return []
    }
    do {
      return try JSONDecoder().decode([FocusSessionRecord].self, from: data)
    } catch {
      return []
    }
  }
}

#if DEBUG
extension StatisticsStore {
  /// Isolated suite for `-demoData` mode — a distinct plist from `.standard`,
  /// so demo history can never read from or overwrite real recorded history.
  static let demoSuiteName = "com.archiet4.pomodorobar.demo"

  /// A store seeded with realistic, deterministic sample history for App
  /// Store screenshots and manual QA of the Statistics window. Always resets
  /// the demo suite to a fresh dataset on launch, so every run looks the
  /// same regardless of anything clicked in a previous demo session.
  static func demo() -> StatisticsStore {
    let store = StatisticsStore(defaults: UserDefaults(suiteName: demoSuiteName) ?? .standard)
    store.records = DemoStatisticsData.sampleRecords()
    store.persist()
    return store
  }
}
#endif