import SwiftUI

/// The content shown inside the menu bar item.
///
/// When idle: a small tomato glyph alone. When running or paused:
/// - if `hideMenuBarTime` is off: a tiny phase-tinted tomato + the countdown.
/// - if `hideMenuBarTime` is on: a ripening tomato alone, green at the start
///   of the session ripening to red as time elapses (no countdown text).
struct TimerMenuBarLabel: View {
  let timer: PomodoroTimer
  let settings: AppSettings

  private var showsTime: Bool {
    timer.runState == .running || timer.runState == .paused
  }

  /// 0 at the start of a session (unripe green) -> 1 at the end (ripe red).
  private var ripeness: Double {
    1.0 - timer.progress
  }

  var body: some View {
    if showsTime {
      if settings.hideMenuBarTime {
        TomatoGlyph(
          size: 14,
          ripeness: ripeness,
          menuBarOptimized: true
        )
        .accessibilityLabel(timer.accessibilityLabel)
      } else {
        HStack(spacing: 4) {
          TomatoGlyph(size: 12, phase: timer.phase, menuBarOptimized: true)
          Text(timer.formattedRemaining)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
        }
        .accessibilityLabel(timer.accessibilityLabel)
      }
    } else {
      TomatoGlyph(size: 13, phase: nil, menuBarOptimized: true)
        .accessibilityLabel(timer.accessibilityLabel)
    }
  }
}

private extension PomodoroTimer {
  /// VoiceOver-friendly summary of the current timer state for the menu bar.
  var accessibilityLabel: String {
    switch runState {
    case .idle:
      return "Pomodoro idle, \(phase.label)"
    case .running:
      return "Pomodoro \(phase.label), \(formattedRemaining) remaining"
    case .paused:
      return "Pomodoro \(phase.label) paused, \(formattedRemaining) remaining"
    }
  }
}