import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Focus-app gating preferences.
///
/// When "Focus Mode" is on, the timer only counts down while one of the listed
/// apps is frontmost. Apps are added via a file importer limited to `.app`
/// bundles; their icons are resolved through NSWorkspace. The Safari entry
/// additionally supports restricting to specific websites (see
/// `SafariDomainsSection`), checked via Apple Events.
struct FocusAppsTab: View {
  @Environment(FocusGuard.self) private var focusGuard

  @State private var showPicker = false

  var body: some View {
    @Bindable var focusGuard = focusGuard

    Form {
      Section {
        Toggle(
          String(
            localized: "focusMode.toggle",
            defaultValue: "Pause timer unless a focus app is active"
          ),
          isOn: $focusGuard.enabled,
        )
        .tint(Theme.tomatoRed)
      } header: {
        Text(String(localized: "focusMode.header", defaultValue: "Focus Mode"))
      } footer: {
        Text(String(
          localized: "focusMode.footer",
          defaultValue: "When on, the timer only counts down while one of these apps is frontmost. Switch to YouTube and the tomato pauses."
        ))
      }

      Section {
        if focusGuard.focusApps.isEmpty {
          HStack {
            Image(systemName: "app.dashed")
              .foregroundStyle(.secondary)
              .frame(width: 28, height: 28)
            Text(String(localized: "focusApps.empty", defaultValue: "No focus apps yet."))
              .foregroundStyle(.secondary)
              .font(.system(.body, design: .rounded))
            Spacer()
          }
        } else {
          ForEach(focusGuard.focusApps) { app in
            FocusAppRow(app: app, icon: { appIcon(for: app) }) {
              focusGuard.remove(app)
            }
            if app.bundleId == WellKnownBundleId.safari {
              SafariDomainsSection(app: app)
            }
          }
        }

        addAppMenu
      } header: {
        Text(String(localized: "focusApps.header", defaultValue: "Focus Apps"))
      } footer: {
        Text(String(
          localized: "focusApps.footer",
          defaultValue: "Add the apps you want to work in. For Safari, optionally restrict to specific websites — leave empty to allow the whole app."
        ))
      }
    }
    .formStyle(.grouped)
    .fileImporter(
      isPresented: $showPicker,
      allowedContentTypes: [UTType.application],
      allowsMultipleSelection: true,
    ) { result in
      handlePick(result)
    }
  }

  // MARK: - Add Menu

  /// Adding an app offers the currently running apps first — one click,
  /// no trip through the open panel — with "Choose from Finder…" as the
  /// fallback for apps that aren't running.
  private var addAppMenu: some View {
    Menu {
      let candidates = runningAppCandidates
      if !candidates.isEmpty {
        ForEach(candidates, id: \.processIdentifier) { app in
          Button(app.localizedName ?? app.bundleIdentifier ?? String(localized: "focusApps.unknown", defaultValue: "Unknown")) {
            if let url = app.bundleURL {
              focusGuard.add(url: url)
            }
          }
        }
        Divider()
      }
      Button(String(localized: "focusApps.chooseFromFinder", defaultValue: "Choose from Finder…")) {
        showPicker = true
      }
    } label: {
      Label(String(localized: "focusApps.add", defaultValue: "Add App…"),
            systemImage: "plus.circle.fill")
        .foregroundStyle(Theme.tomatoRed)
    }
    .menuStyle(.button)
    .buttonStyle(.borderless)
    .fixedSize()
    .accessibilityHint(
      String(
        localized: "focusApps.addHelp",
        defaultValue: "Choose an application to add to the focus list."
      )
    )
  }

