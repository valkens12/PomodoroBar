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

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 16) {
      phaseHeader

      ringWithTime

      if timer.isWaitingForFocusApp {
        waitingBanner
      }

      sessionDots

      if statistics.todaySessions > 0 {
        todaySummary
      }

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
        .foregroundStyle(Theme.textColor(for: timer.phase))
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
      // The pulse is purely celebratory — skip it entirely under Reduce
      // Motion, matching the start pop in CircularProgressView.
      guard !reduceMotion else { return }
      celebrationPulse = true
      Task {
        try? await Task.sleep(for: .milliseconds(380))
        celebrationPulse = false
      }
    }
  }

  /// Banner shown when the timer is running but the countdown is held —
  /// either the frontmost app isn't a focus app at all (`.wrongApp`), or
  /// Safari is frontmost with focus-domains configured and the current tab
  /// doesn't match one of them (`.wrongTab`). The timer never decrements in
  /// either state.
  private var waitingBanner: some View {
    VStack(spacing: 4) {
      switch timer.focusWaitReason {
      case .notWaiting:
        EmptyView()
      case .wrongApp:
        wrongAppBannerContent
      case .wrongTab:
        wrongTabBannerContent
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      Theme.vineGreen.opacity(0.12),
      in: RoundedRectangle(cornerRadius: 10, style: .continuous),
    )
  }

  /// Content for `.wrongApp`: offers a one-click jump back into the first
  /// focus app so the banner isn't a dead end.
  private var wrongAppBannerContent: some View {
    Group {
      HStack(spacing: 6) {
        Image(systemName: "leaf.fill")
          .font(Typography.bannerIcon)
          .foregroundStyle(Theme.vineGreen)
        Text("Paused — open a focus app")
          .font(Typography.bannerTitle)
          .foregroundStyle(Theme.textColor(for: .longBreak))
        Spacer()
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Timer paused, waiting for a focus app to become active")

      if let frontmostName = focusGuard.frontmostAppName ?? focusGuard.frontmostBundleId {
        bannerDetailRow(label: "Current:", value: frontmostName)
      }

      if let firstApp = focusGuard.focusApps.first {
        HStack {
          Button {
            focusGuard.openFirstFocusApp()
          } label: {
            Label("Open \(firstApp.name)", systemImage: "arrow.up.forward.app")
              .font(Typography.bannerDetail)
          }
          .buttonStyle(.borderless)
          .tint(Theme.textColor(for: .longBreak))
          .help("Bring \(firstApp.name) to the front so the timer resumes")
          .accessibilityLabel("Open \(firstApp.name)")
          Spacer()
        }
      }
    }
  }

  /// Content for `.wrongTab`: Safari is already frontmost, so there's
  /// nothing to "open" — instead show which site is active and which sites
  /// would count.
  private var wrongTabBannerContent: some View {
    Group {
      HStack(spacing: 6) {
        Image(systemName: "safari")
          .font(Typography.bannerIcon)
          .foregroundStyle(Theme.vineGreen)
        Text("Paused — wrong tab")
          .font(Typography.bannerTitle)
          .foregroundStyle(Theme.textColor(for: .longBreak))
        Spacer()
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Timer paused, current Safari tab isn't a focus website")

      if let host = focusGuard.frontmostTabHost {
        bannerDetailRow(label: "Current:", value: host)
      }

      if let allowedDomains = safariFocusDomains, !allowedDomains.isEmpty {
        bannerDetailRow(label: "Allowed:", value: allowedDomains.joined(separator: ", "))
      }
    }
  }

  private var safariFocusDomains: [String]? {
    focusGuard.focusApps.first { $0.bundleId == WellKnownBundleId.safari }?.focusDomains
  }

  /// Shared "Label: value" line used by both banner variants.
  private func bannerDetailRow(label: String, value: String) -> some View {
    HStack(spacing: 4) {
      Text(label)
        .font(Typography.bannerDetail)
        .foregroundStyle(.secondary)
      Text(value)
        .font(Typography.bannerDetail)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer()
    }
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

  /// One-line glance at today's progress, surfacing the statistics that
  /// otherwise live three clicks away in Settings.
  private var todaySummary: some View {
    Text(
      "Today: \(statistics.todayMinutes)m · \(statistics.todaySessions) "
      + (statistics.todaySessions == 1 ? "session" : "sessions")
    )
    .font(Typography.stateCaption)
    .foregroundStyle(.secondary)
    .accessibilityLabel(
      "Today: \(statistics.todayMinutes) focus minutes, "
      + "\(statistics.todaySessions) sessions"
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
    .keyboardShortcut(.space, modifiers: [])
    .help("\(primaryButtonTitle) the timer (Space)")
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: timer.runState)
    .accessibilityLabel(primaryButtonTitle)
  }

  /// Reset is a no-op when the timer is idle at the top of a phase, so it's
  /// disabled there; Skip stays enabled because advancing the phase is
  /// meaningful even while idle.
  private var isResetNoOp: Bool {
    timer.runState == .idle && timer.remainingSeconds == timer.totalSeconds
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
      .disabled(isResetNoOp)
      .keyboardShortcut("r")
      .help("Restart the current phase from the beginning (⌘R)")
      .accessibilityLabel("Reset timer")

      Button {
        timer.skip()
      } label: {
        Label("Skip", systemImage: "forward.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .keyboardShortcut("s")
      .help("Skip ahead to the next phase (⌘S)")
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
      .keyboardShortcut(",")
      .help("Open PomodoroBar settings (⌘,)")
      .accessibilityLabel("Open settings")

      Spacer()

      Button("Quit") {
        NSApp.terminate(nil)
      }
      .buttonStyle(.borderless)
      .keyboardShortcut("q")
      .help("Quit PomodoroBar (⌘Q)")
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