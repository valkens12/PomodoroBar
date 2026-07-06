import SwiftUI

/// The shareable "Focus Card": a fixed-size portrait story card (9:16)
/// rendered offscreen by `FocusShareCardExport` and shown scaled-down as a
/// live preview in `FocusShareCardPickerView`. Instead of screenshotting the
/// Statistics window, it compacts the history into a persona headline, a
/// radial 24-hour "focus clock" bloom, the week's key numbers, and a 30-day
/// trend strip. All colors come from the chosen style's palette — explicit
/// values, never appearance-dynamic ones (see `FocusShareCardStyle.Palette`).
struct FocusShareCardView: View {
  let data: FocusShareCardData
  let style: FocusShareCardStyle

  /// 360 x 640 pt at 3x renders exactly 1080 x 1920 px, the portrait story
  /// format every social platform treats as native.
  static let cardSize = CGSize(width: 360, height: 640)
  static let exportScale: CGFloat = 3

  private var palette: FocusShareCardStyle.Palette { style.palette }

  var body: some View {
    VStack(spacing: 0) {
      header
      Spacer(minLength: 12)
      personaBlock
      Spacer(minLength: 12)
      FocusClockBloom(hourlyMinutes: data.hourlyMinutes, palette: palette)
        .frame(width: 252, height: 252)
      Spacer(minLength: 16)
      statsRow
      if let delta = data.weekDeltaPercent {
        deltaBadge(delta)
          .padding(.top, 12)
      }
      Spacer(minLength: 16)
      trendStrip
      Spacer(minLength: 14)
      footer
    }
    .padding(26)
    .frame(width: Self.cardSize.width, height: Self.cardSize.height)
    .background(cardBackground)
  }

  // MARK: - Sections

  private var header: some View {
    HStack(spacing: 7) {
      TomatoGlyph(size: 18, phase: .focus)
      Text(verbatim: "PomodoroBar")
        .font(.system(.footnote, design: .rounded).weight(.semibold))
        .foregroundStyle(palette.secondaryText)
      Spacer()
      Text(data.generatedOn, format: .dateTime.month(.abbreviated).day().year())
        .font(.system(.footnote, design: .rounded))
        .foregroundStyle(palette.tertiaryText)
    }
  }

  private var personaBlock: some View {
    VStack(spacing: 6) {
      Text(String(localized: "share.card.kicker", defaultValue: "My Focus Rhythm"))
        .font(.system(.caption, design: .rounded).weight(.semibold))
        .textCase(.uppercase)
        .tracking(2.2)
        .foregroundStyle(palette.kicker)
      Text(data.persona.title)
        .font(.system(size: 34, weight: .bold, design: .rounded))
        .foregroundStyle(palette.primaryText)
      Text(data.persona.tagline)
        .font(.system(.subheadline, design: .rounded))
        .foregroundStyle(palette.secondaryText)
    }
    .multilineTextAlignment(.center)
  }

  private var statsRow: some View {
    HStack(spacing: 10) {
      CardStat(
        title: String(localized: "share.card.week", defaultValue: "This Week"),
        value: formattedFocusDuration(data.weekMinutes),
        subtitle: String(
          format: String(
            localized: data.weekSessions == 1
              ? "stats.sessionsCount.singular"
              : "stats.sessionsCount.plural",
            defaultValue: data.weekSessions == 1 ? "%d session" : "%d sessions",
          ),
          data.weekSessions,
        ),
        palette: palette,
      )
      CardStat(
        title: String(localized: "stats.streak.title", defaultValue: "Streak"),
        value: "\(data.streak)",
        subtitle: String(
          localized: data.streak == 1 ? "stats.streak.unitSingular" : "stats.streak.unitPlural",
          defaultValue: data.streak == 1 ? "day streak" : "days streak",
        ),
        palette: palette,
      )
      CardStat(
        title: String(localized: "stats.bestDay.title", defaultValue: "Best Day"),
        value: data.bestDayMinutes.map { formattedFocusDuration($0) } ?? "—",
        subtitle: String(localized: "share.card.allTime", defaultValue: "all-time"),
        palette: palette,
      )
    }
  }

  private func deltaBadge(_ delta: Int) -> some View {
    HStack(spacing: 5) {
      Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
        .font(.system(size: 11, weight: .bold))
      Text(
        String(
          format: String(
            localized: "share.card.weekDelta",
            defaultValue: "%@%% vs last week",
          ),
          delta >= 0 ? "+\(delta)" : "\(delta)",
        )
      )
      .font(.system(.footnote, design: .rounded).weight(.semibold))
    }
    .foregroundStyle(delta >= 0 ? palette.positiveDelta : palette.secondaryText)
    .padding(.horizontal, 12)
    .padding(.vertical, 5)
    .background(palette.badgeBackground, in: Capsule())
  }

