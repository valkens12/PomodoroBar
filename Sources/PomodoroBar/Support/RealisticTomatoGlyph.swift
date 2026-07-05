import SwiftUI

/// The popover's centered tomato, given real body instead of a flat
/// two-tone fill: a four-stop radial shade, faint skin striations and
/// grain, ambient occlusion, a corner rim light, static glossy specular
/// highlights, and a calyx that casts its own soft shadow onto the body
/// below. Reserved for the popover ring, where there's room for the extra
/// layers — the menu bar and stat cards keep the flatter, cheaper
/// `TomatoGlyph`.
///
/// Every layer is drawn statically. The glyph must not run any continuous
/// (`repeatForever`) animation: it lives inside the `MenuBarExtra` `.window`
/// popover, and a never-settling animation makes the AppKit-hosted popover
/// recompute its anchor every frame, so the whole popover visibly jitters
/// around the menu bar. Discrete, settling animations (the start pop) are
/// fine and are driven by the parent, not here.
struct RealisticTomatoGlyph: View {

  var size: CGFloat
  var phase: PomodoroTimer.Phase

  private var calyxSize: CGFloat { size * 0.30 }
  private var calyxLeafCount: Int { size < 16 ? 3 : 5 }

  var body: some View {
    ZStack {
      contactShadow
      shadedBody
      skinDetail
      ambientOcclusion
      subsurfaceHighlight
      specularHighlights
      calyxGroup
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }

  // MARK: - Body

  private var contactShadow: some View {
    Ellipse()
      .fill(Color.black.opacity(0.32))
      .frame(width: size * 0.62, height: size * 0.10)
      .blur(radius: size * 0.05)
      .offset(y: size * 0.52)
  }

  private var shadedBody: some View {
    TomatoShape()
      .fill(
        .radialGradient(
          Gradient(colors: Theme.realisticBodyStops(for: phase)),
          center: UnitPoint(x: 0.32, y: 0.28),
          startRadius: 0,
          endRadius: size * 0.75
        )
      )
  }

  // MARK: - Surface detail

  /// Fine skin grain, multiplied over the body so it reads as texture rather
  /// than paint.
  private var skinDetail: some View {
    TomatoGrain()
      .clipShape(TomatoShape())
      .blendMode(.multiply)
      .opacity(0.55)
  }

  /// A downward shade plus a soft shadow under the calyx, so the top dimple
  /// reads as recessed.
  private var ambientOcclusion: some View {
    ZStack {
      TomatoShape()
        .fill(
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .clear, location: 0.62),
              .init(color: .black.opacity(0.42), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
      Ellipse()
        .fill(Color.black.opacity(0.20))
        .frame(width: size * 0.36, height: size * 0.19)
        .blur(radius: size * 0.04)
        .offset(y: -size * 0.24)
    }
    .clipShape(TomatoShape())
    .compositingGroup()
    .blendMode(.multiply)
  }

  /// Small bright curl near the bottom-center — a stand-in for the
  /// subsurface scatter you get on real translucent fruit, where light
  /// passing through the skin reads back as a soft warm glow. Screen-blended
  /// so it brightens whatever sits under it (the deep AO at the bottom) and
  /// sits between the AO pass and the specular highlights in the z-order.
  private var subsurfaceHighlight: some View {
    Ellipse()
      .fill(Theme.realisticBodyStops(for: phase)[0].opacity(0.40))
      .frame(width: size * 0.30, height: size * 0.10)
      .blur(radius: size * 0.05)
      .offset(y: size * 0.30)
      .clipShape(TomatoShape())
      .blendMode(.screen)
  }

  /// Broad soft highlight plus a sharper glassy fleck and spark — a fixed,
  /// glossy specular. Deliberately static (see the type doc): no shimmer, so
  /// the popover never repositions.
  private var specularHighlights: some View {
    ZStack {
      Ellipse()
        .fill(Color.white.opacity(0.30))
        .frame(width: size * 0.32, height: size * 0.21)
        .blur(radius: size * 0.07)
        .offset(x: -size * 0.19, y: -size * 0.17)

      Ellipse()
        .fill(Color.white.opacity(0.72))
        .frame(width: size * 0.11, height: size * 0.074)
        .blur(radius: size * 0.013)
        .offset(x: -size * 0.21, y: -size * 0.24)

      Circle()
        .fill(Color.white.opacity(0.40))
        .frame(width: size * 0.036, height: size * 0.036)
        .blur(radius: size * 0.013)
        .offset(x: -size * 0.27, y: -size * 0.18)
    }
    .accessibilityHidden(true)
  }

  // MARK: - Calyx

  private var calyxGroup: some View {
    ZStack {
      TomatoCalyx(leafCount: calyxLeafCount)
        .fill(
          LinearGradient(
            colors: [Theme.leafGreen, Color(red: 0.24, green: 0.42, blue: 0.16)],
            startPoint: .bottom,
            endPoint: .top
          )
        )
        .frame(width: calyxSize, height: calyxSize)
        .shadow(color: .black.opacity(0.40), radius: size * 0.025, x: 0, y: size * 0.02)

      // The stem scar: a dark brown knob peeking through where the leaves
      // meet, with a tiny warm highlight so it reads as a 3D bump rather
      // than a flat dot.
      ZStack {
        Circle()
          .fill(Color(red: 0.20, green: 0.13, blue: 0.06))
          .frame(width: size * 0.05, height: size * 0.05)
        Circle()
          .fill(Color(red: 0.42, green: 0.29, blue: 0.16).opacity(0.80))
          .frame(width: size * 0.014, height: size * 0.014)
          .offset(x: -size * 0.008, y: -size * 0.008)
      }
    }
    .offset(y: -size * 0.34)
    .accessibilityHidden(true)
  }
}

// MARK: - TomatoGrain

/// Fine skin-texture grain: a fixed field of tiny low-opacity specks, standing
/// in for the noise a raster renderer would use. Positions are hashed from
/// the index so the field is deterministic — the same speckles every launch —
/// without needing a stored texture asset.
private struct TomatoGrain: View {

  private static let speckleCount = 160

  var body: some View {
    Canvas { context, size in
      for i in 0..<Self.speckleCount {
        let x = Self.hash(Double(i) * 12.9898) * size.width
        let y = Self.hash(Double(i) * 78.233) * size.height
        let radius = size.width * 0.006
        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        context.opacity = 0.10 + Self.hash(Double(i) * 37.719) * 0.10
        context.fill(Path(ellipseIn: rect), with: .color(.black))
      }
    }
  }

  /// A cheap deterministic hash to `[0, 1)` — the classic sine-based noise
  /// trick, chosen over a seeded RNG so this needs no extra state.
  private static func hash(_ seed: Double) -> Double {
    let x = sin(seed) * 43758.5453
    return x - x.rounded(.down)
  }
}