  /// Running apps with a regular activation policy that aren't already in the
  /// list, sorted by name. Recomputed each time the menu opens.
  private var runningAppCandidates: [NSRunningApplication] {
    let existing = Set(focusGuard.focusApps.map(\.bundleId))
    return NSWorkspace.shared.runningApplications
      .filter { $0.activationPolicy == .regular }
      .filter { app in
        guard let bundleId = app.bundleIdentifier else { return false }
        return !existing.contains(bundleId)
          && bundleId != Bundle.main.bundleIdentifier
      }
      .sorted {
        ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "")
          == .orderedAscending
      }
  }

  // MARK: - Helpers

  /// Resolves the app's icon via NSWorkspace, falling back to a generic glyph
  /// when the file path is no longer valid.
  @ViewBuilder
  private func appIcon(for app: FocusApp) -> some View {
    let pathExists = FileManager.default.fileExists(atPath: app.urlPath)
    if pathExists {
      let nsImage = NSWorkspace.shared.icon(forFile: app.urlPath)
      Image(nsImage: nsImage)
        .resizable()
        .interpolation(.high)
        .frame(width: 28, height: 28)
    } else {
      Image(systemName: "app")
        .resizable()
        .scaledToFit()
        .frame(width: 28, height: 28)
        .foregroundStyle(.secondary)
    }
  }

  /// Processes the file-importer result: on success, registers every picked
  /// .app with the FocusGuard; on failure, logs and ignores.
  private func handlePick(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      for url in urls {
        focusGuard.add(url: url)
      }
    case .failure(let error):
      // Non-fatal: the user cancelled or the URL was unreadable.
      print("FocusAppsTab: file importer failed: \(error.localizedDescription)")
    }
  }
}

// MARK: - FocusAppRow

/// A single focus-app row. The destructive remove button only appears on
/// hover, matching system list patterns (Mail, Reminders) instead of
/// permanently showing a red icon next to every row.
private struct FocusAppRow<Icon: View>: View {
  let app: FocusApp
  @ViewBuilder let icon: () -> Icon
  let onRemove: () -> Void

  @State private var isHovering = false

  var body: some View {
    HStack {
      icon()
        .accessibilityHidden(true)
      Text(app.name)
        .lineLimit(1)
        .truncationMode(.middle)
        .font(.system(.body, design: .rounded))
      Spacer()
      // Opacity (not `.hidden()` or a conditional) so the button stays in the
      // accessibility tree and reachable via VoiceOver/keyboard, which never
      // "hover" — only its visibility for sighted pointer users is gated.
      Button(role: .destructive, action: onRemove) {
        Image(systemName: "minus.circle.fill")
          .foregroundStyle(.red)
      }
      .buttonStyle(.borderless)
      .opacity(isHovering ? 1 : 0)
      .help(
        String(
          format: String(
            localized: "focusApps.remove", defaultValue: "Remove %@ from the focus list"
          ),
          app.name,
        )
      )
      .accessibilityLabel(
        String(
          format: String(
            localized: "focusApps.removeA11y", defaultValue: "Remove %@"
          ),
          app.name,
        )
      )
    }
    .contentShape(Rectangle())
    .onHover { hovering in
      withAnimation(.easeOut(duration: 0.12)) {
        isHovering = hovering
      }
    }
  }
}

// MARK: - SafariDomainsSection

/// Sub-rows under the Safari entry for restricting focus credit to specific
/// websites. Shown only for `WellKnownBundleId.safari`, since domains are
/// meaningless for every other app. An empty `app.focusDomains` list leaves
/// Safari gated at the app level only — identical to today's behavior.
private struct SafariDomainsSection: View {
  let app: FocusApp
  @Environment(FocusGuard.self) private var focusGuard

  @State private var newDomain = ""
  @State private var isCapturing = false
  @State private var showPrimerAlert = false

  /// Shown once, ever, before the first Apple Event is sent to Safari — per
  /// HIG guidance to explain before triggering a system permission dialog.
  @AppStorage("hasShownSafariAutomationPrimer") private var hasShownPrimer = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(String(localized: "domains.header", defaultValue: "Restrict to specific websites"))
        .font(.system(.caption, design: .rounded).weight(.medium))
        .foregroundStyle(.secondary)

      ForEach(app.focusDomains, id: \.self) { domain in
        DomainRow(domain: domain) {
          focusGuard.removeDomain(domain, from: app)
        }
      }

