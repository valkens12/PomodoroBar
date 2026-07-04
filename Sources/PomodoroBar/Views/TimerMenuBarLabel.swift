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
/// - Phase change (focus <-> break): a short squash-and-pop bounce while the
///   body crossfades to the new phase's colors, driven frame-by-frame by
///   `MenuBarTransitionAnimator` because the status item never runs implicit
///   SwiftUI animations. The animator is triggered by the timer model's
///   `onPhaseChange` (wired in `PomodoroBarApp`), not `.onChange` here —
///   a `MenuBarExtra` label re-renders through observation but never
///   receives view lifecycle events, so `.onChange` would never fire.
struct TimerMenuBarLabel: View {
  let timer: PomodoroTimer
  let settings: AppSettings
  let animator: MenuBarTransitionAnimator

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
            tomatoView(size: 16)
            if isDimmed {
              pauseGlyph
            }
          }
        } else {
          HStack(spacing: 4) {
            tomatoView(size: 12)
            if isDimmed {
              pauseGlyph
            }
            Text(timer.formattedRemaining)
              .font(Typography.menuBarCountdown)
              .monospacedDigit()
          }
        }
      } else {
        tomatoView(size: 16)
      }
    }
    .opacity(isDimmed ? 0.45 : 1.0)
    .accessibilityLabel(timer.accessibilityLabel)
  }

  /// The tomato at the given point size, carrying the phase-change bounce.
  /// The scale/rotation are plain static transforms re-rendered each frame by
  /// the animator's progress updates, which is what actually animates inside
  /// a status item.
  private func tomatoView(size: CGFloat) -> some View {
    tomatoImage(size: size)
      .scaleEffect(animator.scale)
      .rotationEffect(.degrees(animator.wiggleDegrees))
  }

  /// The tomato at the given point size, honoring the monochrome preference.
  /// The template variant lets macOS tint the silhouette like its own status
  /// items; the color variant keeps the ripening/phase tinting.
  private func tomatoImage(size: CGFloat) -> Image {
    if settings.monochromeMenuBarIcon {
      return Image(nsImage: MenuBarIcon.tomatoTemplate(size: size))
    } else {
      let stops = animator.stops(target: steadyStops)
      return Image(
        nsImage: MenuBarIcon.tomato(
          bright: stops.bright, deep: stops.deep, size: size
        )
      )
    }
  }

  /// The body gradient stops the icon settles on outside a transition:
  /// ripening when the countdown is hidden, phase-tinted while running, and
  /// the ripe-red default when idle.
  private var steadyStops: (bright: Color, deep: Color) {
    // Focus gating is holding the countdown: grey the tomato so the always-
    // visible icon reads as stopped, not merely a fainter red. Baked into the
    // icon's color stops rather than a `.grayscale()` modifier, which a
    // MenuBarExtra label won't reliably render.
    if timer.isWaitingForFocusApp {
      return Theme.mutedStops
    }
    if showsTime, settings.hideMenuBarTime {
      return Theme.ripeStops(for: ripeness)
    }
    return Theme.bodyStops(for: showsTime ? timer.phase : nil)
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
      return String(
        format: String(
          localized: "menubar.idle", defaultValue: "Pomodoro idle, %@"
        ),
        phase.label,
      )
    case .running:
      return isWaitingForFocusApp
        ? String(
          format: String(
            localized: "menubar.runningWaiting",
            defaultValue: "Pomodoro %@, paused, waiting for a focus app"
          ),
          phase.label,
        )
        : String(
          format: String(
            localized: "menubar.running",
            defaultValue: "Pomodoro %@ running, %@ remaining"
          ),
          phase.label, formattedRemaining,
        )
    case .paused:
      return String(
        format: String(
          localized: "menubar.paused",
          defaultValue: "Pomodoro %@ paused, %@ remaining"
        ),
        phase.label, formattedRemaining,
      )
    }
  }
}