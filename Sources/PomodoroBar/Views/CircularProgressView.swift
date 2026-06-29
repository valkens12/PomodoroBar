import SwiftUI

/// A circular progress ring surrounding a centered tomato glyph.
///
/// The ring is filled with a phase-specific tomato-plant gradient drawn over
/// a faint vine-green track, rotated so progress depletes clockwise. A
/// `TomatoGlyph` sits in the center so the ring appears to wrap the tomato.
struct CircularProgressView: View {
  let progress: Double
  let phase: PomodoroTimer.Phase

  /// Clamped so `Circle.trim` always receives a strictly positive value;
  /// a zero `to:` would render nothing and visually disappear at the end.
  private var trimmedProgress: Double {
    min(1.0, max(0.001, progress))
  }

  private let ringSize: CGFloat = 170
  private let lineWidth: CGFloat = 12
  private let glyphSize: CGFloat = 84

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

      // The tomato at the center of the ring.
      TomatoGlyph(size: glyphSize, phase: phase)
    }
    .frame(width: ringSize, height: ringSize)
    .accessibilityHidden(true)
  }
}