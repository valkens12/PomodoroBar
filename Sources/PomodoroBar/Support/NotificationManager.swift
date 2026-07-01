import Foundation
import UserNotifications

/// Posts a local notification when a phase completes, so the end of a focus
/// session or break is visible even while another app is full-screen.
///
/// Every entry point no-ops when the process is not running from a real .app
/// bundle (`swift run` during development): `UNUserNotificationCenter`
/// requires a bundle identifier and traps without one.
@MainActor
enum NotificationManager {
  /// Fixed identifier so a new phase notification replaces the previous one
  /// instead of stacking up in Notification Center.
  private static let requestIdentifier = "pomodorobar.phase-change"

  /// True when the process runs from an app bundle and can use the
  /// UserNotifications framework at all.
  static var isSupported: Bool {
    Bundle.main.bundleIdentifier != nil
  }

  /// Presents banners even while PomodoroBar is the active app — as an
  /// accessory app it is rarely "active", but the popover can be open when a
  /// phase flips and the banner should still appear.
  private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
    ) async -> UNNotificationPresentationOptions {
      [.banner]
    }
  }

  private static let delegate = Delegate()

  /// Installs the presentation delegate and asks for alert permission.
  /// Safe to call repeatedly; the system only prompts once.
  static func requestAuthorizationIfNeeded() async {
    guard isSupported else { return }
    let center = UNUserNotificationCenter.current()
    center.delegate = delegate
    _ = try? await center.requestAuthorization(options: [.alert])
  }

  /// Announces the end of `finished` and what comes next. `autoStarted`
  /// switches the body between "starting now" and "open the app to start".
  static func postPhaseChange(
    finished: PomodoroTimer.Phase,
    next: PomodoroTimer.Phase,
    nextMinutes: Int,
    autoStarted: Bool,
  ) {
    guard isSupported else { return }

    let content = UNMutableNotificationContent()
    switch finished {
    case .focus:
      content.title = "Focus session complete"
    case .shortBreak, .longBreak:
      content.title = "Break over"
    }
    let nextLabel = next.label.lowercased()
    content.body = autoStarted
      ? "Starting \(nextLabel) (\(nextMinutes) min)."
      : "\(next.label) (\(nextMinutes) min) is ready — press Start when you are."

    let request = UNNotificationRequest(
      identifier: requestIdentifier,
      content: content,
      trigger: nil,
    )
    UNUserNotificationCenter.current().add(request)
  }
}
