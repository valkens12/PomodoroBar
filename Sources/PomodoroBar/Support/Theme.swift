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

  /// Warm cream — the top of the popover gradient.
  static let cream: Color = Color(red: 0.99, green: 0.96, blue: 0.92)

  /// Soft tomato blush — cards and the bottom of the popover gradient.
  static let tomatoBlush: Color = Color(red: 0.98, green: 0.93, blue: 0.91)

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

  /// The primary accent color for the given phase, used for labels, buttons,
  /// and the status bar indicator dot.
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

  // MARK: - Surfaces

  /// Soft tomato-blush card background with a faint vine-green separator tone.
  static let cardBackground: Color = tomatoBlush

  /// Vertical popover gradient: warm cream at the top fading to soft tomato
  /// blush at the bottom.
  static func popoverGradient() -> LinearGradient {
    LinearGradient(
      colors: [cream, tomatoBlush],
      startPoint: .top,
      endPoint: .bottom,
    )
  }

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
/// - `ripeness`: when set (0...1), overrides `phase` with a green->red ripening
///   gradient — used by the menu bar icon when the countdown is hidden.
/// - `menuBarOptimized`: uses a brighter, higher-contrast body plus a thin dark
///   outline so the tomato reads on both light and dark menu bars.
struct TomatoGlyph: View {

  var size: CGFloat
  var phase: PomodoroTimer.Phase? = nil
  var ripeness: Double? = nil
  var menuBarOptimized: Bool = false

  var body: some View {
    let stops: (bright: Color, deep: Color) = {
      if let ripeness {
        return Theme.ripeStops(for: ripeness)
      }
      return Theme.bodyStops(for: phase)
    }()
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