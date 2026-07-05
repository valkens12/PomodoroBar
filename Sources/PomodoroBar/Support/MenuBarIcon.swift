import AppKit
import SwiftUI

/// Rasterizes `TomatoGlyph` into an `NSImage` for the menu bar status item.
///
/// `MenuBarExtra` does not reliably render an arbitrary SwiftUI `View`
/// (shapes + gradients) as the status-item icon. Rendering the glyph to an
/// `NSImage` and showing it via `Image(nsImage:)` is the documented,
/// reliable path. `isTemplate = false` keeps the tomato in color instead of
/// forcing monochrome template rendering.
///
/// The phase-change bounce (`scale`) is baked into these pixels too, for the
/// same reason: a status item shows whatever bitmap its button holds, but a
/// `scaleEffect` applied afterwards in the `MenuBarExtra` label tree is a
/// compositor-level transform that never reaches that bitmap, so it renders
/// as a no-op. Passing the pose into `ImageRenderer` up front makes it part
/// of the raster, exactly like the color crossfade already is.
enum MenuBarIcon {

  /// The tomato with explicit body gradient stops. The caller resolves the
  /// stops (phase palette, ripening blend, or a mid-animation mix of the
  /// two); this just rasterizes them.
  @MainActor
  static func tomato(
    bright: Color,
    deep: Color,
    size: CGFloat = 16,
    scale: Double = 1,
  ) -> NSImage {
    let view = TomatoGlyph(
      size: size,
      bodyOverride: (bright: bright, deep: deep),
      menuBarOptimized: true
    )
    return render(view, size: size, scale: scale, template: false)
  }

  /// The tomato as a system-style *template* image: a plain silhouette whose
  /// alpha channel is all that matters, so macOS tints it exactly like its
  /// own status items — adapting to light/dark menu bars, desktop tint, and
  /// Increased Contrast for free. Used when the user opts into the
  /// monochrome icon.
  @MainActor
  static func tomatoTemplate(
    size: CGFloat = 16,
    scale: Double = 1,
  ) -> NSImage {
    render(TomatoSilhouette(size: size), size: size, scale: scale, template: true)
  }

  @MainActor
  private static func render(
    _ view: some View,
    size: CGFloat,
    scale: Double,
    template: Bool,
  ) -> NSImage {
    // Extra canvas headroom so the scaled-up glyph doesn't clip against the
    // image bounds — `TomatoShape` already touches its frame's edges at
    // rest, so any scale-up needs somewhere to go. Computed from how far
    // `scale` currently sits from resting (1), so at rest this is exactly
    // zero: the canvas matches `size` pixel-for-pixel, same as before this
    // pose baking existed, and only grows during the ~0.9s bounce. Kept a
    // pure function of the pose (not a fixed constant) so nothing reserves —
    // or jiggles — space when no transition is playing.
    let overshoot = max(0, scale - 1)
    let canvas = size + size * overshoot * 1.6

    let posed = view
      .scaleEffect(scale)
      .frame(width: canvas, height: canvas)

    let renderer = ImageRenderer(content: posed)
    renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

    let fallback = NSImage(size: NSSize(width: canvas, height: canvas))
    guard let image = renderer.nsImage else {
      return fallback
    }
    image.isTemplate = template
    return image
  }
}

/// The tomato reduced to a flat single-color silhouette (body + calyx) for
/// template rendering. The fill color is irrelevant — template images are
/// masked by alpha — black just makes the raster unambiguous.
private struct TomatoSilhouette: View {
  var size: CGFloat

  var body: some View {
    let calyxSize = size * 0.30
    return ZStack {
      TomatoShape()
        .fill(Color.black)
      TomatoCalyx(leafCount: size < 16 ? 3 : 5)
        .fill(Color.black)
        .frame(width: calyxSize, height: calyxSize)
        .offset(y: -size * 0.34)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}