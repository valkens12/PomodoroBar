import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A click-to-record control for the global hotkey: shows the current
/// combination ("⌃⌥P"), and on click waits for the next keystroke to become
/// the new one. Escape cancels; combinations that would hijack ordinary
/// typing (no ⌃/⌥/⌘ anchor, unless a function key) are rejected with a beep.
struct HotkeyRecorderField: View {
  @Binding var combo: KeyCombo
  @Environment(AppSettings.self) private var settings

  @State private var isRecording = false
  @State private var eventMonitor: Any?

  var body: some View {
    Button {
      if isRecording {
        cancelRecording()
      } else {
        beginRecording()
      }
    } label: {
      Text(
        isRecording
          ? String(localized: "hotkey.idle", defaultValue: "Type shortcut…")
          : combo.displayString
      )
        .font(.system(.body, design: .rounded))
        .foregroundStyle(isRecording ? .secondary : .primary)
        .frame(minWidth: 100)
    }
    .buttonStyle(.bordered)
    .help(
      isRecording
        ? String(
          localized: "hotkey.recordingHelp",
          defaultValue: "Press the new key combination, or Escape to cancel"
        )
        : String(
          localized: "hotkey.idleHelp",
          defaultValue: "Click, then press a new key combination"
        )
    )
    .accessibilityLabel(
      String(
        format: String(
          localized: "hotkey.a11y", defaultValue: "Global shortcut: %@"
        ),
        combo.accessibleDescription,
      )
    )
    .accessibilityHint(
      String(
        localized: "hotkey.hint",
        defaultValue: "Starts recording; press the new key combination to set it."
      )
    )
    .onDisappear {
      cancelRecording()
    }
  }

  // MARK: - Recording

  private func beginRecording() {
    guard !isRecording else { return }
    isRecording = true

    // Suspend the live registration: if the user re-records the currently
    // active combo, Carbon would swallow the keystroke system-wide before
    // this local monitor ever sees it.
    HotkeyCenter.shared.setEnabled(false)

    // NSEvent is not Sendable, so the Sendable pieces (KeyCombo + escape
    // flag) are extracted before hopping to the main actor. Returning nil
    // consumes every keystroke while recording, so nothing leaks through to
    // the window.
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let candidate = KeyCombo(event: event)
      let isBareEscape =
        event.keyCode == UInt16(kVK_Escape) && candidate.carbonModifiers == 0
      MainActor.assumeIsolated {
        handleRecorded(candidate, isBareEscape: isBareEscape)
      }
      return nil
    }
  }

  /// Escape cancels, a valid combination is adopted, anything else beeps and
  /// keeps listening.
  private func handleRecorded(_ candidate: KeyCombo, isBareEscape: Bool) {
    if isBareEscape {
      cancelRecording()
      return
    }

    if candidate.isValid {
      combo = candidate
      HotkeyCenter.shared.setCombo(candidate)
      endRecording()
    } else {
      NSSound.beep()
    }
  }

  private func cancelRecording() {
    guard isRecording else { return }
    endRecording()
  }

  private func endRecording() {
    isRecording = false
    if let eventMonitor {
      NSEvent.removeMonitor(eventMonitor)
      self.eventMonitor = nil
    }
    // Consult the toggle rather than assuming true: the user can flip the
    // hotkey off while recording is in flight.
    HotkeyCenter.shared.setEnabled(settings.globalHotkeyEnabled)
  }
}
