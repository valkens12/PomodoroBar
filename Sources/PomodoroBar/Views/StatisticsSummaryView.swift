import SwiftUI

/// The AI overview card at the top of the Statistics window: 2-3 motivating
/// sentences about the user's focus history, generated on device by
/// `StatisticsSummaryGenerator`. Rendered only when the parent has already
/// checked `StatisticsSummaryGenerator.isSupported` (Apple Intelligence
/// hardware); shows a placeholder shimmer while generating and collapses to
/// nothing if generation fails.
struct StatisticsSummaryView: View {
  @Environment(StatisticsSummaryGenerator.self) private var generator

  /// Compact stats rendering fed to the model; part of the `.task` identity
  /// below, so a change in the underlying history regenerates the summary.
  let digest: String

  /// Mirrors `AppSettings.aiSummaryDarkHumor`. Also part of the `.task`
  /// identity, so flipping the toggle regenerates immediately instead of
  /// waiting for the next unrelated statistics change.
  let darkHumor: Bool

  /// Combined regeneration key — SwiftUI's `.task(id:)` needs one
  /// `Equatable` value, and either half changing should restart generation.
  private var taskId: String {
    "\(darkHumor)\u{0}\(digest)"
  }

  var body: some View {
    Group {
      switch generator.state {
      case .idle, .generating:
        card {
          // Static placeholder redacted into a shimmer of realistic shape,
          // so the card doesn't jump when the real 2-3 sentences land.
          Text(placeholderText)
            .redacted(reason: .placeholder)
        }
      case .ready(let summary):
        card {
          Text(summary)
        }
      case .failed:
        EmptyView()
      }
    }
    .task(id: taskId) {
      await generator.generate(digest: digest, darkHumor: darkHumor)
    }
  }

  private var placeholderText: String {
    darkHumor
      ? String(
        localized: "stats.summary.placeholder.darkHumor",
        defaultValue: "Reviewing the evidence against you…"
      )
      : String(
        localized: "stats.summary.placeholder",
        defaultValue:
          "Looking over your focus history to pull out the highlights and cheer you on…"
      )
  }

  private var title: String {
    darkHumor
      ? String(localized: "stats.summary.title.darkHumor", defaultValue: "The Brutal Truth")
      : String(localized: "stats.summary.title", defaultValue: "Your Week in Focus")
  }

  private func card(@ViewBuilder content: () -> some View) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: darkHumor ? "flame.fill" : "sparkles")
        .foregroundStyle(darkHumor ? Theme.tomatoRed : Theme.tomatoOrange)
        .font(.system(.body, design: .rounded))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(.subheadline, design: .rounded).weight(.medium))
          .foregroundStyle(.secondary)

        content()
          .font(.system(.body, design: .rounded))
          .foregroundStyle(Theme.textColor(for: .focus))
          .fixedSize(horizontal: false, vertical: true)
      }
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
