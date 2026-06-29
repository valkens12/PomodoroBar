import Charts
import SwiftUI

/// Focus-history statistics: today / week / month summaries, a 7-day bar chart,
/// and a 30-day area trend. All marks are tomato-tinted to keep the aesthetic
/// cohesive. A friendly empty state is shown when no sessions have been recorded.
struct StatisticsTab: View {
  @Environment(StatisticsStore.self) private var statistics

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
        .foregroundStyle(Theme.tomatoRed)
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
        phase: .focus,
      )
      StatCard(
        title: "This Week",
        minutes: statistics.weekMinutes,
        sessions: statistics.weekSessions,
        phase: .shortBreak,
      )
      StatCard(
        title: "This Month",
        minutes: statistics.monthMinutes,
        sessions: statistics.monthSessions,
        phase: .longBreak,
      )
    }
  }

  // MARK: - 7-Day Bar Chart

  private var sevenDayChart: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Last 7 Days")
        .font(.system(.headline, design: .rounded))
        .foregroundStyle(Theme.tomatoRed)

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
      }
      .chartXAxis {
        AxisMarks(values: .stride(by: .day)) { value in
          AxisGridLine()
          AxisValueLabel(format: .dateTime.weekday(.abbreviated))
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading) { _ in
          AxisGridLine()
          AxisValueLabel("m")
        }
      }
      .frame(height: 160)
    }
  }

  // MARK: - 30-Day Area Trend

  private var thirtyDayChart: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Last 30 Days")
        .font(.system(.headline, design: .rounded))
        .foregroundStyle(Theme.vineGreen)

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
      }
      .chartXAxis {
        AxisMarks(values: .stride(by: .day, count: 5)) { value in
          AxisGridLine()
          AxisValueLabel(format: .dateTime.day())
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading) { _ in
          AxisGridLine()
          AxisValueLabel("m")
        }
      }
      .frame(height: 120)
    }
  }

  // MARK: - Clear History

  private var clearButton: some View {
    HStack {
      Spacer()
      Button("Clear History", role: .destructive) {
        statistics.clearAll()
      }
      .buttonStyle(.bordered)
      .accessibilityHint("Delete all recorded focus sessions.")
    }
  }
}

// MARK: - StatCard

/// A compact summary card: a tomato glyph accent, a big rounded focus-minutes
/// number, and a session-count subtitle.
private struct StatCard: View {
  let title: String
  let minutes: Int
  let sessions: Int
  let phase: PomodoroTimer.Phase

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        TomatoGlyph(size: 20, phase: phase)
          .accessibilityHidden(true)
        Text(title)
          .font(.system(.subheadline, design: .rounded).weight(.medium))
          .foregroundStyle(.secondary)
      }

      Text("\(minutes)")
        .font(.system(.largeTitle, design: .rounded).weight(.bold))
        .foregroundStyle(Theme.color(for: phase))
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