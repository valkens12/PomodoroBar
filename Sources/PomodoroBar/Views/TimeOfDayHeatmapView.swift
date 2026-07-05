import SwiftUI

/// A 7 (weekday) x 24 (hour) heatmap of when focus sessions actually happen,
/// built from `StatisticsStore.timeOfDayHeatmap` across all recorded
/// history. Styled after GitHub's contribution graph — small rounded
/// squares quantized into discrete intensity levels, with a "Less -> More"
/// legend — rather than a continuous Swift Charts gradient, which read as
/// too subtle a grid of nearly-same-colored rectangles at this size.
struct TimeOfDayHeatmapView: View {
  let cells: [TimeOfDayCell]

  private static let levelCount = 4
  private static let cellSize: CGFloat = 14
  private static let cellSpacing: CGFloat = 3
  private static let rowLabelWidth: CGFloat = 30

  /// Empty-square tone, matching the card surface everywhere else in this
  /// window rather than a bare `.gray`, so an all-zero heatmap doesn't clash.
  private static let emptyLevelColor = Theme.cardBackground

  /// Level 1...4 ramp from a pale tomato tint to fully-saturated tomato red.
  private static let filledLevelColors: [Color] = (1...levelCount).map { level in
    Theme.mix(
      Theme.tomatoOrange.opacity(0.25),
      Theme.tomatoRed,
      by: Double(level - 1) / Double(levelCount - 1),
    )
  }

  private var maxMinutes: Int {
    cells.map(\.minutes).max() ?? 0
  }

  /// `cells` is already 7 x 24 in row-major order (weekday outer, hour
  /// inner, locale-correct week start) — just re-chunk it into rows.
  private var rows: [[TimeOfDayCell]] {
    stride(from: 0, to: cells.count, by: 24).map {
      Array(cells[$0..<min($0 + 24, cells.count)])
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(String(localized: "stats.timeOfDay", defaultValue: "Time of Day"))
        .font(.system(.headline, design: .rounded))
        .foregroundStyle(Theme.textColor(for: .focus))

      VStack(alignment: .leading, spacing: Self.cellSpacing) {
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
          gridRow(row)
        }
        hourAxisRow
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(summaryAccessibilityLabel)

      legend
    }
  }

  // MARK: - Grid

  private func gridRow(_ row: [TimeOfDayCell]) -> some View {
    HStack(spacing: Self.cellSpacing) {
      Text(weekdaySymbol(for: row.first?.weekday ?? 1))
        .font(.system(size: 9, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)
        .frame(width: Self.rowLabelWidth, alignment: .leading)

      ForEach(row) { cell in
        RoundedRectangle(cornerRadius: 3)
          .fill(color(for: cell.minutes))
          .frame(width: Self.cellSize, height: Self.cellSize)
      }
    }
  }

  /// Hour ticks every 6 hours, aligned under their matching column. Every
  /// slot renders the same `Text` (empty string where there's no tick)
  /// rather than a conditional view, so the `HStack` reserves identical
  /// per-column width for all 24 — a conditional `Group` here previously let
  /// the 20 empty slots collapse to zero width, bunching the 4 visible
  /// labels together instead of spreading them under their columns. Bare
  /// hour numbers (not a full localized time string) so the label reliably
  /// fits on one line at this width.
  private var hourAxisRow: some View {
    HStack(spacing: Self.cellSpacing) {
      Color.clear.frame(width: Self.rowLabelWidth)
      ForEach(0..<24, id: \.self) { hour in
        Text(hour % 6 == 0 ? "\(hour)" : "")
          .font(.system(size: 8, design: .rounded))
          .foregroundStyle(.secondary)
          .frame(width: Self.cellSize)
      }
    }
  }

  /// "Less [swatches] More" key, matching the familiar contribution-graph
  /// convention so the quantized levels read without needing a numeric axis.
  private var legend: some View {
    HStack(spacing: 4) {
      Spacer()
      Text(String(localized: "stats.timeOfDay.less", defaultValue: "Less"))
        .font(.system(size: 9, design: .rounded))
        .foregroundStyle(.secondary)
      RoundedRectangle(cornerRadius: 2)
        .fill(Self.emptyLevelColor)
        .frame(width: 10, height: 10)
      ForEach(Self.filledLevelColors.indices, id: \.self) { index in
        RoundedRectangle(cornerRadius: 2)
          .fill(Self.filledLevelColors[index])
          .frame(width: 10, height: 10)
      }
      Text(String(localized: "stats.timeOfDay.more", defaultValue: "More"))
        .font(.system(size: 9, design: .rounded))
        .foregroundStyle(.secondary)
    }
    .accessibilityHidden(true)
  }

  // MARK: - Helpers

  private func weekdaySymbol(for weekday: Int) -> String {
    Calendar.current.shortWeekdaySymbols[weekday - 1]
  }

  private func hourLabel(_ hour: Int) -> String {
    let calendar = Calendar.current
    let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    return date.formatted(.dateTime.hour(.defaultDigits(amPM: .narrow)))
  }

  /// Quantizes `minutes` into the same discrete levels the squares render,
  /// relative to the busiest bucket — a continuous mix here would defeat the
  /// point of the stepped legend below.
  private func color(for minutes: Int) -> Color {
    guard minutes > 0, maxMinutes > 0 else { return Self.emptyLevelColor }
    let level = max(1, Int(ceil(Double(minutes) / Double(maxMinutes) * Double(Self.levelCount))))
    return Self.filledLevelColors[min(level, Self.levelCount) - 1]
  }

  private var summaryAccessibilityLabel: String {
    guard let peak = cells.max(by: { $0.minutes < $1.minutes }), peak.minutes > 0 else {
      return String(
        localized: "stats.timeOfDay.a11yEmpty",
        defaultValue: "Time of day heatmap. No focus time recorded yet."
      )
    }
    let weekday = Calendar.current.weekdaySymbols[peak.weekday - 1]
    return String(
      format: String(
        localized: "stats.timeOfDay.a11yPeak",
        defaultValue: "Time of day heatmap. Busiest around %1$@ on %2$@s, %3$@."
      ),
      hourLabel(peak.hour), weekday, accessibleFocusDuration(peak.minutes),
    )
  }
}

#Preview {
  TimeOfDayHeatmapView(cells: StatisticsStore.timeOfDayHeatmap(records: []))
    .padding()
}