      HStack(spacing: 8) {
        TextField(
          String(localized: "domains.placeholder", defaultValue: "example.com"),
          text: $newDomain,
        )
        .textFieldStyle(.roundedBorder)
        .font(.system(.body, design: .rounded))
        .onSubmit(addTypedDomain)
        Button(String(localized: "domains.add", defaultValue: "Add"), action: addTypedDomain)
          .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
      }

      captureButton

      if focusGuard.automationPermissionDenied {
        deniedPermissionNotice
      }
    }
    .padding(.leading, 36)
    .padding(.vertical, 4)
  }

  private var captureButton: some View {
    Button {
      if hasShownPrimer {
        captureCurrentTab()
      } else {
        showPrimerAlert = true
      }
    } label: {
      if isCapturing {
        ProgressView()
          .controlSize(.small)
      } else {
        Label(
          String(
            localized: "domains.addCurrent",
            defaultValue: "Add Current Tab's Domain"
          ),
          systemImage: "safari",
        )
      }
    }
    .buttonStyle(.borderless)
    .foregroundStyle(Theme.tomatoRed)
    .disabled(isCapturing || !SafariTabQuery.isSupported)
    .accessibilityHint(
      String(
        localized: "domains.addCurrentHint",
        defaultValue: "Adds the domain of the tab currently open in Safari."
      )
    )
    .alert(
      String(
        localized: "domains.primerTitle",
        defaultValue: "Allow Safari Tab Access?"
      ),
      isPresented: $showPrimerAlert,
    ) {
      Button(String(localized: "domains.primerContinue", defaultValue: "Continue")) {
        hasShownPrimer = true
        captureCurrentTab()
      }
      Button(String(localized: "skip.confirm.cancel", defaultValue: "Cancel"), role: .cancel) {}
    } message: {
      Text(String(
        localized: "domains.primerMessage",
        defaultValue: "PomodoroBar needs permission to check Safari's current tab. You'll see a system prompt next — click OK to allow it."
      ))
    }
  }

  private var deniedPermissionNotice: some View {
    HStack(spacing: 4) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
      Text(
        String(
          localized: "domains.automationDenied",
          defaultValue: "Automation access denied."
        )
      )
        .foregroundStyle(.secondary)
      Button(
        String(localized: "domains.openSettings", defaultValue: "Open Settings…"),
        action: openAutomationSettings,
      )
        .buttonStyle(.link)
    }
    .font(.system(.caption, design: .rounded))
  }

  private func addTypedDomain() {
    let trimmed = newDomain.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    focusGuard.addDomain(trimmed, to: app)
    newDomain = ""
  }

  private func captureCurrentTab() {
    isCapturing = true
    Task {
      let host = await focusGuard.captureCurrentSafariTabHost()
      isCapturing = false
      if let host {
        focusGuard.addDomain(host, to: app)
      }
    }
  }

  private func openAutomationSettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
      )
    else { return }
    NSWorkspace.shared.open(url)
  }
}

/// A single focus-domain row, matching `FocusAppRow`'s hover-reveal remove
/// pattern.
private struct DomainRow: View {
  let domain: String
  let onRemove: () -> Void

  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "globe")
        .foregroundStyle(.secondary)
        .font(.system(size: 11))
      Text(domain)
        .font(.system(.callout, design: .rounded))
      Spacer()
      Button(role: .destructive, action: onRemove) {
        Image(systemName: "minus.circle.fill")
          .foregroundStyle(.red)
      }
      .buttonStyle(.borderless)
      .opacity(isHovering ? 1 : 0)
      .help(
        String(
          format: String(
            localized: "domain.remove", defaultValue: "Remove %@"
          ),
          domain,
        )
      )
      .accessibilityLabel(
        String(
          format: String(
            localized: "domain.removeA11y", defaultValue: "Remove %@"
          ),
          domain,
        )
      )
    }
    .contentShape(Rectangle())
    .onHover { hovering in
      withAnimation(.easeOut(duration: 0.12)) {
        isHovering = hovering
      }
    }
  }
}

#Preview {
  FocusAppsTab()
    .environment(FocusGuard())
}
