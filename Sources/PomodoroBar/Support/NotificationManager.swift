import Foundation
import UserNotifications

/// Posts a local notification when a phase completes, so the end of a focus
/// session or break is visible even while another app is full-screen.
///
/// Notifications for phases that did *not* auto-start carry action buttons
/// (Start / Skip) so the user can begin the next phase straight from the
/// banner without hunting for the menu bar item. Actions are routed through
/// `actionHandler`, wired up by the App at launch.
///
/// Every entry point no-ops when the process is not running from a real .app
/// bundle (`swift run` during development): `UNUserNotificationCenter`
/// requires a bundle identifier and traps without one.
@MainActor
enum NotificationManager {
  /// Fixed identifier so a new phase notification replaces the previous one
  /// instead of stacking up in Notification Center.
  private static let requestIdentifier = "pomodorobar.phase-change"

  /// Two categories, differing only in the Start action's title — category
  /// actions are registered up front, so "Start Focus" vs "Start Break"
  /// can't be decided per-notification any other way.
  private static let categoryNextFocus = "pomodorobar.phase.next-focus"
  private static let categoryNextBreak = "pomodorobar.phase.next-break"

  private static let actionStart = "pomodorobar.action.start"
  private static let actionSkip = "pomodorobar.action.skip"

  /// What the user chose on a phase-change notification.
  enum Action {
    /// Start the (already teed-up) next phase.
    case startNext
    /// Skip the next phase entirely and move past it.
    case skipNext
  }

  /// Invoked on the main actor when the user taps a notification action.
  /// Set once at launch by the App, which owns the timer.
  static var actionHandler: ((Action) -> Void)?

  /// True when the process runs from an app bundle and can use the
  /// UserNotifications framework at all.
  static var isSupported: Bool {
    Bundle.main.bundleIdentifier != nil
  }

  /// Presents banners even while PomodoroBar is the active app — as an
  /// accessory app it is rarely "active", but the popover can be open when a
  /// phase flips and the banner should still appear. Also routes action
  /// button taps to `actionHandler`.
  private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
    ) async -> UNNotificationPresentationOptions {
      [.banner]
    }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
    ) async {
      let action: Action?
      switch response.actionIdentifier {
      case NotificationManager.actionStart:
        action = .startNext
      case NotificationManager.actionSkip:
        action = .skipNext
      default:
        // Plain tap on the banner body — no implicit action; starting a
        // 25-minute session from an accidental click would be worse than
        // doing nothing.
        action = nil
      }
      guard let action else { return }
      await MainActor.run {
        NotificationManager.actionHandler?(action)
      }
    }
  }

  private static let delegate = Delegate()

  /// Installs the presentation delegate, registers the action categories,
  /// and asks for alert + sound permission. Safe to call repeatedly; the
  /// system only prompts once.
  static func requestAuthorizationIfNeeded() async {
    guard isSupported else { return }
    let center = UNUserNotificationCenter.current()
    center.delegate = delegate
    registerCategories(in: center)
    _ = try? await center.requestAuthorization(options: [.alert, .sound])
  }

  /// Both actions run in the background (no `.foreground` option): the
  /// timer is a menu bar accessory, so acting on it shouldn't drag any
  /// window forward.
  private static func registerCategories(in center: UNUserNotificationCenter) {
    let skip = UNNotificationAction(
      identifier: actionSkip,
      title: String(localized: "notification.action.skip", defaultValue: "Skip"),
    )

    let startFocus = UNNotificationAction(
      identifier: actionStart,
      title: String(
        localized: "notification.action.startFocus", defaultValue: "Start Focus"
      ),
    )
    let startBreak = UNNotificationAction(
      identifier: actionStart,
      title: String(
        localized: "notification.action.startBreak", defaultValue: "Start Break"
      ),
    )

    center.setNotificationCategories([
      UNNotificationCategory(
        identifier: categoryNextFocus,
        actions: [startFocus, skip],
        intentIdentifiers: [],
      ),
      UNNotificationCategory(
        identifier: categoryNextBreak,
        actions: [startBreak, skip],
        intentIdentifiers: [],
      ),
    ])
  }

  /// Announces the end of `finished` and what comes next. `autoStarted`
  /// switches the body between "starting now" and "open the app to start",
  /// and gates the action buttons — an auto-started phase needs no Start.
  /// `withSound` attaches the default notification sound so the phase cue
  /// respects the user's per-app notification sound settings.
  static func postPhaseChange(
    finished: PomodoroTimer.Phase,
    next: PomodoroTimer.Phase,
    nextMinutes: Int,
    autoStarted: Bool,
    withSound: Bool,
  ) {
    guard isSupported else { return }

    let content = UNMutableNotificationContent()
    switch finished {
    case .focus:
      content.title = String(
        localized: "notification.title.focusDone",
        defaultValue: "Focus session complete",
      )
    case .shortBreak, .longBreak:
      content.title = String(
        localized: "notification.title.breakDone",
        defaultValue: "Break over",
      )
    }
    let nextLabel = next.label.lowercased()
    if autoStarted {
      content.body = String(
        format: String(
          localized: "notification.body.autoStart",
          defaultValue: "Starting %@ (%d min)."
        ),
        nextLabel, nextMinutes,
      )
    } else {
      content.body = String(
        format: String(
          localized: "notification.body.manualStart",
          defaultValue: "%@ (%d min) is ready."
        ),
        next.label, nextMinutes,
      )
    }

    if withSound {
      content.sound = .default
    }

    if !autoStarted {
      content.categoryIdentifier = next == .focus ? categoryNextFocus : categoryNextBreak
    }

    let request = UNNotificationRequest(
      identifier: requestIdentifier,
      content: content,
      trigger: nil,
    )
    UNUserNotificationCenter.current().add(request)
  }
}
