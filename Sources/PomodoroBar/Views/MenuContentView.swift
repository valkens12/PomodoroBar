import AppKit
import SwiftUI

/// The popover contents shown when the menu bar item is opened.
///
/// Renders a tomato-themed popover on a real Liquid Glass panel
/// (`.glassEffect()`, which adapts to light/dark automatically — no manual
/// appearance pinning needed): a phase header, a progress ring wrapping a
/// tomato with overlaid time, an optional "waiting for focus app" banner,
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

  /// True for a brief moment right after a focus session completes, driving
  /// a scale + glow pulse on the ring and a bump on the just-filled dot.
  @State private var celebrationPulse = false

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
    .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: - Sections

  private var phaseHeader: some View {
    HStack(spacing: 8) {
      Image(systemName: timer.phase.systemImage)
        .font(Typography.phaseIcon)
        .foregroundStyle(Theme.color(for: timer.phase))
      Text(timer.phase.label)
        .font(Typography.phaseTitle)
        .foregroundStyle(Theme.color(for: timer.phase))
      Spacer()
    }
    .animation(.easeInOut(duration: 0.35), value: timer.phase)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Current phase: \(timer.phase.label)")
  }

  private var ringWithTime: some View {
    ZStack {
      CircularProgressView(
        progress: timer.progress,
        phase: timer.phase,
        isRunning: timer.isRunning
      )

      VStack(spacing: 2) {
        Text(timer.formattedRemaining)
          .font(Typography.countdownDisplay)
          .monospacedDigit()
          .foregroundStyle(.primary)
        Text(runStateLabel)
          .font(Typography.stateCaption)
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
      }
    }
    .frame(width: ringSize, height: ringSize)
    .scaleEffect(celebrationPulse ? 1.08 : 1.0)
    .shadow(
      color: Theme.color(for: timer.phase).opacity(celebrationPulse ? 0.55 : 0),
      radius: celebrationPulse ? 18 : 0,
    )
    .animation(.spring(response: 0.35, dampingFraction: 0.45), value: celebrationPulse)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(timer.phase.label), \(timer.formattedRemaining) remaining, \(runStateLabel)"
    )
    .onChange(of: timer.focusCompletionTick) {
      celebrationPulse = true
      Task {
        try? await Task.sleep(for: .milliseconds(380))
        celebrationPulse = false
      }
    }
  }

  /// Banner shown when the timer is running but no focus app is frontmost.
  /// The timer holds (does not decrement) in this state.
  private var waitingBanner: some View {
    VStack(spacing: 4) {
      HStack(spacing: 6) {
        Image(systemName: "leaf.fill")
          .font(Typography.bannerIcon)
          .foregroundStyle(Theme.vineGreen)
        Text("Paused — open a focus app")
          .font(Typography.bannerTitle)
          .foregroundStyle(Theme.vineGreen)
        Spacer()
      }

      if focusGuard.frontmostBundleId != nil,
        !focusGuard.isFocusAppActive {
        HStack(spacing: 4) {
          Text("Current:")
            .font(Typography.bannerDetail)
            .foregroundStyle(.secondary)
          Text(focusGuard.frontmostAppName ?? focusGuard.frontmostBundleId ?? "")
            .font(Typography.bannerDetail)
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
        let isFilled = index < timer.completedFocusSessions
        let isJustFilled = index == timer.completedFocusSessions - 1

        Capsule()
          .fill(isFilled ? Theme.tomatoRed : Theme.vineGreen.opacity(0.25))
          .frame(width: 16, height: 4)
          .scaleEffect(isJustFilled && celebrationPulse ? 1.3 : 1.0)
      }
    }
    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: timer.completedFocusSessions)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "Progress: \(timer.completedFocusSessions) of " +
      "\(settings.sessionsBeforeLongBreak) focus sessions completed"
    )
  }

  private var primaryControls: some View {
    Button {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        timer.toggleStartPause()
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: primaryButtonSymbol)
          .contentTransition(.symbolEffect(.replace))
        Text(primaryButtonTitle)
          .contentTransition(.opacity)
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .tint(Theme.color(for: timer.phase))
    .controlSize(.large)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: timer.runState)
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
    .font(Typography.compactLabel)
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

  private var primaryButtonSymbol: String {
    switch timer.runState {
    case .idle, .paused:
      "play.fill"
    case .running:
      "pause.fill"
    }
  }
}