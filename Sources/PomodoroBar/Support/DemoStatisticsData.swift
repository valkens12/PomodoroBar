#if DEBUG
import Foundation

/// Deterministic, realistic-looking sample focus history for `-demoData`
/// mode (`StatisticsStore.demo()`) — used to populate the Statistics window
/// for App Store screenshots and manual QA without ever touching real
/// recorded history. Debug-only: never compiled into a shipped build.
enum DemoStatisticsData {

  /// ~8 weeks of history: an unbroken 16-day streak ending today, a
  /// realistic mix of gaps and rest days further back, weekday sessions
  /// clustered in a morning + afternoon block with lighter weekends, and one
  /// standout "flow day" nine days back for the Best Day card.
  static func sampleRecords(relativeTo now: Date = Date()) -> [FocusSessionRecord] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)

    var records: [FocusSessionRecord] = []

    for daysAgo in 0..<56 {
      guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
      let weekday = calendar.component(.weekday, from: day)
      let isWeekend = weekday == 1 || weekday == 7

      // The most recent 16 days are always populated so the streak reads
      // cleanly; further back, skip some days for a realistic, uneven trail.
      let keepsGoing = daysAgo < 16
        || (isWeekend && daysAgo % 3 != 0)
        || (!isWeekend && daysAgo % 11 != 0)
      guard keepsGoing else { continue }

      let hours = isWeekend ? [10] : [9, 11, 14]
      for (index, hour) in hours.enumerated() {
        let minutes = index.isMultiple(of: 2) ? 25 : 50
        records.append(session(on: day, hour: hour, minutes: minutes, calendar: calendar))
      }

      // A standout flow day, for the Best Day highlight.
      if daysAgo == 9 {
        for hour in [16, 18] {
          records.append(session(on: day, hour: hour, minutes: 50, calendar: calendar))
        }
      }
    }

    return records
  }

  private static func session(
    on day: Date,
    hour: Int,
    minutes: Int,
    calendar: Calendar,
  ) -> FocusSessionRecord {
    let date = calendar.date(bySettingHour: hour, minute: 20, second: 0, of: day) ?? day
    return FocusSessionRecord(id: UUID(), date: date, minutes: minutes)
  }
}
#endif
