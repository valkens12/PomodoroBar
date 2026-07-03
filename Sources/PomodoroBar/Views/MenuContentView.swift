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
  @Environment(\.openWindow) private var openWindow

  private let popoverWidth: CGFloat = 270
  private let ringSize: CGFloat = 170

  /// True for a brief moment right after a focus session completes, driving
  /// a scale + glow pulse on the ring and a bump on the just-filled dot.
  @State private var celebrationPulse = false

  /// Gates Skip behind a confirmation while a focus session is in flight —
  /// skipping discards the session unrecorded, so a single stray click
  /// shouldn't be able to do it.
  @State private var showSkipConfirmation = false

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
        .contentTransition(.symbolEffect(.replace))
      Text(timer.phase.label)
        .font(Typography.phaseTitle)
        .foregroundStyle(Theme.textColor(for: timer.phase))
        .contentTransition(.opacity)
      Spacer()
    }
    .animation(.easeInOut(duration: 0.35), value: timer.phase)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      String(
        format: String(localized: "phaseHeader.a11y", defaultValue: "Current phase: %@"),
        locale: .current,
        timer.phase.label,
      )
    )
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
          // Digits roll over instead of snapping. `numericText` is a
          // content transition, so Reduce Motion is skipped explicitly like
          // every other flourish in this view.
          .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
          .animation(.linear(duration: 0.2), value: timer.remainingSeconds)
        Text(runStateLabel)
          .font(Typography.stateCaption)
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
          .contentTransition(.opacity)
          .animation(.easeInOut(duration: 0.2), value: runStateLabel)
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
      String(
        format: String(
          localized: "phaseHeader.combined", defaultValue: "%1$@, %2$@ remaining, %3$@"
        ),
        locale: .current,
        timer.phase.label, timer.formattedRemaining, runStateLabel,
      )
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
        Text(String(localized: "banner.wrongApp", defaultValue: "Paused — open a focus app"))
          .font(Typography.bannerTitle)
          .foregroundStyle(Theme.textColor(for: .longBreak))
        Spacer()
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
        String(localized: "banner.wrongApp.a11y",
               defaultValue: "Timer paused, waiting for a focus app to become active")
      )

      if let frontmostName = focusGuard.frontmostAppName ?? focusGuard.frontmostBundleId {
        bannerDetailRow(
          label: String(
            localized: "banner.detailCurrent", defaultValue: "Current:"
          ),
          value: frontmostName,
        )
      }

      if let firstApp = focusGuard.focusApps.first {
        HStack {
          Button {
            focusGuard.openFirstFocusApp()
          } label: {
            Label(
              String(
                format: String(localized: "banner.openAppPrefix", defaultValue: "Open %@"),
                firstApp.name,
              ),
              systemImage: "arrow.up.forward.app",
            )
            .font(Typography.bannerDetail)
          }
          .buttonStyle(.borderless)
          .tint(Theme.textColor(for: .longBreak))
          .help(
            String(
              format: String(
                localized: "banner.bringApp", defaultValue: "Bring %@ to the front so the timer resumes"
              ),
              firstApp.name,
            )
          )
          .accessibilityLabel(
            String(
              format: String(
                localized: "banner.openAppPrefix", defaultValue: "Open %@"
              ),
              firstApp.name,
            )
          )
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
        Text(String(localized: "banner.wrongTab", defaultValue: "Paused — wrong tab"))
          .font(Typography.bannerTitle)
          .foregroundStyle(Theme.textColor(for: .longBreak))
        Spacer()
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
        String(
          localized: "banner.wrongTab.a11y",
          defaultValue: "Timer paused, current Safari tab isn't a focus website",
        )
      )

      if let host = focusGuard.frontmostTabHost {
        bannerDetailRow(
          label: String(
            localized: "banner.detailCurrent", defaultValue: "Current:"
          ),
          value: host,
        )
      }

      if let allowedDomains = safariFocusDomains, !allowedDomains.isEmpty {
        bannerDetailRow(
          label: String(
            localized: "banner.detailAllowed", defaultValue: "Allowed:"
          ),
          value: allowedDomains.joined(separator: ", "),
        )
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
      String(
        format: String(
          localized: "dots.a11y",
          defaultValue: "Progress: %1$lld of %2$lld focus sessions completed"
        ),
        locale: .current,
        timer.completedFocusSessions, settings.sessionsBeforeLongBreak,
      )
    )
  }

  /// One-line glance at today's progress, doubling as a shortcut into the
  /// Statistics window.
  private var todaySummary: some View {
    Button {
      openWindow(id: WindowId.statistics)
    } label: {
      HStack(spacing: 3) {
        let unit = String(
          localized: statistics.todaySessions == 1 ? "unit.session" : "unit.sessions",
          defaultValue: statistics.todaySessions == 1 ? "session" : "sessions",
        )
        Text(
          String(
            format: String(
              localized: statistics.todaySessions == 1
                ? "todaySummary.singular" : "todaySummary.plural",
              defaultValue: statistics.todaySessions == 1
                ? "Today: %1$lldm · %2$@ session"
                : "Today: %1$lldm · %2$@ sessions"
            ),
            locale: .current,
            statistics.todayMinutes, unit,
          )
        )
        Image(systemName: "chevron.right")
          .font(.system(size: 8, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .font(Typography.stateCaption)
      .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .help(String(localized: "todaySummary.help", defaultValue: "Show your focus history"))
    .accessibilityLabel(
      String(
        format: String(
          localized: "todaySummary.a11y",
          defaultValue: "Today: %1$lld focus minutes, %2$lld sessions"
        ),
        locale: .current,
        statistics.todayMinutes, statistics.todaySessions,
      )
    )
    .accessibilityHint(
      String(localized: "todaySummary.hint", defaultValue: "Opens the statistics window.")
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
    // buttonTint, not color(for:): the prominent style draws white label
    // text, and the raw break greens don't give white text 4.5:1 contrast.
    .tint(Theme.buttonTint(for: timer.phase))
    .controlSize(.large)
    .keyboardShortcut(.space, modifiers: [])
    .help(
      String(
        format: String(
          localized: "control.primary.help", defaultValue: "%@ the timer (Space)"
        ),
        primaryButtonTitle,
      )
    )
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: timer.runState)
    .accessibilityLabel(primaryButtonTitle)
  }

  /// Reset is a no-op when the timer is idle at the top of a phase, so it's
  /// disabled there; Skip stays enabled because advancing the phase is
  /// meaningful even while idle.
  private var isResetNoOp: Bool {
    timer.runState == .idle && timer.remainingSeconds == timer.totalSeconds
  }

  /// True when skipping right now would throw away a focus session that has
  /// made progress — that deserves a confirmation; skipping an untouched
  /// phase or a break stays one click.
  private var skipDiscardsFocusProgress: Bool {
    timer.phase == .focus && timer.remainingSeconds < timer.totalSeconds
  }

  private var secondaryControls: some View {
    HStack(spacing: 10) {
      Button {
        timer.reset()
      } label: {
        Label(
          String(localized: "control.reset", defaultValue: "Reset"),
          systemImage: "arrow.counterclockwise",
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .disabled(isResetNoOp)
      .keyboardShortcut("r")
      .help(
        String(localized: "control.reset.help", defaultValue: "Restart the current phase from the beginning (⌘R)")
      )
      .accessibilityLabel(
        String(localized: "control.reset.a11y", defaultValue: "Reset timer")
      )

      Button {
        if skipDiscardsFocusProgress {
          showSkipConfirmation = true
        } else {
          timer.skip()
        }
      } label: {
        Label(
          String(localized: "control.skip", defaultValue: "Skip"),
          systemImage: "forward.fill",
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .keyboardShortcut(.rightArrow, modifiers: .command)
      .help(
        String(localized: "control.skip.help", defaultValue: "Skip ahead to the next phase (⌘→)")
      )
      .accessibilityLabel(
        String(localized: "control.skip.a11y", defaultValue: "Skip to next phase")
      )
      .confirmationDialog(
        String(
          localized: "skip.confirm.title",
          defaultValue: "Skip this focus session?",
        ),
        isPresented: $showSkipConfirmation,
      ) {
        Button(
          String(localized: "skip.confirm.action", defaultValue: "Skip Session"),
          role: .destructive,
        ) {
          timer.skip()
        }
        Button(
          String(localized: "skip.confirm.cancel", defaultValue: "Cancel"),
          role: .cancel,
        ) {}
      } message: {
        Text(
          String(
            localized: "skip.confirm.message",
            defaultValue: "Skipped sessions aren't recorded in your statistics.",
          )
        )
      }
    }
  }

  /// Bottom row uses `SettingsLink` — the documented, reliable way to open
  /// the Settings scene from a `MenuBarExtra` popover in an accessory
  /// (LSUIElement) app. `@Environment(\.openSettings)` is unreliable here.
  /// All three entries are plain text, menu-item style, so no one action
  /// looks more decorated than its neighbors.
  private var bottomRow: some View {
    HStack {
      SettingsLink {
        Text(String(localized: "bottomRow.settings.label", defaultValue: "Settings…"))
      }
      .buttonStyle(.borderless)
      .keyboardShortcut(",")
      .help(
        String(localized: "bottomRow.settings.help", defaultValue: "Open PomodoroBar settings (⌘,)")
      )
      .accessibilityLabel(
        String(localized: "bottomRow.settings.a11y", defaultValue: "Open settings")
      )

      Spacer()

      Button(String(localized: "bottomRow.statistics.label", defaultValue: "Statistics…")) {
        openWindow(id: WindowId.statistics)
      }
      .buttonStyle(.borderless)
      .help(
        String(localized: "bottomRow.statistics.help", defaultValue: "Show your focus history")
      )
      .accessibilityLabel(
        String(localized: "bottomRow.statistics.a11y", defaultValue: "Open statistics")
      )

      Spacer()

      Button(String(localized: "bottomRow.quit.label", defaultValue: "Quit")) {
        NSApp.terminate(nil)
      }
      .buttonStyle(.borderless)
      .keyboardShortcut("q")
      .help(
        String(localized: "bottomRow.quit.help", defaultValue: "Quit PomodoroBar (⌘Q)")
      )
      .accessibilityLabel(
        String(localized: "bottomRow.quit.a11y", defaultValue: "Quit PomodoroBar")
      )
    }
    .font(Typography.compactLabel)
  }

  // MARK: - Derived strings

  private var runStateLabel: String {
    switch timer.runState {
    case .idle:
      return String(localized: "runState.idle", defaultValue: "Ready")
    case .running:
      return timer.isWaitingForFocusApp
        ? String(localized: "runState.waiting", defaultValue: "Waiting")
        : String(localized: "runState.running", defaultValue: "Running")
    case .paused:
      return String(localized: "runState.paused", defaultValue: "Paused")
    }
  }

  private var primaryButtonTitle: String {
    switch timer.runState {
    case .idle:
      return String(localized: "control.start", defaultValue: "Start")
    case .running:
      return String(localized: "control.pause", defaultValue: "Pause")
    case .paused:
      return String(localized: "control.resume", defaultValue: "Resume")
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