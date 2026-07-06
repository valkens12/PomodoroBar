import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Rendering the Focus Card into a PNG can fail at two points; each gets
/// its own case so a failure in the share sheet is at least diagnosable.
enum FocusShareCardRenderError: Error {
  /// `ImageRenderer` produced no image for the card view.
  case imageUnavailable
  /// The rendered bitmap could not be encoded as PNG.
  case pngEncodingFailed
}

/// `Transferable` payload behind the Statistics window's ShareLink: the
/// derived `FocusShareCardData` in, a 1080 x 1920 PNG out. Rendering happens
/// lazily inside the transfer representation — the card is only rasterized
/// when the user actually picks a share destination, not on every body
/// evaluation of the Statistics view.
struct FocusShareCardExport: Transferable, Sendable {
  let data: FocusShareCardData
  let style: FocusShareCardStyle

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .png) { export in
      // ImageRenderer is main-actor bound; the export closure is not.
      try await MainActor.run { try export.renderPNGData() }
    }
    .suggestedFileName("PomodoroBar Focus Card.png")
  }

  @MainActor
  func renderPNGData() throws -> Data {
    let renderer = ImageRenderer(content: FocusShareCardView(data: data, style: style))
    renderer.scale = FocusShareCardView.exportScale
    renderer.isOpaque = true
    guard let cgImage = renderer.cgImage else {
      throw FocusShareCardRenderError.imageUnavailable
    }
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
      throw FocusShareCardRenderError.pngEncodingFailed
    }
    return png
  }
}
