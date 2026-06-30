import AppKit
import Foundation
import SwiftUI

/// A user-selected app that, when frontmost, keeps the timer ticking.
struct FocusApp: Identifiable, Codable, Hashable {
  let id: UUID
  let bundleId: String
  let name: String
  let urlPath: String
}

/// Gates the Pomodoro countdown on the frontmost app.
///
/// When `enabled` is on and `focusApps` is non-empty, the timer only counts
/// down while one of the listed apps is frontmost. Switch away and the tomato
/// pauses (the run state stays `.running`; the ticking is suspended).
@Observable
@MainActor
final class FocusGuard {
  // MARK: - Constants

  private enum Key {
    static let focusGatingEnabled = "focusGatingEnabled"
    static let focusApps = "focusApps"
  }

  // MARK: - Stored Properties

  var enabled: Bool {
    didSet {
      UserDefaults.standard.set(enabled, forKey: Key.focusGatingEnabled)
    }
  }

  var focusApps: [FocusApp] {
    didSet {
      persistApps()
    }
  }

  private(set) var frontmostBundleId: String?
  private(set) var frontmostAppName: String?

  @ObservationIgnored
  private var observerTokens: [NSObjectProtocol] = []

  // MARK: - Init

  init() {
    let defaults = UserDefaults.standard

    if defaults.object(forKey: Key.focusGatingEnabled) != nil {
      self.enabled = defaults.bool(forKey: Key.focusGatingEnabled)
    } else {
      self.enabled = false
    }

    self.focusApps = Self.loadApps()

    // Persist the (possibly defaulted) enabled flag so it's always consistent.
    defaults.set(enabled, forKey: Key.focusGatingEnabled)
  }

  // MARK: - Derived

  /// True when the timer should count down given the current frontmost app.
  var isFocusAppActive: Bool {
    guard enabled, !focusApps.isEmpty else { return true }
    guard let frontmost = frontmostBundleId else { return false }
    return focusApps.contains { $0.bundleId == frontmost }
  }

  // MARK: - Public Actions

  func add(url: URL) {
    guard
      let bundle = Bundle(url: url),
      let bundleId = bundle.bundleIdentifier
    else { return }

    // Avoid duplicates by bundle id.
    if focusApps.contains(where: { $0.bundleId == bundleId }) { return }

    let name =
      bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? url.deletingPathExtension().lastPathComponent

    focusApps.append(
      FocusApp(
        id: UUID(),
        bundleId: bundleId,
        name: name,
        urlPath: url.path,
      ),
    )
  }

  func remove(_ app: FocusApp) {
    focusApps.removeAll { $0.id == app.id }
  }

  // MARK: - Monitoring

  func startMonitoring() {
    guard observerTokens.isEmpty else { return }

    refreshFrontmost()

    let center = NSWorkspace.shared.notificationCenter
    let activateToken = center.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main,
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.refreshFrontmost()
      }
    }

    observerTokens.append(activateToken)
  }

  func stopMonitoring() {
    let center = NSWorkspace.shared.notificationCenter
    for token in observerTokens {
      center.removeObserver(token)
    }
    observerTokens.removeAll()
  }

  func refreshFrontmost() {
    let app = NSWorkspace.shared.frontmostApplication
    frontmostBundleId = app?.bundleIdentifier
    frontmostAppName = app?.localizedName
  }

  // MARK: - Persistence

  private func persistApps() {
    do {
      let data = try JSONEncoder().encode(focusApps)
      UserDefaults.standard.set(data, forKey: Key.focusApps)
    } catch {
      // Encoding failures are non-fatal; in-memory state remains correct.
    }
  }

  private static func loadApps() -> [FocusApp] {
    guard
      let data = UserDefaults.standard.data(forKey: Key.focusApps)
    else {
      return []
    }
    do {
      return try JSONDecoder().decode([FocusApp].self, from: data)
    } catch {
      return []
    }
  }

  // MARK: - Deinit

  deinit {
    // Releasing the token array drops the observers; no main-actor access here.
    // The plain array and its contained NSObjectProtocol tokens are released by
    // ARC when `observerTokens` is itself released at instance deallocation.
  }
}