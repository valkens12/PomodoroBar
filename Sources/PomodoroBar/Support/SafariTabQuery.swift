import Foundation

/// Queries Safari's frontmost tab URL via Apple Events, for tab-level focus
/// gating. Shells out to `/usr/bin/osascript` rather than using
/// `NSAppleScript` in-process: the Apple Event round-trip can block for the
/// full system timeout (Safari busy, asleep, or an unanswered Automation
/// permission prompt on screen), and running that inside a subprocess keeps
/// the block off every actor PomodoroBar cares about — not just MainActor.
/// Deliberately not `@MainActor`.
enum SafariTabQuery {
  enum QueryError: Error {
    case notSupported
    case processFailed(String)
    case unparsableOutput
    case timedOut
    case automationDenied
  }

  private static let script =
    "tell application \"Safari\" to get URL of current tab of front window"

  /// True when the process can plausibly send Apple Events at all. Mirrors
  /// `NotificationManager.isSupported` / `LoginItem.isSupported` — dev builds
  /// via `swift run` have no bundle identifier and osascript's app-targeting
  /// by name still works, but there is no point trying without a real bundle
  /// since the whole feature is meaningless outside a packaged app.
  static var isSupported: Bool { Bundle.main.bundleIdentifier != nil }

  /// Returns the frontmost Safari tab's URL host (e.g. "learn.coursera.org"),
  /// or a `QueryError` describing why it couldn't. Every failure case must be
  /// treated by the caller as "fall back to app-level gating" — never as
  /// "block the timer" — per FocusGuard's fail-open contract.
  static func currentTabHost() async -> Result<String, QueryError> {
    guard isSupported else { return .failure(.notSupported) }

    let outcome = await runOsascript(script)
    switch outcome {
    case .timedOut:
      return .failure(.timedOut)
    case .failed(let stderr):
      if stderr.contains("(-1743)") {
        return .failure(.automationDenied)
      }
      return .failure(.processFailed(stderr))
    case .succeeded(let stdout):
      let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
      guard let host = URLComponents(string: trimmed)?.host, !host.isEmpty else {
        return .failure(.unparsableOutput)
      }
      return .success(host.lowercased())
    }
  }

  // MARK: - Process plumbing

  private enum ProcessOutcome {
    case succeeded(String)
    case failed(String)
    case timedOut
  }

  /// Lets the cancellation handler reach the in-flight `Process` even though
  /// it lives in a separate closure scope from where it's created — `Process`
  /// itself isn't `Sendable`, but `.terminate()` is documented safe to call
  /// from any thread, so a locked box around the reference is enough.
  private final class ProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?

    func set(_ process: Process) {
      lock.lock()
      defer { lock.unlock() }
      self.process = process
    }

    func terminateIfRunning() {
      lock.lock()
      let process = self.process
      lock.unlock()
      if process?.isRunning == true {
        process?.terminate()
      }
    }
  }

  /// The termination handler, the timeout block, and the `do/catch` around
  /// `process.run()` can all race to resume the continuation; this wraps
  /// "resume exactly once" as a `Sendable` reference type instead of a
  /// captured local closure, which Swift 6 strict concurrency won't accept
  /// crossing the multiple `@Sendable` closure boundaries here.
  private final class ContinuationResumer: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<ProcessOutcome, Never>

    init(_ continuation: CheckedContinuation<ProcessOutcome, Never>) {
      self.continuation = continuation
    }

    func callAsFunction(_ outcome: ProcessOutcome) {
      lock.lock()
      defer { lock.unlock() }
      guard !didResume else { return }
      didResume = true
      continuation.resume(returning: outcome)
    }
  }

  /// Runs `osascript -e <script>` off the caller's actor, racing it against a
  /// fixed timeout and terminating the process if the surrounding Task is
  /// cancelled (e.g. the user switched away from Safari mid-poll) so a hung
  /// Safari doesn't leave zombie osascript processes behind.
  private static func runOsascript(_ script: String) async -> ProcessOutcome {
    let box = ProcessBox()

    return await withTaskCancellationHandler {
      await withCheckedContinuation { (continuation: CheckedContinuation<ProcessOutcome, Never>) in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let resume = ContinuationResumer(continuation)

        process.terminationHandler = { proc in
          let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
          if proc.terminationStatus == 0 {
            resume(.succeeded(String(data: stdoutData, encoding: .utf8) ?? ""))
          } else {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            resume(.failed(String(data: stderrData, encoding: .utf8) ?? ""))
          }
        }

        do {
          try process.run()
        } catch {
          resume(.failed("\(error)"))
          return
        }
        box.set(process)

        // Timeout: a hung Safari or an unanswered TCC prompt could otherwise
        // block indefinitely.
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
          guard process.isRunning else { return }
          process.terminate()
          resume(.timedOut)
        }
      }
    } onCancel: {
      box.terminateIfRunning()
    }
  }
}
