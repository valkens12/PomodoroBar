import Foundation

/// Everything the shareable Focus Card renders, derived once from raw
/// session history by `make(records:now:calendar:)` — a pure function, so
/// the card is deterministic and the derivation is testable against fixed
/// dates without a live `StatisticsStore` (the same pattern as the store's
/// own `nonisolated static` aggregates).
struct FocusShareCardData: Equatable, Sendable {
  /// Time-of-day archetype classified from `hourlyMinutes`.
  let persona: FocusPersona

  /// Focus minutes per hour of day (24 buckets, all history) — the radial
  /// "focus clock" bloom on the card.
  let hourlyMinutes: [Int]

  /// Focus minutes per day for the last 30 days, oldest -> newest — the
  /// mini trend strip on the card.
  let last30DailyMinutes: [Int]

  let weekMinutes: Int
  let weekSessions: Int
  let streak: Int
  let bestDayMinutes: Int?

  /// Whole-percent change of this week's minutes vs. the 7 days before,
  /// or nil when the previous window has no focus at all — "+∞%" would
  /// read as a bug, not a brag.
  let weekDeltaPercent: Int?

  let totalMinutes: Int
  let generatedOn: Date

  static func make(
    records: [FocusSessionRecord],
    now: Date = Date(),
    calendar: Calendar = .current,
  ) -> FocusShareCardData {
    let weekStart = calendar.startOfDay(
      for: calendar.date(byAdding: .day, value: -6, to: now) ?? now,
    )
    let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart

    let weekRecords = records.filter { $0.date >= weekStart }
    let previousWeekMinutes = records
      .filter { $0.date >= previousWeekStart && $0.date < weekStart }
      .reduce(0) { $0 + $1.minutes }
    let weekMinutes = weekRecords.reduce(0) { $0 + $1.minutes }

    let hourly = hourlyMinutes(records: records, calendar: calendar)

    return FocusShareCardData(
      persona: FocusPersona.classify(hourlyMinutes: hourly, sessionCount: records.count),
      hourlyMinutes: hourly,
      last30DailyMinutes: dailyMinutes(records: records, dayCount: 30, now: now, calendar: calendar),
      weekMinutes: weekMinutes,
      weekSessions: weekRecords.count,
      streak: StatisticsStore.currentStreak(records: records, today: now, calendar: calendar),
      bestDayMinutes: StatisticsStore.bestDay(records: records, calendar: calendar)?.minutes,
      weekDeltaPercent: deltaPercent(current: weekMinutes, previous: previousWeekMinutes),
      totalMinutes: records.reduce(0) { $0 + $1.minutes },
      generatedOn: now,
    )
  }

  // MARK: - Derivation Helpers

  static func hourlyMinutes(
    records: [FocusSessionRecord],
    calendar: Calendar,
  ) -> [Int] {
    var buckets = [Int](repeating: 0, count: 24)
    for record in records {
      let hour = calendar.component(.hour, from: record.date)
      buckets[hour] += record.minutes
    }
    return buckets
  }

  static func deltaPercent(current: Int, previous: Int) -> Int? {
    guard previous > 0 else { return nil }
    return Int((Double(current - previous) / Double(previous) * 100).rounded())
  }

  private static func dailyMinutes(
    records: [FocusSessionRecord],
    dayCount: Int,
    now: Date,
    calendar: Calendar,
  ) -> [Int] {
    let today = calendar.startOfDay(for: now)
    var byDay: [Date: Int] = [:]
    for record in records {
      byDay[calendar.startOfDay(for: record.date), default: 0] += record.minutes
    }
    return (0..<dayCount).reversed().map { offset in
      let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
      return byDay[day, default: 0]
    }
  }
}

// MARK: - FocusPersona

/// A time-of-day focus archetype: which stretch of the day carries the
/// user's heaviest focus, classified from the all-history hourly profile.
/// `sprouting` is the honest fallback while history is too thin for the
/// label to mean anything.
enum FocusPersona: Equatable, Sendable {
  case earlyBird
  case morningMaker
  case afternoonAnchor
  case eveningCloser
  case nightOwl
  case sprouting

  /// Below this many recorded sessions a "peak hour" is noise, so the card
  /// says "still ripening" instead of pretending to know the user.
  static let minimumSessionsForClassification = 5

  static func classify(hourlyMinutes: [Int], sessionCount: Int) -> FocusPersona {
    guard
      sessionCount >= minimumSessionsForClassification,
      let peakMinutes = hourlyMinutes.max(),
      peakMinutes > 0,
      let peakHour = hourlyMinutes.firstIndex(of: peakMinutes)
    else {
      return .sprouting
    }
    switch peakHour {
    case 5..<9: return .earlyBird
    case 9..<13: return .morningMaker
    case 13..<17: return .afternoonAnchor
    case 17..<22: return .eveningCloser
    default: return .nightOwl
    }
  }

  var title: String {
    switch self {
    case .earlyBird:
      return String(localized: "share.persona.earlyBird", defaultValue: "Early Bird")
    case .morningMaker:
      return String(localized: "share.persona.morningMaker", defaultValue: "Morning Maker")
    case .afternoonAnchor:
      return String(localized: "share.persona.afternoonAnchor", defaultValue: "Afternoon Anchor")
    case .eveningCloser:
      return String(localized: "share.persona.eveningCloser", defaultValue: "Evening Closer")
    case .nightOwl:
      return String(localized: "share.persona.nightOwl", defaultValue: "Night Owl")
    case .sprouting:
      return String(localized: "share.persona.sprouting", defaultValue: "Green Tomato")
    }
  }

  var tagline: String {
    switch self {
    case .earlyBird:
      return String(
        localized: "share.persona.earlyBird.tagline",
        defaultValue: "Sharpest before the world wakes up",
      )
    case .morningMaker:
      return String(
        localized: "share.persona.morningMaker.tagline",
        defaultValue: "Deep work while the coffee is still warm",
      )
    case .afternoonAnchor:
      return String(
        localized: "share.persona.afternoonAnchor.tagline",
        defaultValue: "Locked in when the day peaks",
      )
    case .eveningCloser:
      return String(
        localized: "share.persona.eveningCloser.tagline",
        defaultValue: "Finishing strong after hours",
      )
    case .nightOwl:
      return String(
        localized: "share.persona.nightOwl.tagline",
        defaultValue: "Deep focus after dark",
      )
    case .sprouting:
      return String(
        localized: "share.persona.sprouting.tagline",
        defaultValue: "Still ripening, one session at a time",
      )
    }
  }
}
