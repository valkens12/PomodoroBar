import Foundation

/// Queries Safari's frontmost tab URL via Apple Events, for tab-level focus
/// gating. Sends the event **in-process** with `NSAppleScript` (dispatched to
/// a private serial queue so the synchronous round-trip never blocks any actor
/// PomodoroBar cares about). In-process is mandatory under the App Sandbox:
/// the entitlement check is applied to the *sending* process, so shelling out
/// to `/usr/bin/osascript` — where the child, not us, is the sender — is denied
/// under sandbox and rejected by App Review. The `with timeout` wrapper bounds
/// the wait, so a busy or asleep Safari can't pin the worker thread. Both the
/// sandboxed (Mac App Store) and hardened-runtime direct builds carry
/// `com.apple.security.automation.apple-events`, so this one code path serves
/// every distribution channel.
enum SafariTabQuery {
  enum QueryError: Error {
    case notSupported
    case scriptFailed(String)
    case unparsableOutput
    case timedOut
    case automationDenied
  }

  /// Wrapped in `with timeout` so the Apple Event send can't outlive the
  /// worker thread: a hung Safari surfaces as an `errAETimeout` (-1712)
  /// instead of blocking until the multi-minute system default.
  private static let source = """
    with timeout of 2 seconds
      tell application "Safari" to get URL of current tab of front window
    end timeout
    """

  /// AppleScript / Apple Event Manager result codes we branch on. Anything
  /// else is folded into `.scriptFailed` and treated as fail-open by callers.
  private static let errAEEventNotPermitted = -1743
  private static let errAETimeout = -1712

  /// Serial queue owning every `NSAppleScript` execution. `NSAppleScript` is
  /// not thread-safe, so confining all runs to one queue (rather than an
  /// arbitrary global-queue slot) keeps executions from overlapping.
  private static let queryQueue = DispatchQueue(label: "com.archiet4.pomodorobar.safari-query")

  /// True when the process can plausibly send Apple Events at all. Mirrors
  /// `NotificationManager.isSupported` / `LoginItem.isSupported` — dev builds
  /// via `swift run` have no bundle identifier, and the whole feature is
  /// meaningless outside a packaged app.
  static var isSupported: Bool { Bundle.main.bundleIdentifier != nil }

  /// Returns the frontmost Safari tab's URL host (e.g. "learn.coursera.org"),
  /// or a `QueryError` describing why it couldn't. Every failure case must be
  /// treated by the caller as "fall back to app-level gating" — never as
  /// "block the timer" — per FocusGuard's fail-open contract.
  static func currentTabHost() async -> Result<String, QueryError> {
    guard isSupported else { return .failure(.notSupported) }

    switch await runAppleScript(source) {
    case .timedOut:
      return .failure(.timedOut)
    case .denied:
      return .failure(.automationDenied)
    case .failed(let message):
      return .failure(.scriptFailed(message))
    case .succeeded(let urlString):
      guard let host = URLComponents(string: urlString)?.host, !host.isEmpty else {
        return .failure(.unparsableOutput)
      }
      return .success(host.lowercased())
    }
  }

  // MARK: - Apple Event plumbing

  private enum ScriptOutcome: Sendable {
    case succeeded(String)
    case failed(String)
    case timedOut
    case denied
  }

  /// Compiles and runs `source` off the caller's actor on `queryQueue`. The
  /// `NSAppleScript` instance is created and consumed entirely inside the
  /// queue closure, so nothing non-`Sendable` crosses the continuation.
  private static func runAppleScript(_ source: String) async -> ScriptOutcome {
    await withCheckedContinuation { (continuation: CheckedContinuation<ScriptOutcome, Never>) in
      queryQueue.async {
        guard let script = NSAppleScript(source: source) else {
          continuation.resume(returning: .failed("could not compile Safari query script"))
          return
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
          let number = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
          let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "unknown AppleScript error"
          switch number {
          case errAEEventNotPermitted:
            continuation.resume(returning: .denied)
          case errAETimeout:
            continuation.resume(returning: .timedOut)
          default:
            continuation.resume(returning: .failed("(\(number)) \(message)"))
          }
          return
        }

        continuation.resume(returning: .succeeded(descriptor.stringValue ?? ""))
      }
    }
  }
}
