import ServiceManagement
import SwiftUI

/// Window scene identifiers, shared between the scene declarations below and
/// the `openWindow` call sites in the popover.
enum WindowId {
  static let statistics = "statistics"
}

@main
struct PomodoroBarApp: App {
  @State private var timer: PomodoroTimer
  @State private var settings: AppSettings
  @State private var focusGuard: FocusGuard
  @State private var statistics: StatisticsStore

  init() {
    // TEMPORARY diagnostic — exercised via
    //   POMO_DEBUG_LOGINITEM=1 build/PomodoroBar.app/Contents/MacOS/PomodoroBar
    // Remove once the launch-at-login investigation concludes.
    if ProcessInfo.processInfo.environment["POMO_DEBUG_LOGINITEM"] != nil {
      print("bundleId: \(Bundle.main.bundleIdentifier ?? "nil")")
      print("bundleURL: \(Bundle.main.bundleURL.path)")
      print("status before: \(SMAppService.mainApp.status.rawValue)")
      do {
        try SMAppService.mainApp.register()
        print("register: OK")
      } catch {
        print("register error: \(error)")
      }
      print("status after register: \(SMAppService.mainApp.status.rawValue)")
      do {
        try SMAppService.mainApp.unregister()
        print("unregister: OK")
      } catch {
        print("unregister error: \(error)")
      }
      print("status after unregister: \(SMAppService.mainApp.status.rawValue)")
      exit(0)
    }

    let s = AppSettings()
    let g = FocusGuard()
    let st = StatisticsStore()
    g.startMonitoring()
    let t = PomodoroTimer(settings: s, focusGuard: g, statistics: st)
    _settings = State(initialValue: s)
    _focusGuard = State(initialValue: g)
    _statistics = State(initialValue: st)
    _timer = State(initialValue: t)

    // Route notification action buttons (Start / Skip on a phase-change
    // banner) into the timer. By the time the notification is posted the
    // phase has already advanced and sits idle, so "start" is a plain start.
    NotificationManager.actionHandler = { action in
      switch action {
      case .startNext:
        t.start()
      case .skipNext:
        t.skip()
      }
    }

    // System-wide start/pause hotkey (recordable in Settings), if the user
    // opted in.
    HotkeyCenter.shared.onHotkey = {
      t.toggleStartPause()
    }
    HotkeyCenter.shared.setCombo(s.globalHotkey)
    HotkeyCenter.shared.setEnabled(s.globalHotkeyEnabled)

    // Ask for notification permission up front (no-op outside an app bundle,
    // and the system only ever prompts once) so the first phase-completion
    // notification can actually be delivered.
    if s.notificationsEnabled {
      Task { @MainActor in
        await NotificationManager.requestAuthorizationIfNeeded()
      }
    }
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
    }
    // Respect SettingsView's own min/max frame instead of letting the window
    // be dragged past its content into empty space.
    .windowResizability(.contentSize)

    Window("Statistics", id: WindowId.statistics) {
      StatisticsView()
        .environment(statistics)
        .frame(
          minWidth: 480, idealWidth: 540, maxWidth: 680,
          minHeight: 460, idealHeight: 600, maxHeight: 760,
        )
        .regularActivationWindow()
    }
    .windowResizability(.contentSize)
    .defaultSize(width: 540, height: 600)
  }
}
