import SwiftUI

/// A circular progress ring surrounding a centered tomato glyph.
///
/// The ring is filled with a phase-specific tomato-plant gradient drawn over
/// a faint vine-green track, rotated so progress depletes clockwise. A
/// `TomatoGlyph` sits in the center so the ring appears to wrap the tomato.
struct CircularProgressView: View {
  let progress: Double
  let phase: PomodoroTimer.Phase
  /// Observed so the tomato can play its start pop the moment the timer
  /// transitions into a running state. Defaults to `false` so callers that
  /// don't care about the animation (if any) compile unchanged.
  var isRunning: Bool = false

  /// Clamped so `Circle.trim` always receives a strictly positive value;
  /// a zero `to:` would render nothing and visually disappear at the end.
  private var trimmedProgress: Double {
    min(1.0, max(0.001, progress))
  }

  private let ringSize: CGFloat = 170
  private let lineWidth: CGFloat = 12
  private let glyphSize: CGFloat = 84

  /// Bumped each time the timer enters a running state. The value itself is
  /// meaningless — `PhaseAnimator(trigger:)` replays its sequence on every
  /// change, so this is the signal that fires the one-shot start pop.
  @State private var startTick = 0

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      // Faint vine-green track ring behind the progress arc.
      Circle()
        .stroke(Theme.vineGreen.opacity(0.15), lineWidth: lineWidth)

      // Progress arc, trimmed and rotated to start at 12 o'clock.
      Circle()
        .trim(from: 0, to: trimmedProgress)
        .stroke(
          Theme.gradient(for: phase),
          style: StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round
          )
        )
        .rotationEffect(.degrees(-90))
        .animation(.linear(duration: 0.3), value: progress)
        .animation(.easeInOut(duration: 0.35), value: phase)

      // The tomato at the center of the ring.
      tomatoGlyph
    }
    .frame(width: ringSize, height: ringSize)
    .animation(.easeInOut(duration: 0.35), value: phase)
    .accessibilityHidden(true)
    .onChange(of: isRunning) { _, running in
      // Fire the pop on every transition into running — Start and Resume
      // share the play button, so both get the satisfying "go" kick. Skipped
      // entirely when the user has requested reduced motion.
      guard running, !reduceMotion else { return }
      startTick &+= 1
    }
  }

  // MARK: - Tomato

  /// The centered tomato, wrapped in a one-shot squash-and-stretch when the
  /// timer starts. Falls back to a static glyph under reduced motion.
  @ViewBuilder
  private var tomatoGlyph: some View {
    if reduceMotion {
      TomatoGlyph(size: glyphSize, phase: phase)
    } else {
      PhaseAnimator(TomatoPop.phases, trigger: startTick) { popPhase in
        TomatoGlyph(size: glyphSize, phase: phase)
          .scaleEffect(CGSize(width: popPhase.scaleX, height: popPhase.scaleY))
      } animation: { popPhase in
        popPhase.animation
      }
    }
  }
}

// MARK: - TomatoPop

/// The squash-and-stretch sequence the tomato plays on start:
/// rest → squash (anticipation, pressed wide and short) → stretch (popped
/// tall and narrow) → rest (springy settle). Begins and ends at `rest` so the
/// glyph is never left mid-deform, and each start replays the full sequence.
private enum TomatoPop: Equatable {
  case rest, squash, stretch

  static let phases: [TomatoPop] = [.rest, .squash, .stretch, .rest]

  /// Horizontal scale at this phase (non-uniform so the tomato squashes,
  /// preserving apparent volume rather than a plain zoom).
  var scaleX: CGFloat {
    switch self {
    case .rest: 1.0
    case .squash: 1.12
    case .stretch: 0.92
    }
  }

  /// Vertical scale at this phase.
  var scaleY: CGFloat {
    switch self {
    case .rest: 1.0
    case .squash: 0.86
    case .stretch: 1.16
    }
  }

  /// Animation used to transition *into* this phase.
  var animation: Animation {
    switch self {
    case .rest: .spring(duration: 0.34, bounce: 0.3)
    case .squash: .easeOut(duration: 0.12)
    case .stretch: .spring(duration: 0.26, bounce: 0.42)
    }
  }
}