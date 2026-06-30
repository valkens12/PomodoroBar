import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Focus-app gating preferences.
///
/// When "Focus Mode" is on, the timer only counts down while one of the listed
/// apps is frontmost. Apps are added via a file importer limited to `.app`
/// bundles; their icons are resolved through NSWorkspace.
struct FocusAppsTab: View {
  @Environment(FocusGuard.self) private var focusGuard

  @State private var showPicker = false

  var body: some View {
    @Bindable var focusGuard = focusGuard

    Form {
      Section {
        Toggle(
          "Pause timer unless a focus app is active",
          isOn: $focusGuard.enabled,
        )
        .tint(Theme.tomatoRed)
      } header: {
        Text("Focus Mode")
      } footer: {
        Text(
          "When on, the timer only counts down while one of these apps is "
          + "frontmost. Switch to YouTube and the tomato pauses."
        )
      }

      Section {
        if focusGuard.focusApps.isEmpty {
          HStack {
            Image(systemName: "app.dashed")
              .foregroundStyle(.secondary)
              .frame(width: 28, height: 28)
            Text("No focus apps yet.")
              .foregroundStyle(.secondary)
              .font(.system(.body, design: .rounded))
            Spacer()
          }
        } else {
          ForEach(focusGuard.focusApps) { app in
            FocusAppRow(app: app, icon: { appIcon(for: app) }) {
              focusGuard.remove(app)
            }
          }
        }

        Button {
          showPicker = true
        } label: {
          Label("Add App…", systemImage: "plus.circle.fill")
            .foregroundStyle(Theme.tomatoRed)
        }
        .buttonStyle(.borderless)
        .accessibilityHint("Choose an application to add to the focus list.")
      } header: {
        Text("Focus Apps")
      } footer: {
        Text("Add the apps you want to work in.")
      }
    }
    .formStyle(.grouped)
    .fileImporter(
      isPresented: $showPicker,
      allowedContentTypes: [UTType.application],
      allowsMultipleSelection: false,
    ) { result in
      handlePick(result)
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

  /// Processes the file-importer result: on success, registers the picked .app
  /// with the FocusGuard; on failure, logs and ignores.
  private func handlePick(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first else { return }
      focusGuard.add(url: url)
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
      .accessibilityLabel("Remove \(app.name)")
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