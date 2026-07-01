import AppKit
import SwiftUI

// Native macOS settings window for PomodoroBar.
//
// Organized as a three-tab TabView (General / Focus Apps / Statistics) so the
// growing configuration surface stays scannable. The General tab preserves the
// original duration/cycle/automation/sound form; Focus Apps and Statistics live
// in their own files. The window activates the app on appear so it comes
// forward reliably from the menu bar popover of an accessory (LSUIElement) app.
struct SettingsView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(FocusGuard.self) private var focusGuard
  @Environment(StatisticsStore.self) private var statistics

  var body: some View {
    TabView {
      GeneralTab()
        .tabItem { Label("General", systemImage: "timer") }

      FocusAppsTab()
        .tabItem { Label("Focus Apps", systemImage: "lock.shield") }

      StatisticsTab()
        .tabItem { Label("Statistics", systemImage: "chart.bar.fill") }
    }
    .frame(
      minWidth: 460, idealWidth: 520, maxWidth: 640,
      minHeight: 420, idealHeight: 480, maxHeight: 640,
    )
    .onAppear {
      // Bring the settings window forward (accessory app does not auto-activate).
      NSApp.activate(ignoringOtherApps: true)
    }
  }
}

// MARK: - GeneralTab

/// Duration, cycle, automation, and sound preferences.
/// Uses @Bindable against the shared AppSettings instance so every change is
/// persisted to UserDefaults immediately via the model's didSet hooks.
private struct GeneralTab: View {
  @Environment(AppSettings.self) private var settings

  /// Mirrors `SMAppService` registration state; synced on appear so changes
  /// made in System Settings > Login Items are reflected too.
  @State private var launchAtLogin = false

  var body: some View {
    @Bindable var settings = settings

    Form {
      startupSection
      menuBarSection(settings: settings)
      durationsSection(settings: settings)
      cycleSection(settings: settings)
      automationSection(settings: settings)
      soundSection(settings: settings)
    }
    .formStyle(.grouped)
    .onAppear {
      launchAtLogin = LoginItem.isEnabled
    }
  }

  private var startupSection: some View {
    Section {
      Toggle(isOn: launchAtLoginBinding) {
        settingLabel("Launch at login", systemImage: "power", tint: Theme.tomatoOrange)
      }
      .disabled(!LoginItem.isSupported)
    } header: {
      Text("Startup")
    } footer: {
      Text(
        LoginItem.isSupported
          ? "Open PomodoroBar automatically when you log in."
          : "Launch at login is available when running the installed app."
      )
    }
  }

  /// Writes through to `SMAppService` and reads back the *actual* state, so a
  /// failed registration snaps the toggle back instead of showing a lie.
  private var launchAtLoginBinding: Binding<Bool> {
    Binding(
      get: { launchAtLogin },
      set: { launchAtLogin = LoginItem.setEnabled($0) },
    )
  }

  @ViewBuilder
  private func menuBarSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      Toggle(isOn: $settings.hideMenuBarTime) {
        settingLabel(
          "Hide time, show ripening tomato",
          systemImage: "leaf.fill",
          tint: Theme.leafGreen,
        )
      }
    } header: {
      Text("Menu Bar")
    } footer: {
      Text(
        "When on, the menu bar shows a tomato that ripens from green to red "
        + "as the session progresses, instead of the countdown."
      )
    }
  }

  // MARK: - Sections

  @ViewBuilder
  private func durationsSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      stepperRow(
        label: settingLabel("Focus", systemImage: "brain.head.profile", tint: Theme.tomatoRed),
        range: AppSettings.Bounds.focusMinutes,
        unit: "min",
        binding: $settings.focusMinutes,
      )
      stepperRow(
        label: settingLabel("Short Break", systemImage: "cup.and.saucer", tint: Theme.leafGreen),
        range: AppSettings.Bounds.shortBreakMinutes,
        unit: "min",
        binding: $settings.shortBreakMinutes,
      )
      stepperRow(
        label: settingLabel("Long Break", systemImage: "leaf", tint: Theme.vineGreen),
        range: AppSettings.Bounds.longBreakMinutes,
        unit: "min",
        binding: $settings.longBreakMinutes,
      )
    } header: {
      Text("Durations")
    } footer: {
      Text("Set how long each phase lasts in minutes.")
    }
  }

  @ViewBuilder
  private func cycleSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      stepperRow(
        label: settingLabel(
          "Sessions Before Long Break", systemImage: "repeat", tint: Theme.tomatoOrange,
        ),
        range: AppSettings.Bounds.sessionsBeforeLongBreak,
        unit: settings.sessionsBeforeLongBreak == 1 ? "session" : "sessions",
        binding: $settings.sessionsBeforeLongBreak,
      )
    } header: {
      Text("Cycle")
    } footer: {
      Text("Number of focus sessions before a long break.")
    }
  }

  @ViewBuilder
  private func automationSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      Toggle(isOn: $settings.autoStartBreaks) {
        settingLabel("Auto-start breaks", systemImage: "play.circle", tint: Theme.leafGreen)
      }
      Toggle(isOn: $settings.autoStartFocus) {
        settingLabel("Auto-start focus", systemImage: "arrow.forward.circle", tint: Theme.tomatoRed)
      }
    } header: {
      Text("Automation")
    } footer: {
      Text("Choose whether the next phase starts on its own.")
    }
  }

  @ViewBuilder
  private func soundSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      Toggle(isOn: $settings.notificationsEnabled) {
        settingLabel(
          "Phase change notification", systemImage: "bell.badge", tint: Theme.tomatoRed,
        )
      }
      .disabled(!NotificationManager.isSupported)
      .onChange(of: settings.notificationsEnabled) { _, enabled in
        if enabled {
          Task { await NotificationManager.requestAuthorizationIfNeeded() }
        }
      }
      Toggle(isOn: $settings.soundEnabled) {
        settingLabel("Phase change sound", systemImage: "bell", tint: Theme.tomatoOrange)
      }
      Toggle(isOn: $settings.tickEnabled) {
        settingLabel("Tick every second", systemImage: "metronome", tint: Theme.vineGreen)
      }
    } header: {
      Text("Alerts")
    } footer: {
      Text(
        "A notification makes the end of a session visible even when another "
        + "app is full-screen. Sounds play for phase changes and focus ticks."
      )
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
    .environment(StatisticsStore())
}