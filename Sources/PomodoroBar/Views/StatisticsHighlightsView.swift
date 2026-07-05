import SwiftUI

/// "Highlights" row: current streak, all-time best day, and — when focus
/// gating has tracked it — time procrastinated this week, shown as a card
/// strip beneath the Today/Week/Month summary cards. Streak and best day are
/// derived from full history (`StatisticsStore.currentStreak` / `.bestDay`),
/// not the rolling windows the summary cards use; procrastination uses the
/// 7-day window and hides entirely when no session was tracked
/// (`StatisticsStore.weekProcrastinationMinutes`).
struct StatisticsHighlightsView: View {
  let streak: Int
  let bestDay: DailyTotal?
  let weekProcrastinationMinutes: Int?

  var body: some View {
    HStack(spacing: 12) {
      HighlightCard(
        systemImage: "flame.fill",
        tint: Theme.tomatoOrange,
        title: String(localized: "stats.streak.title", defaultValue: "Streak"),
        value: "\(streak)",
        valueA11yLabel: streakA11yLabel,
        subtitle: streakSubtitle,
      )
      HighlightCard(
        systemImage: "trophy.fill",
        tint: Theme.vineGreen,
        title: String(localized: "stats.bestDay.title", defaultValue: "Best Day"),
        value: bestDay.map { formattedFocusDuration($0.minutes) } ?? "—",
        valueA11yLabel: bestDay.map { accessibleFocusDuration($0.minutes) },
        subtitle: bestDaySubtitle,
      )
      if let weekProcrastinationMinutes {
        HighlightCard(
          systemImage: "hourglass",
          tint: .secondary,
          title: String(
            localized: "stats.procrastination.title", defaultValue: "Procrastinated",
          ),
          value: formattedFocusDuration(weekProcrastinationMinutes),
          valueA11yLabel: procrastinationA11yLabel(weekProcrastinationMinutes),
          subtitle: String(
            localized: "stats.procrastination.subtitle", defaultValue: "this week",
          ),
        )
      }
    }
  }

  private var streakSubtitle: String {
    String(
      localized: streak == 1 ? "stats.streak.unitSingular" : "stats.streak.unitPlural",
      defaultValue: streak == 1 ? "day streak" : "days streak",
    )
  }

  private var streakA11yLabel: String {
    String(
      format: String(
        localized: streak == 1 ? "stats.streak.a11ySingular" : "stats.streak.a11yPlural",
        defaultValue: streak == 1 ? "%d day streak" : "%d days streak",
      ),
      streak,
    )
  }

  private var bestDaySubtitle: String {
    guard let bestDay else {
      return String(localized: "stats.bestDay.none", defaultValue: "No sessions yet")
    }
    return bestDay.date.formatted(.dateTime.month(.abbreviated).day())
  }

  /// VoiceOver label for the procrastination value — `accessibleFocusDuration`
  /// reads "… focus time", which is exactly wrong for this card.
  private func procrastinationA11yLabel(_ minutes: Int) -> String {
    String(
      format: String(
        localized: minutes == 1
          ? "stats.procrastination.a11ySingular"
          : "stats.procrastination.a11yPlural",
        defaultValue: minutes == 1
          ? "%d minute procrastinated this week"
          : "%d minutes procrastinated this week",
      ),
      minutes,
    )
  }
}

/// A compact highlight card: tinted SF Symbol + title, a big value, and a
/// subtitle. Shares `StatCard`'s visual language (Views/StatisticsView.swift)
/// but is generic enough for a plain count (streak) or a duration + date
/// (best day), where `StatCard`'s fixed duration+session-count shape doesn't
/// fit.
private struct HighlightCard: View {
  let systemImage: String
  let tint: Color
  let title: String
  let value: String
  let valueA11yLabel: String?
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: systemImage)
          .foregroundStyle(tint)
        Text(title)
          .font(.system(.subheadline, design: .rounded).weight(.medium))
          .foregroundStyle(.secondary)
      }

      Text(value)
        .font(.system(.largeTitle, design: .rounded).weight(.bold))
        .foregroundStyle(Theme.textColor(for: .focus))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityLabel(valueA11yLabel ?? value)

      Text(subtitle)
        .font(.system(.footnote, design: .rounded))
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Theme.vineGreen.opacity(0.15), lineWidth: 1)
    )
  }
}

#Preview {
  StatisticsHighlightsView(
    streak: 5,
    bestDay: DailyTotal(id: Date(), date: Date(), minutes: 200),
    weekProcrastinationMinutes: 34,
  )
  .padding()
}
