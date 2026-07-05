import AppKit
import SwiftUI

// Native macOS settings window for PomodoroBar.
//
// Organized as a two-tab TabView (General / Focus Apps) so the configuration
// surface stays scannable. The General tab preserves the original
// duration/cycle/automation/sound form; Focus Apps lives in its own file.
// Statistics are content, not configuration, and live in their own window
// (see `StatisticsView`).
//
// Focus handling: see `regularActivationWindow()` — the MenuBarExtra popover
// is a non-activating panel, so this window needs explicit activation-policy
// and key-focus management to accept keyboard input.
struct SettingsView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(FocusGuard.self) private var focusGuard

  var body: some View {
    VStack(spacing: 0) {
      TabView {
        GeneralTab()
          .tabItem {
            Label(String(localized: "settings.tab.general", defaultValue: "General"),
                  systemImage: "timer")
          }

        FocusAppsTab()
          .tabItem {
            Label(String(localized: "settings.tab.focusApps", defaultValue: "Focus Apps"),
                  systemImage: "lock.shield")
          }
      }
      versionFooter
    }
    .frame(
      minWidth: 460, idealWidth: 520, maxWidth: 640,
      minHeight: 420, idealHeight: 480, maxHeight: 640,
    )
    .regularActivationWindow()
  }

  /// The running app's marketing + build version, shown outside the TabView
  /// so it stays visible no matter which tab is selected — the one place in
  /// Settings a user can confirm what they actually have installed, without
  /// digging through Finder's Get Info or About This Mac-style lookups.
  private var versionFooter: some View {
    Text(Self.versionLabel)
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.vertical, 8)
  }

  private static var versionLabel: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return String(
      format: String(localized: "settings.version", defaultValue: "Version %@ (%@)"),
      locale: .current,
      version, build,
    )
  }
}

// MARK: - GeneralTab

/// Duration, cycle, automation, and sound preferences.
/// Uses @Bindable against the shared AppSettings instance so every change is
/// persisted to UserDefaults immediately via the model's didSet hooks.
private struct GeneralTab: View {
  @Environment(AppSettings.self) private var settings

  /// Mirrors `SMAppService` registration state; synced on appear and every
  /// time the app becomes active again, so approving the item in System
  /// Settings › Login Items is reflected the moment the user comes back.
  @State private var loginItemStatus: LoginItem.Status = .unsupported

  /// Human-readable reason the last (un)register attempt failed, shown
  /// inline — a toggle that silently snaps back looks broken.
  @State private var loginItemError: String?

  /// Ko-fi page for the Support row. The Ko-fi widget embed is web-only, so
  /// the native equivalent is a button that opens this page in the default
  /// browser. The ID matches the widget embed (`Y8Y01QFKCC`).
  private static let kofiURL = URL(string: "https://ko-fi.com/Y8Y01QFKCC")!

  var body: some View {
    @Bindable var settings = settings

    Form {
      startupSection
      menuBarSection(settings: settings)
      keyboardSection(settings: settings)
      durationsSection(settings: settings)
      cycleSection(settings: settings)
      automationSection(settings: settings)
      soundSection(settings: settings)
      statisticsSection(settings: settings)
      supportSection
    }
    .formStyle(.grouped)
    .onAppear {
      loginItemStatus = LoginItem.status
    }
    .onReceive(
      NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
    ) { _ in
      loginItemStatus = LoginItem.status
    }
  }

  private var startupSection: some View {
    Section {
      Toggle(isOn: launchAtLoginBinding) {
        settingLabel(
          String(localized: "startup.label", defaultValue: "Launch at login"),
          systemImage: "power",
          tint: Theme.tomatoOrange,
        )
      }
      .disabled(loginItemStatus == .unsupported)

      if loginItemStatus == .requiresApproval {
        approvalNeededNotice
      }

      if let loginItemError {
        HStack(spacing: 4) {
          Image(systemName: "xmark.octagon.fill")
            .foregroundStyle(.red)
          Text(loginItemError)
            .foregroundStyle(.secondary)
        }
        .font(.system(.caption, design: .rounded))
      }
    } header: {
      Text(String(localized: "startup.header", defaultValue: "Startup"))
    } footer: {
      Text(
        loginItemStatus == .unsupported
          ? String(
            localized: "startup.footer.unsupported",
            defaultValue: "Launch at login is available when running the installed app."
          )
          : String(
            localized: "startup.footer.normal",
            defaultValue: "Open PomodoroBar automatically when you log in."
          )
      )
    }
  }

