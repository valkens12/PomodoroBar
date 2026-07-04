import AppKit
import SwiftUI

/// Visual theme for PomodoroBar: a refined tomato-plant palette plus the
/// tomato glyph primitives (shape, calyx, glyph) used across the menu bar
/// icon, the popover progress ring, stat cards, and settings tabs.
enum Theme {

  // MARK: - Tomato Palette

  /// Ripe tomato red — the body of the focus tomato.
  static let tomatoRed: Color = Color(red: 0.83, green: 0.18, blue: 0.14)

  /// Sun-ripened orange — the warm highlight side of the focus tomato.
  static let tomatoOrange: Color = Color(red: 0.98, green: 0.42, blue: 0.16)

  /// Vine / stem green — deep calm, used for the long-break phase.
  static let vineGreen: Color = Color(red: 0.30, green: 0.55, blue: 0.20)

  /// Fresh calyx leaf green — used for the calyx and the short-break phase.
  static let leafGreen: Color = Color(red: 0.45, green: 0.75, blue: 0.30)

  /// Card surface for content-layer elements (stat cards). The popover itself
  /// uses real Liquid Glass (`.glassEffect()`), not this — this is only for
  /// surfaces that sit *inside* an opaque window (the Settings scene), which
  /// doesn't get glass automatically and needs an explicit dark variant.
  static let cardBackground: Color = Color(
    nsColor: NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        ? NSColor(red: 0.22, green: 0.16, blue: 0.15, alpha: 1)
        : NSColor(red: 0.98, green: 0.93, blue: 0.91, alpha: 1)
    }
  )

  // MARK: - Phase Palettes

  /// A cohesive tomato-plant gradient for the given phase.
  /// - focus: tomatoRed -> tomatoOrange (the main tomato)
  /// - shortBreak: leafGreen -> a lighter fresh green
  /// - longBreak: vineGreen -> a deep calm green-teal
  static func gradient(for phase: PomodoroTimer.Phase) -> Gradient {
    switch phase {
    case .focus:
      return Gradient(colors: [tomatoRed, tomatoOrange])
    case .shortBreak:
      return Gradient(
        colors: [
          leafGreen,
          Color(red: 0.58, green: 0.85, blue: 0.40),
        ]
      )
    case .longBreak:
      return Gradient(
        colors: [
          vineGreen,
          Color(red: 0.22, green: 0.50, blue: 0.42),
        ]
      )
    }
  }

  /// The primary accent color for the given phase, used for fills, buttons,
  /// gradients, and the status bar indicator dot. For *text* use
  /// `textColor(for:)` — these fill accents (leafGreen especially) fall short
  /// of the 4.5:1 contrast minimum against a light window background.
  static func color(for phase: PomodoroTimer.Phase) -> Color {
    switch phase {
    case .focus:
      return tomatoRed
    case .shortBreak:
      return leafGreen
    case .longBreak:
      return vineGreen
    }
  }

  /// Phase accent tuned for use as a *filled control background* behind
  /// white label text (the prominent Start/Pause button). `color(for:)` is
  /// too bright for this in the break phases — white on `leafGreen` is
  /// roughly 2:1 — so the greens are darkened until white text clears 4.5:1
  /// in both appearances (prominent buttons keep white text in dark mode
  /// too, so one value per phase suffices).
  static func buttonTint(for phase: PomodoroTimer.Phase) -> Color {
    switch phase {
    case .focus:
      // White on tomatoRed already measures ~5:1.
      return tomatoRed
    case .shortBreak:
      return Color(red: 0.24, green: 0.50, blue: 0.14)
    case .longBreak:
      return Color(red: 0.22, green: 0.46, blue: 0.30)
    }
  }

  /// Phase accent tuned for use as text: darkened in light mode and
  /// brightened in dark mode so labels reach at least 4.5:1 against the
  /// window background in both appearances.
  static func textColor(for phase: PomodoroTimer.Phase) -> Color {
    switch phase {
    case .focus:
      return dynamic(
        light: NSColor(red: 0.78, green: 0.16, blue: 0.13, alpha: 1),
        dark: NSColor(red: 1.00, green: 0.55, blue: 0.48, alpha: 1),
      )
    case .shortBreak:
      return dynamic(
        light: NSColor(red: 0.27, green: 0.52, blue: 0.16, alpha: 1),
        dark: NSColor(red: 0.62, green: 0.85, blue: 0.45, alpha: 1),
      )
    case .longBreak:
      return dynamic(
        light: NSColor(red: 0.24, green: 0.46, blue: 0.17, alpha: 1),
        dark: NSColor(red: 0.55, green: 0.80, blue: 0.45, alpha: 1),
      )
    }
  }

  /// A `Color` that resolves per-appearance, following the same pattern as
  /// `cardBackground`.
  private static func dynamic(light: NSColor, dark: NSColor) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
      }
    )
  }

  // MARK: - Surfaces

  /// Pair of radial-gradient stops for the tomato body, tinted per phase.
  /// Returns (bright, deep) where `bright` is the sun-lit upper-left and
  /// `deep` is the shaded edge.
  static func bodyStops(for phase: PomodoroTimer.Phase?) -> (bright: Color, deep: Color) {
    switch phase {
    case .focus, nil:
      return (
        bright: Color(red: 1.00, green: 0.55, blue: 0.28),
        deep: Color(red: 0.62, green: 0.10, blue: 0.08)
      )
    case .shortBreak:
      return (
        bright: Color(red: 0.62, green: 0.88, blue: 0.45),
        deep: Color(red: 0.22, green: 0.45, blue: 0.16)
      )
    case .longBreak:
      return (
        bright: Color(red: 0.45, green: 0.70, blue: 0.45),
        deep: Color(red: 0.16, green: 0.34, blue: 0.30)
      )
    }
  }

  /// Tomato-body stops for a "ripening" tomato: unripe green at 0, passing
  /// through orange around 0.5, to ripe red at 1. Used by the menu bar icon
  /// when the user hides the countdown — the tomato ripens as the session
  /// progresses.
  static func ripeStops(for ripeness: Double) -> (bright: Color, deep: Color) {
    let r = min(1, max(0, ripeness))
    // (r, g, b) channels for unripe -> mid -> ripe, bright and deep variants.
    let gB = (0.62, 0.88, 0.45)
    let gD = (0.30, 0.55, 0.18)
    let oB = (1.00, 0.70, 0.25)
    let oD = (0.90, 0.45, 0.12)
    let rB = (1.00, 0.55, 0.28)
    let rD = (0.62, 0.10, 0.08)

    let bright: (Double, Double, Double)
    let deep: (Double, Double, Double)
    if r < 0.5 {
      let t = r / 0.5
      bright = Self.lerpRGB(gB, oB, t)
      deep = Self.lerpRGB(gD, oD, t)
    } else {
      let t = (r - 0.5) / 0.5
      bright = Self.lerpRGB(oB, rB, t)
      deep = Self.lerpRGB(oD, rD, t)
    }
    return (
      bright: Color(red: bright.0, green: bright.1, blue: bright.2),
      deep: Color(red: deep.0, green: deep.1, blue: deep.2)
    )
  }

  private static func lerpRGB(
    _ a: (Double, Double, Double),
    _ b: (Double, Double, Double),
    _ t: Double
  ) -> (Double, Double, Double) {
    (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
  }

  /// Linear sRGB blend from `a` (fraction 0) to `b` (fraction 1). Stands in
  /// for `Color.mix(with:by:)`, which needs macOS 15 — the deployment target
  /// is macOS 14. Colors that can't be converted to sRGB (never the case for
  /// the literal palette colors this is used with) fall back to the nearer
  /// endpoint.
  static func mix(_ a: Color, _ b: Color, by fraction: Double) -> Color {
    let t = min(max(fraction, 0), 1)
    guard
      let ca = NSColor(a).usingColorSpace(.sRGB),
      let cb = NSColor(b).usingColorSpace(.sRGB)
    else {
      return t < 0.5 ? a : b
    }
    return Color(
      red: ca.redComponent + (cb.redComponent - ca.redComponent) * t,
      green: ca.greenComponent + (cb.greenComponent - ca.greenComponent) * t,
      blue: ca.blueComponent + (cb.blueComponent - ca.blueComponent) * t,
      opacity: ca.alphaComponent + (cb.alphaComponent - ca.alphaComponent) * t,
    )
  }
}

