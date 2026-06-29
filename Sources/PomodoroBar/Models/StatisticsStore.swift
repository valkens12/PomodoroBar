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

  // MARK: - Init

  init() {
    self.records = Self.loadRecords()
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

    var byDay: [Date: Int] = [:]
    for record in records {
      let day = calendar.startOfDay(for: record.date)
      byDay[day, default: 0] += record.minutes
    }

    return buckets.map { day in
      DailyTotal(id: day, date: day, minutes: byDay[day, default: 0])
    }
  }

  // MARK: - Persistence

  private func persist() {
    do {
      let data = try JSONEncoder().encode(records)
      UserDefaults.standard.set(data, forKey: Key.focusRecords)
    } catch {
      // Encoding failures are non-fatal; in-memory state remains correct.
    }
  }

  private static func loadRecords() -> [FocusSessionRecord] {
    guard
      let data = UserDefaults.standard.data(forKey: Key.focusRecords)
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