  private var trendStrip: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(String(localized: "stats.last30Days", defaultValue: "Last 30 Days"))
        .font(.system(.caption2, design: .rounded).weight(.semibold))
        .textCase(.uppercase)
        .tracking(1.6)
        .foregroundStyle(palette.tertiaryText)
      Canvas { context, size in
        let minutes = data.last30DailyMinutes
        guard !minutes.isEmpty else { return }
        let peak = max(minutes.max() ?? 0, 1)
        let gap: CGFloat = 3
        let barWidth = (size.width - gap * CGFloat(minutes.count - 1)) / CGFloat(minutes.count)
        for (index, value) in minutes.enumerated() {
          let intensity = sqrt(Double(value) / Double(peak))
          let barHeight = max(2.5, size.height * intensity)
          let rect = CGRect(
            x: CGFloat(index) * (barWidth + gap),
            y: size.height - barHeight,
            width: barWidth,
            height: barHeight,
          )
          let path = Path(roundedRect: rect, cornerRadius: barWidth / 2.5)
          let color = value == 0
            ? palette.emptyMark
            : Theme.mix(Theme.tomatoOrange, Theme.tomatoRed, by: intensity)
          context.fill(path, with: .color(color))
        }
      }
      .frame(height: 36)
    }
  }

  private var footer: some View {
    HStack(spacing: 0) {
      Text(
        String(
          format: String(
            localized: "share.card.totalFocus",
            defaultValue: "%@ focused all-time",
          ),
          formattedFocusDuration(data.totalMinutes),
        )
      )
      Spacer()
      Text(
        String(
          localized: "share.card.madeWith",
          defaultValue: "made with PomodoroBar",
        )
      )
    }
    .font(.system(.caption2, design: .rounded))
    .foregroundStyle(palette.tertiaryText)
  }

  private var cardBackground: some View {
    ZStack {
      LinearGradient(
        colors: [palette.backgroundTop, palette.backgroundBottom],
        startPoint: .top,
        endPoint: .bottom,
      )
      // Soft glow behind the bloom so the fingerprint reads as the hero of
      // the card.
      RadialGradient(
        colors: [palette.glow, .clear],
        center: .center,
        startRadius: 10,
        endRadius: 210,
      )
    }
  }
}

// MARK: - CardStat

/// One column of the stats row: uppercase label, big value, small subtitle.
private struct CardStat: View {
  let title: String
  let value: String
  let subtitle: String
  let palette: FocusShareCardStyle.Palette

  var body: some View {
    VStack(spacing: 3) {
      Text(title)
        .font(.system(.caption2, design: .rounded).weight(.semibold))
        .textCase(.uppercase)
        .tracking(1.2)
        .foregroundStyle(palette.tertiaryText)
      Text(value)
        .font(.system(.title2, design: .rounded).weight(.bold))
        .foregroundStyle(palette.primaryText)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(subtitle)
        .font(.system(.caption2, design: .rounded))
        .foregroundStyle(palette.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - FocusClockBloom

/// The card's centerpiece: 24 petals arranged like a clock face (midnight at
/// the top, noon at the bottom), each petal's length and warmth driven by
/// the focus minutes recorded in that hour of day. Every user's history
/// produces a different bloom, which is what makes the card worth sharing.
private struct FocusClockBloom: View {
  let hourlyMinutes: [Int]
  let palette: FocusShareCardStyle.Palette

  private static let hoursPerDay = 24
  private static let degreesPerHour = 360.0 / Double(hoursPerDay)

  var body: some View {
    GeometryReader { proxy in
      let size = min(proxy.size.width, proxy.size.height)
      let innerRadius = size * 0.17
      let maxPetalLength = size * 0.27
      let peak = max(hourlyMinutes.max() ?? 0, 1)

      ZStack {
        ForEach(0..<Self.hoursPerDay, id: \.self) { hour in
          let minutes = hour < hourlyMinutes.count ? hourlyMinutes[hour] : 0
          // Square-root scaling keeps quiet hours visible next to the peak
          // instead of collapsing them into invisible slivers.
          let intensity = sqrt(Double(minutes) / Double(peak))
          let length = 5 + intensity * maxPetalLength
          Capsule()
            .fill(
              minutes == 0
                ? palette.emptyMark
                : Theme.mix(Theme.tomatoOrange, Theme.tomatoRed, by: intensity)
                  .opacity(0.45 + 0.55 * intensity)
            )
            .frame(width: size * 0.026, height: length)
            .offset(y: -(innerRadius + length / 2))
            .rotationEffect(.degrees(Double(hour) * Self.degreesPerHour))
        }

        hourLabels(size: size)

        TomatoGlyph(size: size * 0.19, phase: .focus)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }

  /// "0 / 6 / 12 / 18" markers just outside the longest possible petal, so
  /// the bloom reads as a clock face rather than an abstract starburst.
  private func hourLabels(size: CGFloat) -> some View {
    let radius = size * 0.485
    return ForEach([0, 6, 12, 18], id: \.self) { hour in
      let angle = Double(hour) * Self.degreesPerHour * .pi / 180
      Text("\(hour)")
        .font(.system(size: size * 0.042, weight: .medium, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(palette.tertiaryText)
        .offset(
          x: radius * CGFloat(sin(angle)),
          y: -radius * CGFloat(cos(angle)),
        )
    }
  }
}

#if DEBUG
#Preview("Ember") {
  FocusShareCardView(
    data: FocusShareCardData.make(records: DemoStatisticsData.sampleRecords()),
    style: .ember,
  )
}

#Preview("Harvest") {
  FocusShareCardView(
    data: FocusShareCardData.make(records: DemoStatisticsData.sampleRecords()),
    style: .harvest,
  )
}

#Preview("Midnight") {
  FocusShareCardView(
    data: FocusShareCardData.make(records: DemoStatisticsData.sampleRecords()),
    style: .midnight,
  )
}
#endif