// MARK: - TomatoShape

/// A slightly-squashed circle with a gentle point at the bottom and a tiny
/// dimple at the top where the calyx sits. Elegant and symmetric, drawn with
/// beziers in the unit square then scaled to the given rect.
struct TomatoShape: Shape {

  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    let px: (CGFloat, CGFloat) -> CGPoint = { nx, ny in
      CGPoint(x: nx * w, y: ny * h)
    }

    var path = Path()
    // Left equator.
    path.move(to: px(0.0, 0.5))
    // Up the left side to the top dimple (top center dips slightly).
    path.addCurve(
      to: px(0.5, 0.07),
      control1: px(0.0, 0.10),
      control2: px(0.28, 0.0)
    )
    // Down the right side to the right equator.
    path.addCurve(
      to: px(1.0, 0.5),
      control1: px(0.72, 0.0),
      control2: px(1.0, 0.10)
    )
    // Down to the bottom point (extends just past the bottom for a gentle tip).
    path.addCurve(
      to: px(0.5, 1.0),
      control1: px(1.0, 0.92),
      control2: px(0.72, 1.03)
    )
    // Back up the left side to the start.
    path.addCurve(
      to: px(0.0, 0.5),
      control1: px(0.28, 1.03),
      control2: px(0.0, 0.92)
    )
    path.closeSubpath()
    return path
  }
}

// MARK: - TomatoCalyx

/// The green star of sepals sitting on top of the tomato. `leafCount` pointed
/// leaves radiate from a center point. At small sizes pass `3` to keep the
/// calyx legible (a fan of three leaves); at larger sizes pass `5` for the
/// classic five-sepal star.
struct TomatoCalyx: Shape {

  var leafCount: Int = 5

