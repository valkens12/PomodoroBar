import AppKit
import Carbon.HIToolbox

/// A recordable global-hotkey combination: a virtual key code plus Carbon
/// modifier flags — the exact currency `RegisterEventHotKey` deals in.
///
/// Persisted by `AppSettings` as its two raw components; displayed via
/// `displayString` (symbols, e.g. "⌃⌥P") for UI and `accessibleDescription`
/// (words, e.g. "Control Option P") for VoiceOver.
struct KeyCombo: Equatable, Sendable {
  let keyCode: UInt32
  let carbonModifiers: UInt32

  /// ⌃⌥P — "P" for Pomodoro; unclaimed by the system.
  static let defaultCombo = KeyCombo(
    keyCode: UInt32(kVK_ANSI_P),
    carbonModifiers: UInt32(controlKey | optionKey),
  )

  init(keyCode: UInt32, carbonModifiers: UInt32) {
    self.keyCode = keyCode
    self.carbonModifiers = carbonModifiers
  }

  /// The combination held in a `keyDown` event, translating Cocoa modifier
  /// flags to their Carbon equivalents.
  init(event: NSEvent) {
    self.init(
      keyCode: UInt32(event.keyCode),
      carbonModifiers: Self.carbonFlags(from: event.modifierFlags),
    )
  }

  // MARK: - Validity

  /// A combination worth registering globally: either a function key (which
  /// stands alone by convention) or something anchored by ⌃, ⌥, or ⌘.
  /// A bare or shift-only letter would hijack ordinary typing system-wide.
  var isValid: Bool {
    isFunctionKey || hasAnchoringModifier
  }

  private var isFunctionKey: Bool {
    Self.functionKeyCodes.contains(keyCode)
  }

  private var hasAnchoringModifier: Bool {
    carbonModifiers & UInt32(controlKey | optionKey | cmdKey) != 0
  }

  // MARK: - Display

  /// Symbol form for UI, in the canonical ⌃⌥⇧⌘ order: "⌃⌥P", "⌘F5", "⌃Space".
  var displayString: String {
    modifierText(
      control: "⌃", option: "⌥", shift: "⇧", command: "⌘", separator: ""
    ) + keyName
  }

  /// Spoken form for VoiceOver: "Control Option P".
  var accessibleDescription: String {
    modifierText(
      control: "Control", option: "Option", shift: "Shift", command: "Command",
      separator: " "
    ) + spokenKeyName
  }

  private func modifierText(
    control: String,
    option: String,
    shift: String,
    command: String,
    separator: String,
  ) -> String {
    var parts: [String] = []
    if carbonModifiers & UInt32(controlKey) != 0 { parts.append(control) }
    if carbonModifiers & UInt32(optionKey) != 0 { parts.append(option) }
    if carbonModifiers & UInt32(shiftKey) != 0 { parts.append(shift) }
    if carbonModifiers & UInt32(cmdKey) != 0 { parts.append(command) }
    guard !parts.isEmpty else { return "" }
    return parts.joined(separator: separator) + separator
  }

  private var keyName: String {
    if let special = Self.specialKeyNames[keyCode] {
      return special.symbol
    }
    return Self.characterName(for: keyCode) ?? "Key \(keyCode)"
  }

  private var spokenKeyName: String {
    if let special = Self.specialKeyNames[keyCode] {
      return special.spoken
    }
    return Self.characterName(for: keyCode) ?? "key \(keyCode)"
  }

  // MARK: - Key tables

