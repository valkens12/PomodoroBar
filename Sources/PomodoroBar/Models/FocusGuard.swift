import AppKit
import Foundation
import SwiftUI

/// Bundle identifiers of apps that get special-cased behavior beyond plain
/// app-level gating. Currently only Safari, whose frontmost-tab URL can be
/// queried via Apple Events (see `SafariTabQuery`) to support tab-level
/// focus restrictions.
enum WellKnownBundleId {
  static let safari = "com.apple.Safari"
}

/// A user-selected app that, when frontmost, keeps the timer ticking.
///
/// `focusDomains` is only meaningful for the Safari entry (see
/// `WellKnownBundleId.safari`): when non-empty, the timer additionally
/// requires the frontmost Safari tab's host to match one of these domains,
/// not just Safari being the frontmost app. Empty for every other app, and
/// empty by default for Safari too — a Safari entry with no domains behaves
/// exactly like any other app-level entry.
struct FocusApp: Identifiable, Codable, Hashable {
  let id: UUID
  let bundleId: String
  let name: String
  let urlPath: String
  var focusDomains: [String]

  init(
    id: UUID,
    bundleId: String,
    name: String,
    urlPath: String,
    focusDomains: [String] = [],
  ) {
    self.id = id
    self.bundleId = bundleId
    self.name = name
    self.urlPath = urlPath
    self.focusDomains = focusDomains
  }

  private enum CodingKeys: String, CodingKey {
    case id, bundleId, name, urlPath, focusDomains
  }

  /// Custom decoding so previously-persisted entries (saved before
  /// `focusDomains` existed) load without error instead of failing the
  /// whole `focusApps` array decode.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    bundleId = try container.decode(String.self, forKey: .bundleId)
    name = try container.decode(String.self, forKey: .name)
    urlPath = try container.decode(String.self, forKey: .urlPath)
    focusDomains = try container.decodeIfPresent([String].self, forKey: .focusDomains) ?? []
  }
}

/// Domain matching for the Safari tab restriction: suffix-match with a
/// boundary, so a pattern like "coursera.org" matches "learn.coursera.org"
/// but not "evilcoursera.org".
enum DomainMatch {
  static func hostMatches(_ host: String, pattern: String) -> Bool {
    host == pattern || host.hasSuffix("." + pattern)
  }
}

/// Gates the Pomodoro countdown on the frontmost app, and optionally — for
/// Safari — on the frontmost tab's domain.
///
/// When `enabled` is on and `focusApps` is non-empty, the timer only counts
/// down while one of the listed apps is frontmost. Switch away and the tomato
/// pauses (the run state stays `.running`; the ticking is suspended). If the
/// Safari entry has `focusDomains` configured, being frontmost isn't enough
/// on its own — the current tab's host must also match one of those domains,
/// checked by periodically polling Safari via Apple Events while it's
/// frontmost, gating is enabled, and the timer is running (see
/// `updatePollingTaskIfNeeded`). Any polling failure (permission denied,
/// Safari not running, timeout) fails open to app-level-only gating rather
/// than pausing the timer indefinitely.
@Observable
@MainActor
final class FocusGuard {
  // MARK: - Constants

  private enum Key {
    static let focusGatingEnabled = "focusGatingEnabled"
    static let focusApps = "focusApps"
  }

  /// How often the frontmost Safari tab is re-checked while polling is
  /// active. A tunable balance between responsiveness (catching a tab switch
  /// quickly) and Apple Event overhead — not meaningful outside this range.
  private static let tabPollInterval: Duration = .seconds(2)

  // MARK: - Stored Properties

  var enabled: Bool {
    didSet {
      UserDefaults.standard.set(enabled, forKey: Key.focusGatingEnabled)
      updatePollingTaskIfNeeded()
    }
  }

  var focusApps: [FocusApp] {
    didSet {
      persistApps()
      updatePollingTaskIfNeeded()
    }
  }

  private(set) var frontmostBundleId: String?
  private(set) var frontmostAppName: String?

  /// Host of the last successfully-queried frontmost Safari tab (e.g.
  /// "learn.coursera.org"). Stale/meaningless whenever `lastTabQuerySucceeded`
  /// is false or Safari isn't frontmost — always read alongside
  /// `lastTabQuerySucceeded`, never alone.
  private(set) var frontmostTabHost: String?

