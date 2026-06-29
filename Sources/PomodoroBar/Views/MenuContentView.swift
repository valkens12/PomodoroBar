import AppKit
import SwiftUI

/// The popover contents shown when the menu bar item is opened.
///
/// Renders a tomato-themed popover: a phase header, a progress ring wrapping
/// a tomato with overlaid time, an optional "waiting for focus app" banner,
/// session dots, prominent Start/Pause/Resume controls, secondary Reset/Skip
/// controls, and a bottom row with a `SettingsLink` (the reliable way to open
/// the Settings scene from a menu bar popover in an accessory app) and Quit.
struct MenuContentView: View {
  @Environment(PomodoroTimer.self) private var timer
  @Environment(AppSettings.self) private var settings
  @Environment(FocusGuard.self) private var focusGuard
  @Environment(StatisticsStore.self) private var statistics

  private let popoverWidth: CGFloat = 270
  private let ringSize: CGFloat = 170

  var body: some View {
    VStack(spacing: 16) {
      phaseHeader

      ringWithTime

      if timer.isWaitingForFocusApp {
        waitingBanner
      }

      sessionDots

      primaryControls

      secondaryControls

      Divider()
        .overlay(Theme.vineGreen.opacity(0.15))

      bottomRow
    }
    .padding(20)
    .frame(width: popoverWidth)
    .background(Theme.popoverGradient())
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: - Sections

  private var phaseHeader: some View {
    HStack(spacing: 8) {
      Image(systemName: timer.phase.systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Theme.color(for: timer.phase))
      Text(timer.phase.label)
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(Theme.color(for: timer.phase))
      Spacer()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Current phase: \(timer.phase.label)")
  }

  private var ringWithTime: some View {
    ZStack {
      CircularProgressView(
        progress: timer.progress,
        phase: timer.phase
      )

      VStack(spacing: 2) {
        Text(timer.formattedRemaining)
          .font(.system(size: 30, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.primary)
        Text(runStateLabel)
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
      }
    }
    .frame(width: ringSize, height: ringSize)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(timer.phase.label), \(timer.formattedRemaining) remaining, \(runStateLabel)"
    )
  }

  /// Banner shown when the timer is running but no focus app is frontmost.
  /// The timer holds (does not decrement) in this state.
  private var waitingBanner: some View {
    VStack(spacing: 4) {
      HStack(spacing: 6) {
        Image(systemName: "leaf.fill")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(Theme.vineGreen)
        Text("Paused — open a focus app")
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(Theme.vineGreen)
        Spacer()
      }

      if let frontmost = focusGuard.frontmostBundleId,
        !focusGuard.isFocusAppActive {
        HStack(spacing: 4) {
          Text("Current:")
            .font(.system(size: 10, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
          Text(frontmost)
            .font(.system(size: 10, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer()
        }
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(Theme.vineGreen.opacity(0.12), in: Capsule())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Timer paused, waiting for a focus app to become active")
  }

  private var sessionDots: some View {
    HStack(spacing: 6) {
      ForEach(0..<settings.sessionsBeforeLongBreak, id: \.self) { index in
        Capsule()
          .fill(
            index < timer.completedFocusSessions
              ? Theme.tomatoRed
              : Theme.vineGreen.opacity(0.25)
          )
          .frame(width: 16, height: 4)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "Progress: \(timer.completedFocusSessions) of " +
      "\(settings.sessionsBeforeLongBreak) focus sessions completed"
    )
  }

  private var primaryControls: some View {
    Button(action: { timer.toggleStartPause() }) {
      Text(primaryButtonTitle)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .tint(Theme.color(for: timer.phase))
    .controlSize(.large)
    .accessibilityLabel(primaryButtonTitle)
  }

  private var secondaryControls: some View {
    HStack(spacing: 10) {
      Button {
        timer.reset()
      } label: {
        Label("Reset", systemImage: "arrow.counterclockwise")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .accessibilityLabel("Reset timer")

      Button {
        timer.skip()
      } label: {
        Label("Skip", systemImage: "forward.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .accessibilityLabel("Skip to next phase")
    }
  }

  /// Bottom row uses `SettingsLink` — the documented, reliable way to open
  /// the Settings scene from a `MenuBarExtra` popover in an accessory
  /// (LSUIElement) app. `@Environment(\.openSettings)` is unreliable here.
  private var bottomRow: some View {
    HStack {
      SettingsLink {
        Label("Settings…", systemImage: "gearshape")
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("Open settings")

      Spacer()

      Button("Quit") {
        NSApp.terminate(nil)
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("Quit PomodoroBar")
    }
    .font(.system(size: 12, design: .rounded))
  }

  // MARK: - Derived strings

  private var runStateLabel: String {
    switch timer.runState {
    case .idle:
      "Ready"
    case .running:
      timer.isWaitingForFocusApp ? "Waiting" : "Running"
    case .paused:
      "Paused"
    }
  }

  private var primaryButtonTitle: String {
    switch timer.runState {
    case .idle:
      "Start"
    case .running:
      "Pause"
    case .paused:
      "Resume"
    }
  }
}