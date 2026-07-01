#!/usr/bin/env swift
//
// generate-icon.swift -- renders the PomodoroBar app icon (a tomato on a
// rounded-square card, matching the in-app TomatoGlyph/Theme palette) to a
// single 1024x1024 PNG. Run via Scripts/generate-icon.sh, which then slices
// the PNG into a full .iconset and compiles it to Resources/AppIcon.icns
// with `iconutil`.
//
// This duplicates a trimmed copy of Theme.swift's tomato geometry/palette
// rather than importing the PomodoroBar module, because this is a standalone
// script (not part of the SwiftPM target graph) used only at icon-design
// time -- it never ships and is not part of the app build.

import AppKit
import SwiftUI

// MARK: - Palette (mirrors Sources/PomodoroBar/Support/Theme.swift)

enum IconTheme {
  static let cream = Color(red: 0.99, green: 0.96, blue: 0.92)
  static let tomatoBlush = Color(red: 0.98, green: 0.93, blue: 0.91)
  static let leafGreen = Color(red: 0.45, green: 0.75, blue: 0.30)
  static let bodyBright = Color(red: 1.00, green: 0.55, blue: 0.28)
  static let bodyDeep = Color(red: 0.62, green: 0.10, blue: 0.08)
}

// MARK: - Shapes (mirrors TomatoShape / TomatoCalyx)

struct IconTomatoShape: Shape {
  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    let px: (CGFloat, CGFloat) -> CGPoint = { nx, ny in CGPoint(x: nx * w, y: ny * h) }

    var path = Path()
    path.move(to: px(0.0, 0.5))
    path.addCurve(to: px(0.5, 0.07), control1: px(0.0, 0.10), control2: px(0.28, 0.0))
    path.addCurve(to: px(1.0, 0.5), control1: px(0.72, 0.0), control2: px(1.0, 0.10))
    path.addCurve(to: px(0.5, 1.0), control1: px(1.0, 0.92), control2: px(0.72, 1.03))
    path.addCurve(to: px(0.0, 0.5), control1: px(0.28, 1.03), control2: px(0.0, 0.92))
    path.closeSubpath()
    return path
  }
}

struct IconTomatoCalyx: Shape {
  func path(in rect: CGRect) -> Path {
    let size = min(rect.width, rect.height)
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let length = size * 0.5
    let baseRadius = size * 0.06
    let halfWidth = size * 0.13
    let leafCount = 5
    let step = 2 * Double.pi / Double(leafCount)
    let angles = (0..<leafCount).map { i in -Double.pi / 2 + Double(i) * step }

    var path = Path()
    for angle in angles {
      let ux = CGFloat(cos(angle))
      let uy = CGFloat(sin(angle))
      let perpX = -uy
      let perpY = ux
      let tip = CGPoint(x: center.x + length * ux, y: center.y + length * uy)
      let baseMid = CGPoint(x: center.x + baseRadius * ux, y: center.y + baseRadius * uy)
      let basePlus = CGPoint(x: baseMid.x + halfWidth * perpX, y: baseMid.y + halfWidth * perpY)
      let baseMinus = CGPoint(x: baseMid.x - halfWidth * perpX, y: baseMid.y - halfWidth * perpY)
      let bulge = halfWidth * 0.65
      let cp1 = CGPoint(
        x: (basePlus.x + tip.x) / 2 + bulge * perpX,
        y: (basePlus.y + tip.y) / 2 + bulge * perpY,
      )
      let cp2 = CGPoint(
        x: (tip.x + baseMinus.x) / 2 - bulge * perpX,
        y: (tip.y + baseMinus.y) / 2 - bulge * perpY,
      )
      var leaf = Path()
      leaf.move(to: basePlus)
      leaf.addQuadCurve(to: tip, control: cp1)
      leaf.addQuadCurve(to: baseMinus, control: cp2)
      leaf.closeSubpath()
      path.addPath(leaf)
    }
    return path
  }
}

// MARK: - Icon composition

/// 1024x1024 canvas: a warm rounded-square card (matching the popover
/// gradient) with the tomato glyph centered at Apple's ~80% icon-content
/// scale, plus a soft drop shadow for depth against Finder/Spotlight.
struct AppIconView: View {
  let canvas: CGFloat = 1024
  var cardSize: CGFloat { canvas * 0.86 }
  var glyphSize: CGFloat { canvas * 0.56 }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: cardSize * 0.225, style: .continuous)
        .fill(
          LinearGradient(
            colors: [IconTheme.cream, IconTheme.tomatoBlush],
            startPoint: .top,
            endPoint: .bottom,
          )
        )
        .frame(width: cardSize, height: cardSize)

      ZStack {
        IconTomatoShape()
          .fill(
            .radialGradient(
              Gradient(colors: [IconTheme.bodyBright, IconTheme.bodyDeep]),
              center: UnitPoint(x: 0.32, y: 0.28),
              startRadius: 0,
              endRadius: glyphSize * 0.72,
            )
          )
          .shadow(color: .black.opacity(0.25), radius: canvas * 0.02, y: canvas * 0.012)

        IconTomatoCalyx()
          .fill(IconTheme.leafGreen)
          .frame(width: glyphSize * 0.30, height: glyphSize * 0.30)
          .offset(y: -glyphSize * 0.34)

        Ellipse()
          .fill(Color.white.opacity(0.25))
          .frame(width: glyphSize * 0.24, height: glyphSize * 0.16)
          .blur(radius: glyphSize * 0.06)
          .offset(x: -glyphSize * 0.18, y: -glyphSize * 0.20)
      }
      .frame(width: glyphSize, height: glyphSize)
    }
    .frame(width: canvas, height: canvas)
  }
}

// MARK: - Render to PNG

@MainActor
func renderIcon(to outputPath: String) {
  let renderer = ImageRenderer(content: AppIconView())
  renderer.scale = 1

  guard let cgImage = renderer.cgImage else {
    FileHandle.standardError.write(Data("error: failed to render icon\n".utf8))
    exit(1)
  }

  let bitmap = NSBitmapImageRep(cgImage: cgImage)
  guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("error: failed to encode PNG\n".utf8))
    exit(1)
  }

  do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(outputPath)")
  } catch {
    FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
    exit(1)
  }
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

// This script runs single-threaded on the main thread, so it's safe to
// assume MainActor isolation here without hopping through an async runloop.
MainActor.assumeIsolated {
  renderIcon(to: outputPath)
}
