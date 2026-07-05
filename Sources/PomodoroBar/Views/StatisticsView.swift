import Charts
import SwiftUI

/// Focus-history statistics: today / week / month summaries, a streak + best
/// day highlight row, a 7-day bar chart, a 30-day area trend, and a
/// time-of-day heatmap. All marks are tomato-tinted to keep the aesthetic
/// cohesive. A friendly empty state is shown when no sessions have been recorded.
///
/// Shown in its own "Statistics" window (opened from the popover) rather
/// than a Settings tab — history is content, not configuration, and macOS
/// Settings windows are for preferences.
struct StatisticsView: View {
  @Environment(StatisticsStore.self) private var statistics

  /// Hovered/tapped day on each chart, used to drive a crosshair + value
  /// callout. Separate per chart since both are visible at once.
  @State private var selectedSevenDayDate: Date?
  @State private var selectedThirtyDayDate: Date?

  /// Gates the destructive Clear History action behind a confirmation.
  @State private var showClearConfirmation = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if statistics.records.isEmpty {
          emptyState
        } else {
          summaryCards
          StatisticsHighlightsView(
            streak: statistics.currentStreak,
            bestDay: statistics.bestDay,
          )
          sevenDayChart
          thirtyDayChart
          TimeOfDayHeatmapView(cells: statistics.timeOfDayHeatmap)
          clearButton
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 14) {
      TomatoGlyph(size: 56, phase: .focus)
        .accessibilityHidden(true)
      Text(String(localized: "stats.empty.title", defaultValue: "No focus sessions yet"))
        .font(.system(.title3, design: .rounded).weight(.semibold))
        .foregroundStyle(Theme.textColor(for: .focus))
      Text(
        String(
          localized: "stats.empty.body",
          defaultValue:
            "Start the tomato and finish a focus session to see your stats grow here."
        )
      )
        .font(.system(.body, design: .rounded))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 280)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }

  // MARK: - Summary Cards

  private var summaryCards: some View {
    HStack(spacing: 12) {
      StatCard(
        title: String(localized: "stats.today", defaultValue: "Today"),
        minutes: statistics.todayMinutes,
        sessions: statistics.todaySessions,
      )
      StatCard(
        title: String(localized: "stats.thisWeek", defaultValue: "This Week"),
        minutes: statistics.weekMinutes,
        sessions: statistics.weekSessions,
      )
      StatCard(
        title: String(localized: "stats.thisMonth", defaultValue: "This Month"),
        minutes: statistics.monthMinutes,
        sessions: statistics.monthSessions,
      )
    }
  }

  // MARK: - 7-Day Bar Chart

  private var sevenDayChart: some View {
    let selected = nearestDailyTotal(to: selectedSevenDayDate, in: statistics.lastSevenDays)

    return VStack(alignment: .leading, spacing: 8) {
      Text(String(localized: "stats.last7Days", defaultValue: "Last 7 Days"))
        .font(.system(.headline, design: .rounded))
        .foregroundStyle(Theme.textColor(for: .focus))

      Chart(statistics.lastSevenDays) { day in
        BarMark(
          x: .value(
            String(localized: "stats.dayAxis", defaultValue: "Day"),
            day.date,
            unit: .day,
          ),
          y: .value(
            String(localized: "stats.minutesAxis", defaultValue: "Minutes"),
            day.minutes,
          ),
        )
        .foregroundStyle(
          .linearGradient(
            colors: [Theme.tomatoOrange, Theme.tomatoRed],
            startPoint: .top,
            endPoint: .bottom,
          )
        )
        .cornerRadius(4)
        .opacity(selected == nil || selected?.id == day.id ? 1 : 0.35)

        if let selected {
          RuleMark(
            x: .value(
              String(localized: "stats.dayAxis", defaultValue: "Day"),
              selected.date,
              unit: .day,
            )
          )
            .foregroundStyle(Theme.vineGreen.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .annotation(position: .top, spacing: 4) {
              chartCallout(for: selected)
            }
        }
      }
      .chartXSelection(value: $selectedSevenDayDate)
      .chartXAxis {
        AxisMarks(values: .stride(by: .day)) { value in
          AxisGridLine()
          AxisValueLabel(format: .dateTime.weekday(.abbreviated))
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading) { value in
          AxisGridLine()
          AxisValueLabel {
            if let minutes = value.as(Int.self) {
              Text(formattedFocusDuration(minutes))
            }
          }
        }
      }
      .frame(height: 160)
    }
  }

  // MARK: - 30-Day Area Trend

  private var thirtyDayChart: some View {
    let selected = nearestDailyTotal(to: selectedThirtyDayDate, in: statistics.lastThirtyDays)

    return VStack(alignment: .leading, spacing: 8) {
      Text(String(localized: "stats.last30Days", defaultValue: "Last 30 Days"))
        .font(.system(.headline, design: .rounded))
        .foregroundStyle(Theme.textColor(for: .longBreak))

      Chart(statistics.lastThirtyDays) { day in
        LineMark(
          x: .value(
            String(localized: "stats.dayAxis", defaultValue: "Day"),
            day.date,
            unit: .day,
          ),
          y: .value(
            String(localized: "stats.minutesAxis", defaultValue: "Minutes"),
            day.minutes,
          ),
        )
        .foregroundStyle(Theme.tomatoRed)
        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        .interpolationMethod(.catmullRom)

        AreaMark(
          x: .value(
            String(localized: "stats.dayAxis", defaultValue: "Day"),
            day.date,
            unit: .day,
          ),
          y: .value(
            String(localized: "stats.minutesAxis", defaultValue: "Minutes"),
            day.minutes,
          ),
        )
        .foregroundStyle(
          .linearGradient(
            colors: [Theme.tomatoRed.opacity(0.30), Theme.tomatoRed.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom,
          )
        )
        .interpolationMethod(.catmullRom)

        if let selected {
          RuleMark(
            x: .value(
              String(localized: "stats.dayAxis", defaultValue: "Day"),
              selected.date,
              unit: .day,
            )
          )
            .foregroundStyle(Theme.vineGreen.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .annotation(position: .top, spacing: 4) {
              chartCallout(for: selected)
            }

          PointMark(
            x: .value(
              String(localized: "stats.dayAxis", defaultValue: "Day"),
              selected.date,
              unit: .day,
            ),
            y: .value(
              String(localized: "stats.minutesAxis", defaultValue: "Minutes"),
              selected.minutes,
            ),
          )
          .foregroundStyle(Theme.tomatoRed)
          .symbolSize(60)
        }
      }
      .chartXSelection(value: $selectedThirtyDayDate)
      .chartXAxis {
        AxisMarks(values: .stride(by: .day, count: 5)) { value in
          AxisGridLine()
          AxisValueLabel(format: .dateTime.day())
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading) { value in
          AxisGridLine()
          AxisValueLabel {
            if let minutes = value.as(Int.self) {
              Text(formattedFocusDuration(minutes))
            }
          }
        }
      }
      .frame(height: 120)
    }
  }

  /// Shared crosshair callout: the day's date and exact focus minutes.
  @ViewBuilder
  private func chartCallout(for day: DailyTotal) -> some View {
    VStack(spacing: 2) {
      Text(day.date, format: .dateTime.month(.abbreviated).day())
        .font(.system(.caption2, design: .rounded))
        .foregroundStyle(.secondary)
      Text(formattedFocusDuration(day.minutes))
        .font(.system(.caption, design: .rounded).weight(.bold))
        .foregroundStyle(Theme.textColor(for: .focus))
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
  }

  /// Finds the bucket matching `date`'s calendar day, if any.
  private func nearestDailyTotal(to date: Date?, in totals: [DailyTotal]) -> DailyTotal? {
    guard let date else { return nil }
    let day = Calendar.current.startOfDay(for: date)
    return totals.first { $0.date == day }
  }

  // MARK: - Clear History

  private var clearButton: some View {
    HStack {
      Spacer()
      Button(
        String(localized: "stats.clear", defaultValue: "Clear History…"),
        role: .destructive,
      ) {
        showClearConfirmation = true
      }
      .buttonStyle(.bordered)
      .accessibilityHint(
        String(
          localized: "stats.clear.hint",
          defaultValue: "Delete all recorded focus sessions."
        )
      )
      .confirmationDialog(
        String(
          localized: "stats.clear.confirmTitle",
          defaultValue: "Clear all focus history?",
        ),
        isPresented: $showClearConfirmation,
      ) {
        Button(
          String(
            localized: "stats.clear.confirmAction",
            defaultValue: "Clear All History"
          ),
          role: .destructive,
        ) {
          statistics.clearAll()
        }
        Button(
          String(localized: "skip.confirm.cancel", defaultValue: "Cancel"),
          role: .cancel,
        ) {}
      } message: {
        let count = statistics.records.count
        Text(
          String(
            format: String(
              localized: count == 1
                ? "stats.clear.confirmSingular"
                : "stats.clear.confirmPlural",
              defaultValue: count == 1
                ? "This permanently deletes all %d recorded session. This can't be undone."
                : "This permanently deletes all %d recorded sessions. This can't be undone."
            ),
            count,
          )
        )
      }
    }
  }
}

// MARK: - StatCard

/// A compact summary card: a tomato glyph accent, a big rounded focus-minutes
/// number, and a session-count subtitle. All cards share the focus red — every
/// card shows focus minutes, and green means "break" elsewhere in the app.
private struct StatCard: View {
  let title: String
  let minutes: Int
  let sessions: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        TomatoGlyph(size: 20, phase: .focus)
          .accessibilityHidden(true)
        Text(title)
          .font(.system(.subheadline, design: .rounded).weight(.medium))
          .foregroundStyle(.secondary)
      }

      Text(formattedFocusDuration(minutes))
        .font(.system(.largeTitle, design: .rounded).weight(.bold))
        .foregroundStyle(Theme.textColor(for: .focus))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityLabel(accessibleFocusDuration(minutes))

      Text(
        String(
          format: String(
            localized: sessions == 1
              ? "stats.sessionsCount.singular"
              : "stats.sessionsCount.plural",
            defaultValue: sessions == 1 ? "%d session" : "%d sessions"
          ),
          sessions,
        )
      )
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
  StatisticsView()
    .environment(StatisticsStore())
}