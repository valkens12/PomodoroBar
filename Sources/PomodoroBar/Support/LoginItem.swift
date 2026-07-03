import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` backing the "Launch at login"
/// toggle in Settings.
///
/// Registration only works when the process runs from an installed .app
/// bundle; during `swift run` development builds the status is `.unsupported`
/// and the toggle is disabled rather than failing silently.
///
/// On modern macOS a successful `register()` frequently lands in
/// `.requiresApproval` — the system withholds activation until the user
/// approves the item in System Settings › Login Items. That state must be
/// treated as "on, pending approval," not "off": collapsing it to a boolean
/// makes the toggle snap back and look broken.
@MainActor
enum LoginItem {
  enum Status: Equatable {
    /// Registered and active.
    case enabled
    /// Registered, but waiting for the user's approval in
    /// System Settings › Login Items.
    case requiresApproval
    /// Not registered.
    case disabled
    /// Not running from an installable .app bundle (`swift run`).
    case unsupported
  }

  /// Current registration state as reported by the system, so the toggle
  /// reflects changes made in System Settings › Login Items too.
  static var status: Status {
    guard Bundle.main.bundleIdentifier != nil else { return .unsupported }
    switch SMAppService.mainApp.status {
    case .enabled:
      return .enabled
    case .requiresApproval:
      return .requiresApproval
    default:
      return .disabled
    }
  }

  static var isSupported: Bool {
    status != .unsupported
  }

  /// Attempts to (un)register and returns the *actual* resulting status —
  /// re-read from the system, so a failed attempt is reflected honestly —
  /// plus a user-presentable message when the service call threw.
  @discardableResult
  static func setEnabled(_ enabled: Bool) -> (status: Status, errorDescription: String?) {
    guard isSupported else { return (.unsupported, nil) }
    var errorDescription: String?
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      errorDescription = error.localizedDescription
    }
    return (status, errorDescription)
  }

  /// Deep-links to System Settings › General › Login Items, where a
  /// `.requiresApproval` registration is waiting for its checkbox.
  static func openLoginItemsSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
