import SwiftUI

/// Persisted user preferences for PomodoroBar.
///
/// Each property is clamped to a sane range and mirrored to `UserDefaults.standard`
/// in its `didSet` so values survive relaunch.
@Observable
@MainActor
final class AppSettings {
  // MARK: - Constants

  private enum Limits {
    static let focusMinutesLower = 1
    static let focusMinutesUpper = 120
    static let shortBreakLower = 1
    static let shortBreakUpper = 60
    static let longBreakLower = 1
    static let longBreakUpper = 60
    static let sessionsLower = 2
    static let sessionsUpper = 12
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
  }

  // MARK: - Stored Properties

  var focusMinutes: Int {
    didSet {
      focusMinutes = clamp(
        focusMinutes,
        lower: Limits.focusMinutesLower,
        upper: Limits.focusMinutesUpper,
      )
      UserDefaults.standard.set(focusMinutes, forKey: Key.focusMinutes)
    }
  }

  var shortBreakMinutes: Int {
    didSet {
      shortBreakMinutes = clamp(
        shortBreakMinutes,
        lower: Limits.shortBreakLower,
        upper: Limits.shortBreakUpper,
      )
      UserDefaults.standard.set(shortBreakMinutes, forKey: Key.shortBreakMinutes)
    }
  }

  var longBreakMinutes: Int {
    didSet {
      longBreakMinutes = clamp(
        longBreakMinutes,
        lower: Limits.longBreakLower,
        upper: Limits.longBreakUpper,
      )
      UserDefaults.standard.set(longBreakMinutes, forKey: Key.longBreakMinutes)
    }
  }

  var sessionsBeforeLongBreak: Int {
    didSet {
      sessionsBeforeLongBreak = clamp(
        sessionsBeforeLongBreak,
        lower: Limits.sessionsLower,
        upper: Limits.sessionsUpper,
      )
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

  // MARK: - Init

  init() {
    let defaults = UserDefaults.standard

    self.focusMinutes = Self.clamp(
      defaults.object(forKey: Key.focusMinutes) as? Int ?? 25,
      lower: Limits.focusMinutesLower,
      upper: Limits.focusMinutesUpper,
    )
    self.shortBreakMinutes = Self.clamp(
      defaults.object(forKey: Key.shortBreakMinutes) as? Int ?? 5,
      lower: Limits.shortBreakLower,
      upper: Limits.shortBreakUpper,
    )
    self.longBreakMinutes = Self.clamp(
      defaults.object(forKey: Key.longBreakMinutes) as? Int ?? 15,
      lower: Limits.longBreakLower,
      upper: Limits.longBreakUpper,
    )
    self.sessionsBeforeLongBreak = Self.clamp(
      defaults.object(forKey: Key.sessionsBeforeLongBreak) as? Int ?? 4,
      lower: Limits.sessionsLower,
      upper: Limits.sessionsUpper,
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

  private static func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
    min(max(value, lower), upper)
  }

  private func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
    Self.clamp(value, lower: lower, upper: upper)
  }
}