  /// False when the most recent Safari tab poll failed for any reason.
  /// `isFocusAppActive` treats this as "can't verify the tab, fall open."
  private(set) var lastTabQuerySucceeded = true

  /// True once a Safari tab query has failed specifically with "Automation
  /// access denied" (Apple Event error -1743). Drives the denied-permission
  /// affordance in Settings; there's no way to know this ahead of a failed
  /// attempt (Apple Events automation permission has no query API).
  private(set) var automationPermissionDenied = false

  @ObservationIgnored
  private var observerTokens: [NSObjectProtocol] = []

  /// Mirrors `PomodoroTimer.runState == .running`, pushed in by
  /// `setTimerRunning` — `FocusGuard` has no other way to learn this without
  /// a circular dependency on `PomodoroTimer`, and polling must stop the
  /// instant the timer isn't running.
  @ObservationIgnored
  private var timerIsRunning = false

  @ObservationIgnored
  private var pollTask: Task<Void, Never>?

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

  /// True when the timer should count down given the current frontmost app
  /// (and, for a Safari entry with domains configured, the current tab).
  var isFocusAppActive: Bool {
    guard enabled, !focusApps.isEmpty else { return true }
    guard let frontmost = frontmostBundleId else { return false }
    guard let matched = focusApps.first(where: { $0.bundleId == frontmost }) else { return false }
    guard !matched.focusDomains.isEmpty else { return true }
    // Fail open: can't verify the tab right now, don't block on it.
    guard lastTabQuerySucceeded, let host = frontmostTabHost else { return true }
    return matched.focusDomains.contains { DomainMatch.hostMatches(host, pattern: $0) }
  }

