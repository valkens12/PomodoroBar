import SwiftUI

/// The content shown inside the menu bar item.
///
/// Renders the tomato as a rasterized `NSImage` (`MenuBarIcon.tomato`) so it
/// reliably appears in the status item — `MenuBarExtra` does not reliably
/// render arbitrary SwiftUI shape/gradient views as the icon.
///
/// - Idle: a ripe red tomato.
/// - Running/paused, `hideMenuBarTime` off: a phase-tinted tomato + countdown.
/// - Running/paused, `hideMenuBarTime` on: a ripening tomato (green -> red as
///   the session progresses), no countdown.
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
        Image(nsImage: MenuBarIcon.tomato(ripeness: ripeness))
          .accessibilityLabel(timer.accessibilityLabel)
      } else {
        HStack(spacing: 4) {
          Image(nsImage: MenuBarIcon.tomato(phase: timer.phase, size: 12))
          Text(timer.formattedRemaining)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
        }
        .accessibilityLabel(timer.accessibilityLabel)
      }
    } else {
      Image(nsImage: MenuBarIcon.tomato(phase: nil))
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