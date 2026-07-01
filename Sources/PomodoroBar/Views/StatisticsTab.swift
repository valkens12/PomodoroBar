import Charts
import SwiftUI

/// Focus-history statistics: today / week / month summaries, a 7-day bar chart,
/// and a 30-day area trend. All marks are tomato-tinted to keep the aesthetic
/// cohesive. A friendly empty state is shown when no sessions have been recorded.
struct StatisticsTab: View {
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
          sevenDayChart
          thirtyDayChart
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
      Text("No focus sessions yet")
        .font(.system(.title3, design: .rounded).weight(.semibold))
        .foregroundStyle(Theme.textColor(for: .focus))
      Text("Start the tomato and finish a focus session to see your stats grow here.")
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
        title: "Today",
        minutes: statistics.todayMinutes,
        sessions: statistics.todaySessions,
      )
      StatCard(
        title: "This Week",
        minutes: statistics.weekMinutes,
        sessions: statistics.weekSessions,
      )
      StatCard(
        title: "This Month",
        minutes: statistics.monthMinutes,
        sessions: statistics.monthSessions,
      )
    }
  }

  // MARK: - 7-Day Bar Chart

  private var sevenDayChart: some View {
    let selected = nearestDailyTotal(to: selectedSevenDayDate, in: statistics.lastSevenDays)

    return VStack(alignment: .leading, spacing: 8) {
      Text("Last 7 Days")
        .font(.system(.headline, design: .rounded))
        .foregroundStyle(Theme.textColor(for: .focus))

      Chart(statistics.lastSevenDays) { day in
        BarMark(
          x: .value("Day", day.date, unit: .day),
          y: .value("Minutes", day.minutes),
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
          RuleMark(x: .value("Day", selected.date, unit: .day))
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
              Text("\(minutes)m")
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
      Text("Last 30 Days")
        .font(.system(.headline, design: .rounded))
        .foregroundStyle(Theme.textColor(for: .longBreak))

      Chart(statistics.lastThirtyDays) { day in
        LineMark(
          x: .value("Day", day.date, unit: .day),
          y: .value("Minutes", day.minutes),
        )
        .foregroundStyle(Theme.tomatoRed)
        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        .interpolationMethod(.catmullRom)

        AreaMark(
          x: .value("Day", day.date, unit: .day),
          y: .value("Minutes", day.minutes),
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
          RuleMark(x: .value("Day", selected.date, unit: .day))
            .foregroundStyle(Theme.vineGreen.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .annotation(position: .top, spacing: 4) {
              chartCallout(for: selected)
            }

          PointMark(
            x: .value("Day", selected.date, unit: .day),
            y: .value("Minutes", selected.minutes),
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
              Text("\(minutes)m")
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
      Text("\(day.minutes)m")
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
      Button("Clear History…", role: .destructive) {
        showClearConfirmation = true
      }
      .buttonStyle(.bordered)
      .accessibilityHint("Delete all recorded focus sessions.")
      .confirmationDialog(
        "Clear all focus history?",
        isPresented: $showClearConfirmation,
      ) {
        Button("Clear All History", role: .destructive) {
          statistics.clearAll()
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          "This permanently deletes all \(statistics.records.count) recorded "
          + (statistics.records.count == 1 ? "session" : "sessions")
          + ". This can't be undone."
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

      Text("\(minutes)")
        .font(.system(.largeTitle, design: .rounded).weight(.bold))
        .foregroundStyle(Theme.textColor(for: .focus))
        .monospacedDigit()
        .accessibilityLabel("\(minutes) focus minutes")

      Text("\(sessions) \(sessions == 1 ? "session" : "sessions")")
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
  StatisticsTab()
    .environment(StatisticsStore())
}