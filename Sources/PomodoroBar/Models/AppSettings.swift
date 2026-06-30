import SwiftUI

/// Persisted user preferences for PomodoroBar.
///
/// Each property is clamped to a sane range and mirrored to `UserDefaults.standard`
/// in its `didSet` so values survive relaunch.
@Observable
@MainActor
final class AppSettings {
  // MARK: - Constants

  /// Valid ranges for each duration/cycle setting. This is the single source
  /// of truth for both the on-load clamp below and the Settings UI steppers
  /// (`SettingsView`) — keeping one copy means the two can't drift apart.
  enum Bounds {
    static let focusMinutes = 1...120
    static let shortBreakMinutes = 1...60
    static let longBreakMinutes = 1...60
    static let sessionsBeforeLongBreak = 2...12
  }

  private enum Key {
    static let focusMinutes = "focusMinutes"
    static let shortBreakMinutes = "shortBreakMinutes"
    static let longBreakMinutes = "longBreakMinutes"
    static let sessionsBeforeLongBreak = "sessionsBeforeLongBreak"
    static let autoStartBreaks = "autoStartBreaks"
    static let autoStartFocus = "autoStartFocus"
    static let soundEnabled = "soundEnabled"
    static let tickEnabled = "tickEnabled"
    static let hideMenuBarTime = "hideMenuBarTime"
  }

  // MARK: - Stored Properties

  var focusMinutes: Int {
    didSet {
      // Bounds are enforced by the Stepper range in the UI and clamped on load
      // in init. Reassigning here would re-trigger didSet -> infinite recursion
      // -> stack overflow (EXC_BAD_ACCESS), so only persist.
      UserDefaults.standard.set(focusMinutes, forKey: Key.focusMinutes)
    }
  }

  var shortBreakMinutes: Int {
    didSet {
      UserDefaults.standard.set(shortBreakMinutes, forKey: Key.shortBreakMinutes)
    }
  }

  var longBreakMinutes: Int {
    didSet {
      UserDefaults.standard.set(longBreakMinutes, forKey: Key.longBreakMinutes)
    }
  }

  var sessionsBeforeLongBreak: Int {
    didSet {
      UserDefaults.standard.set(
        sessionsBeforeLongBreak, forKey: Key.sessionsBeforeLongBreak,
      )
    }
  }

  var autoStartBreaks: Bool {
    didSet {
      UserDefaults.standard.set(autoStartBreaks, forKey: Key.autoStartBreaks)
    }
  }

  var autoStartFocus: Bool {
    didSet {
      UserDefaults.standard.set(autoStartFocus, forKey: Key.autoStartFocus)
    }
  }

  var soundEnabled: Bool {
    didSet {
      UserDefaults.standard.set(soundEnabled, forKey: Key.soundEnabled)
    }
  }

  var tickEnabled: Bool {
    didSet {
      UserDefaults.standard.set(tickEnabled, forKey: Key.tickEnabled)
    }
  }

  /// When true, the menu bar hides the countdown and shows a ripening tomato
  /// (green -> red as the session progresses) instead.
  var hideMenuBarTime: Bool {
    didSet {
      UserDefaults.standard.set(hideMenuBarTime, forKey: Key.hideMenuBarTime)
    }
  }

  // MARK: - Init

  init() {
    let defaults = UserDefaults.standard

    self.focusMinutes = Self.clamp(
      defaults.object(forKey: Key.focusMinutes) as? Int ?? 25,
      to: Bounds.focusMinutes,
    )
    self.shortBreakMinutes = Self.clamp(
      defaults.object(forKey: Key.shortBreakMinutes) as? Int ?? 5,
      to: Bounds.shortBreakMinutes,
    )
    self.longBreakMinutes = Self.clamp(
      defaults.object(forKey: Key.longBreakMinutes) as? Int ?? 15,
      to: Bounds.longBreakMinutes,
    )
    self.sessionsBeforeLongBreak = Self.clamp(
      defaults.object(forKey: Key.sessionsBeforeLongBreak) as? Int ?? 4,
      to: Bounds.sessionsBeforeLongBreak,
    )

    if defaults.object(forKey: Key.autoStartBreaks) != nil {
      self.autoStartBreaks = defaults.bool(forKey: Key.autoStartBreaks)
    } else {
      self.autoStartBreaks = true
    }
    if defaults.object(forKey: Key.autoStartFocus) != nil {
      self.autoStartFocus = defaults.bool(forKey: Key.autoStartFocus)
    } else {
      self.autoStartFocus = false
    }
    if defaults.object(forKey: Key.soundEnabled) != nil {
      self.soundEnabled = defaults.bool(forKey: Key.soundEnabled)
    } else {
      self.soundEnabled = true
    }
    if defaults.object(forKey: Key.tickEnabled) != nil {
      self.tickEnabled = defaults.bool(forKey: Key.tickEnabled)
    } else {
      self.tickEnabled = false
    }
    if defaults.object(forKey: Key.hideMenuBarTime) != nil {
      self.hideMenuBarTime = defaults.bool(forKey: Key.hideMenuBarTime)
    } else {
      self.hideMenuBarTime = false
    }

    // Mirror back to defaults so persisted values are always consistent with
    // the (possibly clamped) in-memory defaults set above.
    defaults.set(focusMinutes, forKey: Key.focusMinutes)
    defaults.set(shortBreakMinutes, forKey: Key.shortBreakMinutes)
    defaults.set(longBreakMinutes, forKey: Key.longBreakMinutes)
    defaults.set(sessionsBeforeLongBreak, forKey: Key.sessionsBeforeLongBreak)
    defaults.set(autoStartBreaks, forKey: Key.autoStartBreaks)
    defaults.set(autoStartFocus, forKey: Key.autoStartFocus)
    defaults.set(soundEnabled, forKey: Key.soundEnabled)
    defaults.set(tickEnabled, forKey: Key.tickEnabled)
    defaults.set(hideMenuBarTime, forKey: Key.hideMenuBarTime)
  }

  // MARK: - Phase Duration

  /// Returns the duration of a phase in **seconds**.
  func duration(for phase: PomodoroTimer.Phase) -> Int {
    switch phase {
    case .focus:
      return focusMinutes * 60
    case .shortBreak:
      return shortBreakMinutes * 60
    case .longBreak:
      return longBreakMinutes * 60
    }
  }

  // MARK: - Helpers

  private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
    min(max(value, range.lowerBound), range.upperBound)
  }
}