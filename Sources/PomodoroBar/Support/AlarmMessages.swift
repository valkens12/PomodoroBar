import Foundation

/// The playful one-liner the popover ring flips to when a phase-change alarm
/// is acknowledged, picked at random for the direction being entered. Localized
/// so the German build keeps parity with English.
enum AlarmMessages {

  /// A random playful line for the phase now starting.
  static func random(for incoming: PomodoroTimer.Phase) -> String {
    let pool = incoming == .focus ? focusLines : breakLines
    return pool.randomElement() ?? pool[0]
  }

  private static var focusLines: [String] {
    [
      String(localized: "alarm.focus.1", defaultValue: "Lock in"),
      String(localized: "alarm.focus.2", defaultValue: "Back at it"),
      String(localized: "alarm.focus.3", defaultValue: "Game face on"),
      String(localized: "alarm.focus.4", defaultValue: "Let's cook"),
    ]
  }

  private static var breakLines: [String] {
    [
      String(localized: "alarm.break.1", defaultValue: "Go touch grass 🍅"),
      String(localized: "alarm.break.2", defaultValue: "Screens down"),
      String(localized: "alarm.break.3", defaultValue: "Stretch it out"),
      String(localized: "alarm.break.4", defaultValue: "Breathe, champ"),
    ]
  }
}
