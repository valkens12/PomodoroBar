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
    let renderer = ImageRenderer(content: view)
    renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

    let fallback = NSImage(size: NSSize(width: size, height: size))
    guard let image = renderer.nsImage else {
      return fallback
    }
    image.isTemplate = false
    return image
  }
}