  /// True specifically when the frontmost app matched (app-level gating
  /// alone would count as focused) but its configured tab restriction isn't
  /// currently satisfied — lets the UI say "wrong tab" instead of "wrong
  /// app." Never true while a tab query is unverified (fail-open there too).
  var isTabMismatch: Bool {
    guard enabled,
      let frontmost = frontmostBundleId,
      let matched = focusApps.first(where: { $0.bundleId == frontmost }),
      !matched.focusDomains.isEmpty,
      lastTabQuerySucceeded,
      let host = frontmostTabHost
    else { return false }
    return !matched.focusDomains.contains { DomainMatch.hostMatches(host, pattern: $0) }
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

  /// Adds `raw` to `app`'s focus-domain allow-list, normalizing (trim,
  /// lowercase, strip a leading "www.") and de-duplicating. No-ops if the
  /// trimmed input is empty or already present.
  func addDomain(_ raw: String, to app: FocusApp) {
    guard let domain = Self.normalizeDomain(raw) else { return }
    guard let index = focusApps.firstIndex(where: { $0.id == app.id }) else { return }
    guard !focusApps[index].focusDomains.contains(domain) else { return }
    focusApps[index].focusDomains.append(domain)
  }

  func removeDomain(_ domain: String, from app: FocusApp) {
    guard let index = focusApps.firstIndex(where: { $0.id == app.id }) else { return }
    focusApps[index].focusDomains.removeAll { $0 == domain }
  }

  /// Activates the first listed focus app — used by the popover's "waiting"
  /// banner so the user can jump straight back to work with one click.
  func openFirstFocusApp() {
    guard let app = focusApps.first else { return }
    NSWorkspace.shared.openApplication(
      at: URL(fileURLWithPath: app.urlPath),
      configuration: NSWorkspace.OpenConfiguration(),
    )
  }

  /// Called by `PomodoroTimer` on every run-state transition (start, pause,
  /// resume, reset, idle-after-phase-advance). Only running timers are worth
  /// spending Apple Events on.
  func setTimerRunning(_ running: Bool) {
    guard timerIsRunning != running else { return }
    timerIsRunning = running
    updatePollingTaskIfNeeded()
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

    pollTask?.cancel()
    pollTask = nil
  }

  func refreshFrontmost() {
    let app = NSWorkspace.shared.frontmostApplication
    frontmostBundleId = app?.bundleIdentifier
    frontmostAppName = app?.localizedName
    updatePollingTaskIfNeeded()
  }

  // MARK: - Safari Tab Polling

  /// True precisely when a background poll of Safari's frontmost tab is
  /// worth running right now. The single condition `updatePollingTaskIfNeeded`
  /// checks before starting or stopping the poll loop.
  private var wantsTabPolling: Bool {
    guard enabled, timerIsRunning, frontmostBundleId == WellKnownBundleId.safari else {
      return false
    }
    guard let matched = focusApps.first(where: { $0.bundleId == WellKnownBundleId.safari })
    else { return false }
    return !matched.focusDomains.isEmpty
  }

  /// The single choke point deciding whether the tab-polling `Task` should
  /// be alive. Called from every state transition that could change the
  /// answer: app activation (`refreshFrontmost`), timer run-state changes
  /// (`setTimerRunning`), gating toggled (`enabled.didSet`), and domain-list
  /// edits (`focusApps.didSet`, which covers add/remove of both apps and
  /// domains). Missing a call site here either silently breaks the feature
  /// (loop never starts) or leaks background polling indefinitely (loop
  /// never stops) — this is the highest-risk piece of the whole feature.
  private func updatePollingTaskIfNeeded() {
    guard wantsTabPolling else {
      pollTask?.cancel()
      pollTask = nil
      return
    }
    guard pollTask == nil else { return }
    pollTask = Task { @MainActor [weak self] in
      await self?.pollLoop()
    }
  }

  /// Polls Safari's current tab every `tabPollInterval` while
  /// `wantsTabPolling` holds. Exits on its own the moment the condition flips
  /// false, rather than relying solely on external cancellation —
  /// belt-and-suspenders alongside `updatePollingTaskIfNeeded`'s explicit
  /// `cancel()`.
  private func pollLoop() async {
    while !Task.isCancelled, wantsTabPolling {
      await refreshFrontmostTabHost()
      try? await Task.sleep(for: Self.tabPollInterval)
    }
  }

  /// Queries Safari's current tab right now, independent of whether
  /// background polling is active, and returns the host if successful. Used
  /// by the Focus Apps UI's "Add Current Tab's Domain" button — an on-demand
  /// counterpart to `pollLoop` that shares the same success/failure
  /// bookkeeping (`frontmostTabHost`, `lastTabQuerySucceeded`,
  /// `automationPermissionDenied`) so the UI stays consistent with whatever
  /// the background poll last observed.
  @discardableResult
  func captureCurrentSafariTabHost() async -> String? {
    await refreshFrontmostTabHost()
    return lastTabQuerySucceeded ? frontmostTabHost : nil
  }

  private func refreshFrontmostTabHost() async {
    let result = await SafariTabQuery.currentTabHost()
    guard !Task.isCancelled else { return }
    switch result {
    case .success(let host):
      frontmostTabHost = host
      lastTabQuerySucceeded = true
      automationPermissionDenied = false
    case .failure(.automationDenied):
      lastTabQuerySucceeded = false
      automationPermissionDenied = true
    case .failure:
      // Fail open: leave frontmostTabHost as-is, just mark the query stale
      // so isFocusAppActive falls back to app-level gating.
      lastTabQuerySucceeded = false
    }
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

  /// Reduces user input to a bare host so "https://www.Coursera.org/learn"
  /// pasted in whole and "coursera.org" typed by hand both normalize the same
  /// way: trims, lowercases, extracts the host from a full URL, drops any
  /// path, and strips a leading "www.". Returns nil for blank input.
  static func normalizeDomain(_ raw: String) -> String? {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !value.isEmpty else { return nil }
    if let host = URLComponents(string: value)?.host, !host.isEmpty {
      value = host
    } else if let slash = value.firstIndex(of: "/") {
      value = String(value[..<slash])
    }
    if value.hasPrefix("www.") {
      value.removeFirst(4)
    }
    return value.isEmpty ? nil : value
  }

  // MARK: - Deinit

  deinit {
    // Releasing the token array drops the observers; no main-actor access here.
    // The plain array and its contained NSObjectProtocol tokens are released by
    // ARC when `observerTokens` is itself released at instance deallocation.
  }
}
