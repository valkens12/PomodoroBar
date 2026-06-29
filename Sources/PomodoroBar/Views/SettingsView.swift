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
    .frame(minWidth: 460, minHeight: 420)
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

  var body: some View {
    @Bindable var settings = settings

    Form {
      menuBarSection(settings: settings)
      durationsSection(settings: settings)
      cycleSection(settings: settings)
      automationSection(settings: settings)
      soundSection(settings: settings)
    }
    .formStyle(.grouped)
  }

  @ViewBuilder
  private func menuBarSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      Toggle(isOn: $settings.hideMenuBarTime) {
        Label("Hide time, show ripening tomato", systemImage: "leaf.fill")
          .foregroundStyle(Theme.leafGreen)
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
        label: Label("Focus", systemImage: "brain.head.profile")
          .foregroundStyle(Theme.tomatoRed),
        value: settings.focusMinutes,
        range: 5...90,
        unit: "min",
        binding: $settings.focusMinutes,
      )
      stepperRow(
        label: Label("Short Break", systemImage: "cup.and.saucer")
          .foregroundStyle(Theme.leafGreen),
        value: settings.shortBreakMinutes,
        range: 1...30,
        unit: "min",
        binding: $settings.shortBreakMinutes,
      )
      stepperRow(
        label: Label("Long Break", systemImage: "leaf")
          .foregroundStyle(Theme.vineGreen),
        value: settings.longBreakMinutes,
        range: 5...60,
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
        label: Label("Sessions Before Long Break", systemImage: "repeat")
          .foregroundStyle(Theme.tomatoOrange),
        value: settings.sessionsBeforeLongBreak,
        range: 2...8,
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
        Label("Auto-start breaks", systemImage: "play.circle")
          .foregroundStyle(Theme.leafGreen)
      }
      Toggle(isOn: $settings.autoStartFocus) {
        Label("Auto-start focus", systemImage: "arrow.forward.circle")
          .foregroundStyle(Theme.tomatoRed)
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
      Toggle(isOn: $settings.soundEnabled) {
        Label("Phase change sound", systemImage: "bell")
          .foregroundStyle(Theme.tomatoOrange)
      }
      Toggle(isOn: $settings.tickEnabled) {
        Label("Tick every second", systemImage: "metronome")
          .foregroundStyle(Theme.vineGreen)
      }
    } header: {
      Text("Sound")
    } footer: {
      Text("Audio cues for phase changes and focus ticks.")
    }
  }

  // MARK: - Helpers

  /// A labeled row that shows the current value and lets the user step it.
  /// The value is rendered as its own Text (NOT as the Stepper's label, which
  /// `.labelsHidden()` would conceal — that made the number invisible and the
  /// arrows appear to do nothing).
  @ViewBuilder
  private func stepperRow(
    label: some View,
    value: Int,
    range: ClosedRange<Int>,
    unit: String,
    binding: Binding<Int>,
  ) -> some View {
    HStack {
      label
      Spacer()
      Text("\(value) \(unit)")
        .font(.system(.body, design: .rounded).monospacedDigit())
        .foregroundStyle(.primary)
      Stepper(value: binding, in: range) {
        EmptyView()
      }
      .labelsHidden()
    }
  }
}

#Preview {
  SettingsView()
    .environment(AppSettings())
    .environment(FocusGuard())
    .environment(StatisticsStore())
}