  /// A successful registration can still be withheld by macOS pending the
  /// user's approval — surfaced here with a direct route to the approval
  /// checkbox, instead of the toggle mysteriously snapping off.
  private var approvalNeededNotice: some View {
    HStack(spacing: 4) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
      Text(
        String(
          localized: "startup.approvalNotice",
          defaultValue: "Needs your approval in Login Items."
        )
      )
        .foregroundStyle(.secondary)
      Button(
        String(
          localized: "startup.openSettings",
          defaultValue: "Open Settings…"
        )
      ) {
        LoginItem.openLoginItemsSettings()
      }
      .buttonStyle(.link)
    }
    .font(.system(.caption, design: .rounded))
  }

  /// Writes through to `SMAppService` and reads back the *actual* status.
  /// "Requires approval" counts as on — the registration exists; only the
  /// system's activation is pending — so the toggle holds the user's intent
  /// while the notice explains the remaining step.
  private var launchAtLoginBinding: Binding<Bool> {
    Binding(
      get: {
        loginItemStatus == .enabled || loginItemStatus == .requiresApproval
      },
      set: { enabled in
        let result = LoginItem.setEnabled(enabled)
        loginItemStatus = result.status
        loginItemError = result.errorDescription
      },
    )
  }

  @ViewBuilder
  private func menuBarSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      Toggle(isOn: $settings.hideMenuBarTime) {
        settingLabel(
          String(
            localized: "menuBar.hideTime",
            defaultValue: "Hide time, show ripening tomato"
          ),
          systemImage: "leaf.fill",
          tint: Theme.leafGreen,
        )
      }
      Toggle(isOn: $settings.monochromeMenuBarIcon) {
        settingLabel(
          String(localized: "menuBar.monochrome", defaultValue: "Monochrome icon"),
          systemImage: "circle.lefthalf.filled",
          tint: Theme.vineGreen,
        )
      }
    } header: {
      Text(String(localized: "menuBar.header", defaultValue: "Menu Bar"))
    } footer: {
      Text(String(
        localized: "menuBar.footer",
        defaultValue: "The ripening tomato replaces the countdown, going green to red as the session progresses. The monochrome icon matches the built-in menu bar items and adapts to the menu bar's appearance."
      ))
    }
  }

  @ViewBuilder
  private func keyboardSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      Toggle(isOn: $settings.globalHotkeyEnabled) {
        settingLabel(
          String(
            localized: "keyboard.globalEnabled",
            defaultValue: "Start / pause from anywhere"
          ),
          systemImage: "keyboard",
          tint: Theme.tomatoOrange,
        )
      }
      .onChange(of: settings.globalHotkeyEnabled) { _, enabled in
        HotkeyCenter.shared.setEnabled(enabled)
      }

      LabeledContent {
        HotkeyRecorderField(combo: $settings.globalHotkey)
      } label: {
        settingLabel(
          String(localized: "keyboard.shortcut", defaultValue: "Shortcut"),
          systemImage: "command",
          tint: Theme.vineGreen,
        )
      }
      .disabled(!settings.globalHotkeyEnabled)
    } header: {
      Text(String(localized: "keyboard.header", defaultValue: "Keyboard"))
    } footer: {
      let shortcut = settings.globalHotkey.displayString
      Text(String(
        format: String(
          localized: "keyboard.footer",
          defaultValue: "When on, %@ toggles the timer system-wide, even while another app is active. Click the shortcut to record a different one."
        ),
        locale: .current,
        shortcut,
      ))
    }
  }

  // MARK: - Sections

  @ViewBuilder
  private func durationsSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      stepperRow(
        label: settingLabel(
          String(localized: "durations.focus", defaultValue: "Focus"),
          systemImage: "brain.head.profile",
          tint: Theme.tomatoRed,
        ),
        range: AppSettings.Bounds.focusMinutes,
        unit: String(localized: "unit.minutes", defaultValue: "min"),
        binding: $settings.focusMinutes,
      )
      stepperRow(
        label: settingLabel(
          String(localized: "durations.shortBreak", defaultValue: "Short Break"),
          systemImage: "cup.and.saucer",
          tint: Theme.leafGreen,
        ),
        range: AppSettings.Bounds.shortBreakMinutes,
        unit: String(localized: "unit.minutes", defaultValue: "min"),
        binding: $settings.shortBreakMinutes,
      )
      stepperRow(
        label: settingLabel(
          String(localized: "durations.longBreak", defaultValue: "Long Break"),
          systemImage: "leaf",
          tint: Theme.vineGreen,
        ),
        range: AppSettings.Bounds.longBreakMinutes,
        unit: String(localized: "unit.minutes", defaultValue: "min"),
        binding: $settings.longBreakMinutes,
      )
    } header: {
      Text(String(localized: "durations.header", defaultValue: "Durations"))
    } footer: {
      Text(
        String(
          localized: "durations.footer",
          defaultValue: "Set how long each phase lasts in minutes."
        )
      )
    }
  }

  @ViewBuilder
  private func cycleSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      stepperRow(
        label: settingLabel(
          String(
            localized: "cycle.sessionsBeforeLong",
            defaultValue: "Sessions Before Long Break"
          ),
          systemImage: "repeat",
          tint: Theme.tomatoOrange,
        ),
        range: AppSettings.Bounds.sessionsBeforeLongBreak,
        unit: String(
          localized: settings.sessionsBeforeLongBreak == 1 ? "unit.session" : "unit.sessions",
          defaultValue: settings.sessionsBeforeLongBreak == 1 ? "session" : "sessions",
        ),
        binding: $settings.sessionsBeforeLongBreak,
      )
    } header: {
      Text(String(localized: "cycle.header", defaultValue: "Cycle"))
    } footer: {
      Text(
        String(
          localized: "cycle.footer",
          defaultValue: "Number of focus sessions before a long break."
        )
      )
    }
  }

  @ViewBuilder
  private func automationSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      Toggle(isOn: $settings.autoStartBreaks) {
        settingLabel(
          String(localized: "automation.autoStartBreaks", defaultValue: "Auto-start breaks"),
          systemImage: "play.circle",
          tint: Theme.leafGreen,
        )
      }
      Toggle(isOn: $settings.autoStartFocus) {
        settingLabel(
          String(localized: "automation.autoStartFocus", defaultValue: "Auto-start focus"),
          systemImage: "arrow.forward.circle",
          tint: Theme.tomatoRed,
        )
      }
    } header: {
      Text(String(localized: "automation.header", defaultValue: "Automation"))
    } footer: {
      Text(
        String(
          localized: "automation.footer",
          defaultValue: "Choose whether the next phase starts on its own."
        )
      )
    }
  }

  @ViewBuilder
  private func soundSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      Toggle(isOn: $settings.notificationsEnabled) {
        settingLabel(
          String(
            localized: "alerts.notification",
            defaultValue: "Phase change notification"
          ),
          systemImage: "bell.badge",
          tint: Theme.tomatoRed,
        )
      }
      .disabled(!NotificationManager.isSupported)
      .onChange(of: settings.notificationsEnabled) { _, enabled in
        if enabled {
          Task { await NotificationManager.requestAuthorizationIfNeeded() }
        }
      }
      Toggle(isOn: $settings.soundEnabled) {
        settingLabel(
          String(localized: "alerts.sound", defaultValue: "Phase change sound"),
          systemImage: "bell",
          tint: Theme.tomatoOrange,
        )
      }
      Toggle(isOn: $settings.tickEnabled) {
        settingLabel(
          String(localized: "alerts.tick", defaultValue: "Tick every second"),
          systemImage: "metronome",
          tint: Theme.vineGreen,
        )
      }
    } header: {
      Text(String(localized: "alerts.header", defaultValue: "Alerts"))
    } footer: {
      Text(String(
        localized: "alerts.footer",
        defaultValue: "A notification makes the end of a session visible even when another app is full-screen. Sounds play for phase changes and focus ticks."
      ))
    }
  }

  /// Only rendered on Apple Intelligence hardware — the toggle would be
  /// dead weight everywhere else, since `StatisticsView` never shows the
  /// card those machines can't generate anyway.
  @ViewBuilder
  private func statisticsSection(settings: AppSettings) -> some View {
    if StatisticsSummaryGenerator.isSupported {
      @Bindable var settings = settings
      Section {
        Toggle(isOn: $settings.aiSummaryEnabled) {
          settingLabel(
            String(localized: "statistics.aiSummary.toggle", defaultValue: "AI Overview"),
            systemImage: "sparkles",
            tint: Theme.tomatoOrange,
          )
        }
        Toggle(isOn: $settings.aiSummaryDarkHumor) {
          settingLabel(
            String(
              localized: "statistics.aiSummary.darkHumor.toggle",
              defaultValue: "Dark Humor"
            ),
            systemImage: "flame.fill",
            tint: Theme.tomatoRed,
          )
        }
        .disabled(!settings.aiSummaryEnabled)
      } header: {
        Text(String(localized: "statistics.header", defaultValue: "Statistics"))
      } footer: {
        Text(String(
          localized: "statistics.aiSummary.footer",
          defaultValue:
            "A short summary of your focus history, generated on-device using Apple Intelligence — nothing is sent off your Mac. Dark Humor swaps the pep talk for a sarcastic roast; Apple's own safety filters get the final say, so it may just decline and leave the card blank."
        ))
      }
    }
  }

  // MARK: - Support section

  /// Renders the official Ko-fi "Support me on Ko-fi" badge as a clickable
  /// link. The badge is bundled as an image set (Resources/Assets.xcassets/
  /// KoFiBadge.imageset), so the app never fetches it from the network and
  /// the row works offline. The whole row is tappable, matching the visual
  /// weight of the official button.
  private var supportSection: some View {
    Section {
      Link(destination: Self.kofiURL) {
        HStack {
          Image("KoFiBadge")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 36)
            .accessibilityLabel(
              String(
                localized: "support.kofi.a11y",
                defaultValue: "Support me on Ko-fi (opens in your browser)"
              )
            )
          Spacer()
        }
      }
      .buttonStyle(.plain)
    } header: {
      Text(String(localized: "support.header", defaultValue: "Support"))
    } footer: {
      Text(String(
        localized: "support.footer",
        defaultValue: "If PomodoroBar helps you focus, you can buy me a coffee on Ko-fi. Totally optional!"
      ))
    }
  }

  // MARK: - Helpers

  /// A form label with neutral text and a tinted SF Symbol — the tomato
  /// palette stays on the icon, where contrast requirements are looser and
  /// the text remains fully legible in both appearances.
  private func settingLabel(
    _ title: String,
    systemImage: String,
    tint: Color,
  ) -> some View {
    Label {
      Text(title)
    } icon: {
      Image(systemName: systemImage)
        .foregroundStyle(tint)
    }
  }

  /// A labeled row with a typed numeric field (so the value can be entered
  /// directly from the keyboard) plus a Stepper for click adjustment. The
  /// field's binding clamps to `range` on commit — typing a value outside the
  /// bound snaps to the nearest edge instead of silently accepting it.
  @ViewBuilder
  private func stepperRow(
    label: some View,
    range: ClosedRange<Int>,
    unit: String,
    binding: Binding<Int>,
  ) -> some View {
    HStack {
      label
      Spacer()
      TextField("", value: clampedBinding(binding, range: range), format: .number)
        .frame(width: 40)
        .multilineTextAlignment(.trailing)
        .font(.system(.body, design: .rounded).monospacedDigit())
        .textFieldStyle(.roundedBorder)
        .labelsHidden()
        .accessibilityLabel(unit)
      Text(unit)
        .font(.system(.body, design: .rounded))
        .foregroundStyle(.secondary)
      Stepper(value: binding, in: range) {
        EmptyView()
      }
      .labelsHidden()
    }
  }

  /// Wraps `binding` so out-of-range input clamps to `range` on commit,
  /// instead of being persisted as-is (the underlying setting's `didSet`
  /// only persists — it doesn't re-clamp — so clamping happens here).
  private func clampedBinding(_ binding: Binding<Int>, range: ClosedRange<Int>) -> Binding<Int> {
    Binding(
      get: { binding.wrappedValue },
      set: { binding.wrappedValue = min(max($0, range.lowerBound), range.upperBound) },
    )
  }
}

#Preview {
  SettingsView()
    .environment(AppSettings())
    .environment(FocusGuard())
}
