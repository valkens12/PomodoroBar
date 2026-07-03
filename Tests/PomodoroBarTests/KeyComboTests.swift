import Carbon.HIToolbox
import Foundation
import Testing

@testable import PomodoroBar

// MARK: - Global hotkey combinations

@Suite("Key combo validity")
struct KeyComboValidityTests {
  @Test("a bare letter is invalid — it would hijack ordinary typing")
  func bareLetter() {
    let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_P), carbonModifiers: 0)
    #expect(!combo.isValid)
  }

  @Test("shift alone does not anchor a letter")
  func shiftOnlyLetter() {
    let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_P), carbonModifiers: UInt32(shiftKey))
    #expect(!combo.isValid)
  }

  @Test("control anchors a letter", arguments: [controlKey, optionKey, cmdKey])
  func anchoredLetter(modifier: Int) {
    let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_P), carbonModifiers: UInt32(modifier))
    #expect(combo.isValid)
  }

  @Test("a bare function key is valid by convention")
  func bareFunctionKey() {
    let combo = KeyCombo(keyCode: UInt32(kVK_F5), carbonModifiers: 0)
    #expect(combo.isValid)
  }

  @Test("the default combo is valid")
  func defaultCombo() {
    #expect(KeyCombo.defaultCombo.isValid)
  }
}

@Suite("Key combo display")
struct KeyComboDisplayTests {
  @Test("modifiers render in canonical control-option-shift-command order")
  func modifierOrder() {
    let combo = KeyCombo(
      keyCode: UInt32(kVK_Space),
      carbonModifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey),
    )
    #expect(combo.displayString == "⌃⌥⇧⌘Space")
  }

  @Test("layout-independent keys use their symbols")
  func specialKeySymbols() {
    let arrow = KeyCombo(keyCode: UInt32(kVK_LeftArrow), carbonModifiers: UInt32(cmdKey))
    #expect(arrow.displayString == "⌘←")

    let function = KeyCombo(keyCode: UInt32(kVK_F5), carbonModifiers: 0)
    #expect(function.displayString == "F5")
  }

  @Test("accessible description spells the combination out in words")
  func accessibleDescription() {
    let combo = KeyCombo(
      keyCode: UInt32(kVK_Space),
      carbonModifiers: UInt32(controlKey | optionKey),
    )
    #expect(combo.accessibleDescription == "Control Option Space")
  }
}
