import AppKit
import Carbon.HIToolbox

/// Registers the system-wide hotkey (user-recordable, default ⌃⌥P) that
/// toggles start/pause without opening the popover.
///
/// Uses Carbon's `RegisterEventHotKey`, which remains the sanctioned way to
/// claim a global hotkey without Accessibility permission (an `NSEvent`
/// global monitor can only *observe* keystrokes, and only after the user
/// grants Input Monitoring — a far heavier ask for one shortcut).
@MainActor
final class HotkeyCenter {
  static let shared = HotkeyCenter()

  /// Invoked on the main actor when the hotkey fires. Set once at launch by
  /// the App, which owns the timer.
  var onHotkey: (() -> Void)?

  private var combo: KeyCombo = .defaultCombo
  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?

  private init() {}

  func setEnabled(_ enabled: Bool) {
    if enabled {
      register()
    } else {
      unregister()
    }
  }

  /// Swaps in a new combination, re-registering on the spot if the hotkey is
  /// currently live. Called at launch with the persisted combo and by the
  /// recorder field when the user records a new one.
  func setCombo(_ combo: KeyCombo) {
    guard combo != self.combo else { return }
    self.combo = combo
    if hotKeyRef != nil {
      unregister()
      register()
    }
  }

  private func register() {
    guard hotKeyRef == nil else { return }
    installHandlerIfNeeded()

    // Four-char code 'POMD' identifying our hotkeys to the event handler.
    let hotKeyID = EventHotKeyID(signature: 0x504F_4D44, id: 1)
    var ref: EventHotKeyRef?
    let status = RegisterEventHotKey(
      combo.keyCode,
      combo.carbonModifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &ref,
    )
    if status == noErr {
      hotKeyRef = ref
    }
  }

  private func unregister() {
    guard let ref = hotKeyRef else { return }
    UnregisterEventHotKey(ref)
    hotKeyRef = nil
  }

  /// Installs the (single, process-lifetime) Carbon event handler. The C
  /// callback can't capture context, so it reaches back through the shared
  /// instance; Carbon delivers hotkey events on the main thread, but the
  /// explicit main-actor hop keeps that assumption out of the isolation
  /// checker's way.
  private func installHandlerIfNeeded() {
    guard eventHandlerRef == nil else { return }

    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed),
    )
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, _ in
        Task { @MainActor in
          HotkeyCenter.shared.onHotkey?()
        }
        return noErr
      },
      1,
      &eventType,
      nil,
      &eventHandlerRef,
    )
  }
}
