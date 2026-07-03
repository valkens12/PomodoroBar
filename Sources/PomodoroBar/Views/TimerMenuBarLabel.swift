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
/// - Paused, or running-but-waiting-for-a-focus-app: dimmed, so the one
///   surface you see most of the time tells you at a glance whether the
///   countdown is actually moving without opening the popover.
struct TimerMenuBarLabel: View {
  let timer: PomodoroTimer
  let settings: AppSettings

  private var showsTime: Bool {
    timer.runState == .running || timer.runState == .paused
  }

  /// True when the countdown isn't actually advancing right now, either
  /// because the user paused it or because focus gating is holding it.
  private var isDimmed: Bool {
    timer.runState == .paused || timer.isWaitingForFocusApp
  }

  /// 0 at the start of a session (unripe green) -> 1 at the end (ripe red).
  private var ripeness: Double {
    1.0 - timer.progress
  }

  var body: some View {
    Group {
      if showsTime {
        if settings.hideMenuBarTime {
          HStack(spacing: 3) {
            tomatoImage(size: 16)
            if isDimmed {
              pauseGlyph
            }
          }
        } else {
          HStack(spacing: 4) {
            tomatoImage(size: 12)
            if isDimmed {
              pauseGlyph
            }
            Text(timer.formattedRemaining)
              .font(Typography.menuBarCountdown)
              .monospacedDigit()
          }
        }
      } else {
        tomatoImage(size: 16)
      }
    }
    .opacity(isDimmed ? 0.45 : 1.0)
    .accessibilityLabel(timer.accessibilityLabel)
  }

  /// The tomato at the given point size, honoring the monochrome preference.
  /// The template variant lets macOS tint the silhouette like its own status
  /// items; the color variant keeps the ripening/phase tinting.
  private func tomatoImage(size: CGFloat) -> Image {
    if settings.monochromeMenuBarIcon {
      return Image(nsImage: MenuBarIcon.tomatoTemplate(size: size))
    } else {
      return Image(nsImage: colorTomato(size: size))
    }
  }

  /// The color (non-template) tomato at the given point size. Pulled out so
  /// `tomatoImage` has a simple two-branch body; the three call sites only
  /// differ in which `MenuBarIcon.tomato` arguments to pass.
  @MainActor
  private func colorTomato(size: CGFloat) -> NSImage {
    if showsTime, settings.hideMenuBarTime {
      return MenuBarIcon.tomato(ripeness: ripeness, size: size)
    } else if showsTime {
      return MenuBarIcon.tomato(phase: timer.phase, size: size)
    } else {
      return MenuBarIcon.tomato(phase: nil, size: size)
    }
  }

  /// Explicit pause indicator alongside the dimming, so a suspended countdown
  /// doesn't rely on the opacity difference alone to be noticed.
  private var pauseGlyph: some View {
    Image(systemName: "pause.fill")
      .font(.system(size: 8, weight: .bold))
  }
}

private extension PomodoroTimer {
  /// VoiceOver-friendly summary of the current timer state for the menu bar.
  var accessibilityLabel: String {
    switch runState {
    case .idle:
      return "Pomodoro idle, \(phase.label)"
    case .running:
      return isWaitingForFocusApp
        ? "Pomodoro \(phase.label), paused, waiting for a focus app"
        : "Pomodoro \(phase.label), \(formattedRemaining) remaining"
    case .paused:
      return "Pomodoro \(phase.label) paused, \(formattedRemaining) remaining"
    }
  }
}