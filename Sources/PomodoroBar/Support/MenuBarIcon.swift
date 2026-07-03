import AppKit
import SwiftUI

/// Rasterizes `TomatoGlyph` into an `NSImage` for the menu bar status item.
///
/// `MenuBarExtra` does not reliably render an arbitrary SwiftUI `View`
/// (shapes + gradients) as the status-item icon. Rendering the glyph to an
/// `NSImage` and showing it via `Image(nsImage:)` is the documented,
/// reliable path. `isTemplate = false` keeps the tomato in color instead of
/// forcing monochrome template rendering.
enum MenuBarIcon {

  @MainActor
  static func tomato(
    ripeness: Double? = nil,
    phase: PomodoroTimer.Phase? = nil,
    size: CGFloat = 16
  ) -> NSImage {
    let view = TomatoGlyph(
      size: size,
      phase: phase,
      ripeness: ripeness,
      menuBarOptimized: true
    )
    return render(view, size: size, template: false)
  }

  /// The tomato as a system-style *template* image: a plain silhouette whose
  /// alpha channel is all that matters, so macOS tints it exactly like its
  /// own status items — adapting to light/dark menu bars, desktop tint, and
  /// Increased Contrast for free. Used when the user opts into the
  /// monochrome icon.
  @MainActor
  static func tomatoTemplate(size: CGFloat = 16) -> NSImage {
    render(TomatoSilhouette(size: size), size: size, template: true)
  }

  @MainActor
  private static func render(
    _ view: some View,
    size: CGFloat,
    template: Bool,
  ) -> NSImage {
    let renderer = ImageRenderer(content: view)
    renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

    let fallback = NSImage(size: NSSize(width: size, height: size))
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