  private static let functionKeyCodes: Set<UInt32> = [
    UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
    UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
    UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12),
    UInt32(kVK_F13), UInt32(kVK_F14), UInt32(kVK_F15), UInt32(kVK_F16),
    UInt32(kVK_F17), UInt32(kVK_F18), UInt32(kVK_F19),
  ]

  /// Keys whose name isn't a typed character: layout-independent symbols and
  /// their VoiceOver spellings.
  private static let specialKeyNames: [UInt32: (symbol: String, spoken: String)] = [
    UInt32(kVK_Space): ("Space", "Space"),
    UInt32(kVK_Return): ("↩", "Return"),
    UInt32(kVK_ANSI_KeypadEnter): ("⌅", "Enter"),
    UInt32(kVK_Tab): ("⇥", "Tab"),
    UInt32(kVK_Delete): ("⌫", "Delete"),
    UInt32(kVK_ForwardDelete): ("⌦", "Forward Delete"),
    UInt32(kVK_Escape): ("⎋", "Escape"),
    UInt32(kVK_Home): ("↖", "Home"),
    UInt32(kVK_End): ("↘", "End"),
    UInt32(kVK_PageUp): ("⇞", "Page Up"),
    UInt32(kVK_PageDown): ("⇟", "Page Down"),
    UInt32(kVK_LeftArrow): ("←", "Left Arrow"),
    UInt32(kVK_RightArrow): ("→", "Right Arrow"),
    UInt32(kVK_UpArrow): ("↑", "Up Arrow"),
    UInt32(kVK_DownArrow): ("↓", "Down Arrow"),
    UInt32(kVK_F1): ("F1", "F1"), UInt32(kVK_F2): ("F2", "F2"),
    UInt32(kVK_F3): ("F3", "F3"), UInt32(kVK_F4): ("F4", "F4"),
    UInt32(kVK_F5): ("F5", "F5"), UInt32(kVK_F6): ("F6", "F6"),
    UInt32(kVK_F7): ("F7", "F7"), UInt32(kVK_F8): ("F8", "F8"),
    UInt32(kVK_F9): ("F9", "F9"), UInt32(kVK_F10): ("F10", "F10"),
    UInt32(kVK_F11): ("F11", "F11"), UInt32(kVK_F12): ("F12", "F12"),
    UInt32(kVK_F13): ("F13", "F13"), UInt32(kVK_F14): ("F14", "F14"),
    UInt32(kVK_F15): ("F15", "F15"), UInt32(kVK_F16): ("F16", "F16"),
    UInt32(kVK_F17): ("F17", "F17"), UInt32(kVK_F18): ("F18", "F18"),
    UInt32(kVK_F19): ("F19", "F19"),
  ]

  // MARK: - Translation

  static func carbonFlags(from cocoa: NSEvent.ModifierFlags) -> UInt32 {
    var flags: UInt32 = 0
    if cocoa.contains(.control) { flags |= UInt32(controlKey) }
    if cocoa.contains(.option) { flags |= UInt32(optionKey) }
    if cocoa.contains(.shift) { flags |= UInt32(shiftKey) }
    if cocoa.contains(.command) { flags |= UInt32(cmdKey) }
    return flags
  }

  /// Resolves a character key's display name ("P", "É", "5") through the
  /// user's current keyboard layout, so the recorded shortcut reads the way
  /// the user's keyboard is actually labeled.
  private static func characterName(for keyCode: UInt32) -> String? {
    guard
      let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
      let layoutDataPointer = TISGetInputSourceProperty(
        source, kTISPropertyUnicodeKeyLayoutData,
      )
    else { return nil }

    let layoutData = Unmanaged<CFData>
      .fromOpaque(layoutDataPointer)
      .takeUnretainedValue() as Data

    return layoutData.withUnsafeBytes { buffer -> String? in
      guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
        return nil
      }
      var deadKeyState: UInt32 = 0
      var characters = [UniChar](repeating: 0, count: 4)
      var length = 0
      let status = UCKeyTranslate(
        layout,
        UInt16(keyCode),
        UInt16(kUCKeyActionDisplay),
        0, // no modifiers: the base character names the key
        UInt32(LMGetKbdType()),
        OptionBits(kUCKeyTranslateNoDeadKeysBit),
        &deadKeyState,
        characters.count,
        &length,
        &characters,
      )
      guard status == noErr, length > 0 else { return nil }
      let name = String(utf16CodeUnits: characters, count: length)
        .uppercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return name.isEmpty ? nil : name
    }
  }
}