  func path(in rect: CGRect) -> Path {
    let size = min(rect.width, rect.height)
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let length = size * 0.5
    let baseRadius = size * 0.06
    let halfWidth = size * 0.13

    let angles: [Double]
    if leafCount <= 3 {
      // Fan pointing upward: up-left, up, up-right.
      angles = [-Double.pi / 2 - Double.pi / 4, -Double.pi / 2, -Double.pi / 2 + Double.pi / 4]
    } else {
      // Full five-point star centered on "up".
      let step = 2 * Double.pi / Double(leafCount)
      angles = (0..<leafCount).map { i in -Double.pi / 2 + Double(i) * step }
    }

    var path = Path()
    for angle in angles {
      path.addPath(
        Self.leafPath(
          center: center,
          angle: angle,
          length: length,
          baseRadius: baseRadius,
          halfWidth: halfWidth,
        )
      )
    }
    return path
  }

  /// A single pointed teardrop leaf radiating from `center` along `angle`.
  private static func leafPath(
    center: CGPoint,
    angle: Double,
    length: CGFloat,
    baseRadius: CGFloat,
    halfWidth: CGFloat,
  ) -> Path {
    let ux = CGFloat(cos(angle))
    let uy = CGFloat(sin(angle))
    let px = -uy // perpendicular unit
    let py = ux

    let tip = CGPoint(x: center.x + length * ux, y: center.y + length * uy)
    let baseMid = CGPoint(x: center.x + baseRadius * ux, y: center.y + baseRadius * uy)
    let basePlus = CGPoint(x: baseMid.x + halfWidth * px, y: baseMid.y + halfWidth * py)
    let baseMinus = CGPoint(x: baseMid.x - halfWidth * px, y: baseMid.y - halfWidth * py)

    // Bulge the sides outward to give the leaf volume; keep the tip sharp.
    let bulge = halfWidth * 0.65
    let cp1 = CGPoint(
      x: (basePlus.x + tip.x) / 2 + bulge * px,
      y: (basePlus.y + tip.y) / 2 + bulge * py,
    )
    let cp2 = CGPoint(
      x: (tip.x + baseMinus.x) / 2 - bulge * px,
      y: (tip.y + baseMinus.y) / 2 - bulge * py,
    )

    var path = Path()
    path.move(to: basePlus)
    path.addQuadCurve(to: tip, control: cp1)
    path.addQuadCurve(to: baseMinus, control: cp2)
    path.closeSubpath()
    return path
  }
}

// MARK: - TomatoGlyph

/// A composite tomato glyph: a lit tomato body (radially-shaded by default,
/// or a flat bright gradient for the menu bar), the green calyx on top, and a
/// soft specular highlight on the upper-left. Renders crisply from ~13pt
/// (menu bar) up to ~84pt (popover center).
///
/// - `phase`: tint the body for a given Pomodoro phase (default ripe red).
/// - `bodyOverride`: explicit body stops that take precedence over `phase` —
///   used by the menu bar icon for the ripening gradient and for blending
///   between phase palettes during the phase-change animation.
/// - `menuBarOptimized`: uses a brighter, higher-contrast body plus a thin dark
///   outline so the tomato reads on both light and dark menu bars.
struct TomatoGlyph: View {

  var size: CGFloat
  var phase: PomodoroTimer.Phase? = nil
  var bodyOverride: (bright: Color, deep: Color)? = nil
  var menuBarOptimized: Bool = false

  var body: some View {
    let stops: (bright: Color, deep: Color) =
      bodyOverride ?? Theme.bodyStops(for: phase)
    let calyxSize = size * 0.30
    let calyxLeafCount = size < 16 ? 3 : 5

    return ZStack {
      // Tomato body. Menu bar uses a flat bright gradient (higher contrast on
      // dark bars); the popover uses a soft radial shade for depth.
      TomatoShape()
        .fill(
          menuBarOptimized
            ? AnyShapeStyle(
              .linearGradient(
                Gradient(colors: [stops.bright, stops.deep]),
                startPoint: .top,
                endPoint: .bottom
              )
            )
            : AnyShapeStyle(
              .radialGradient(
                Gradient(colors: [stops.bright, stops.deep]),
                center: UnitPoint(x: 0.32, y: 0.28),
                startRadius: 0.0,
                endRadius: size * 0.72
              )
            )
        )

      // Calyx — green sepals sitting on top of the tomato, slightly raised.
      TomatoCalyx(leafCount: calyxLeafCount)
        .fill(Theme.leafGreen)
        .frame(width: calyxSize, height: calyxSize)
        .offset(y: -size * 0.34)
        .accessibilityHidden(true)

      // Soft specular highlight — a blurred white ellipse upper-left.
      Ellipse()
        .fill(Color.white.opacity(0.22))
        .frame(width: size * 0.24, height: size * 0.16)
        .blur(radius: size * 0.06)
        .offset(x: -size * 0.18, y: -size * 0.20)
        .accessibilityHidden(true)

      // Menu bar only: thin dark outline so the tomato is defined on light
      // bars (the bright body already carries it on dark bars).
      if menuBarOptimized {
        TomatoShape()
          .stroke(Color.black.opacity(0.35), lineWidth: max(0.6, size * 0.05))
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}