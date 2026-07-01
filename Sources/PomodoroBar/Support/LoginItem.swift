import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` backing the "Launch at login"
/// toggle in Settings.
///
/// Registration only works when the process runs from an installed .app
/// bundle; during `swift run` development builds `isSupported` is false and
/// the toggle is disabled rather than failing silently.
@MainActor
enum LoginItem {
  /// True when the process runs from an app bundle that the service manager
  /// can register.
  static var isSupported: Bool {
    Bundle.main.bundleIdentifier != nil
  }

  /// Current registration state as reported by the system, so the toggle
  /// reflects changes made in System Settings > Login Items too.
  static var isEnabled: Bool {
    guard isSupported else { return false }
    return SMAppService.mainApp.status == .enabled
  }

  /// Attempts to (un)register and returns the *actual* resulting state, so a
  /// failed attempt snaps the toggle back instead of lying.
  @discardableResult
  static func setEnabled(_ enabled: Bool) -> Bool {
    guard isSupported else { return false }
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      // Fall through: the caller re-reads the real state below.
    }
    return isEnabled
  }
}
