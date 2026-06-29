import SwiftUI

@main
struct PomodoroBarApp: App {
  @State private var timer: PomodoroTimer
  @State private var settings: AppSettings
  @State private var focusGuard: FocusGuard
  @State private var statistics: StatisticsStore

  init() {
    let s = AppSettings()
    let g = FocusGuard()
    let st = StatisticsStore()
    g.startMonitoring()
    _settings = State(initialValue: s)
    _focusGuard = State(initialValue: g)
    _statistics = State(initialValue: st)
    _timer = State(initialValue: PomodoroTimer(settings: s, focusGuard: g, statistics: st))
  }

  var body: some Scene {
    MenuBarExtra {
      MenuContentView()
        .environment(timer)
        .environment(settings)
        .environment(focusGuard)
        .environment(statistics)
    } label: {
      TimerMenuBarLabel(timer: timer, settings: settings)
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
        .environment(settings)
        .environment(focusGuard)
        .environment(statistics)
    }
  }
}