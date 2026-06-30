import SwiftUI

/// Named fixed-size text styles for the popover and menu bar.
///
/// These two surfaces are small, fixed-width layouts (a 270pt popover, a
/// status-bar item) where Dynamic Type reflow isn't practical, so they use
/// literal point sizes rather than Apple's semantic text styles. Settings and
/// Statistics, by contrast, are a real resizable window and already use
/// semantic styles (`.body`, `.headline`, etc.) directly — those scale with
/// the user's preferred text size and don't need an entry here.
///
/// Centralizing the fixed sizes in one place means every label in the
/// popover/menu bar draws from the same small scale instead of each call
/// site picking its own point size independently.
enum Typography {
  /// The mm:ss countdown inside the progress ring.
  static let countdownDisplay = Font.system(size: 30, weight: .semibold, design: .rounded)

  /// Phase name in the popover header ("Focus", "Short Break"...).
  static let phaseTitle = Font.system(size: 15, weight: .semibold, design: .rounded)

  /// Phase glyph next to `phaseTitle` — matched weight, one point larger to
  /// balance the icon against the text baseline.
  static let phaseIcon = Font.system(size: 16, weight: .semibold, design: .rounded)

  /// "READY" / "RUNNING" / "PAUSED" caption under the countdown.
  static let stateCaption = Font.system(size: 11, weight: .medium, design: .rounded)

  /// Waiting-banner primary line ("Paused — open a focus app").
  static let bannerTitle = Font.system(size: 12, weight: .medium, design: .rounded)

  /// Waiting-banner leading glyph.
  static let bannerIcon = Font.system(size: 10, weight: .semibold, design: .rounded)

  /// Waiting-banner secondary line ("Current: <app name>").
  static let bannerDetail = Font.system(size: 10, weight: .regular, design: .rounded)

  /// The bottom Settings…/Quit row.
  static let compactLabel = Font.system(size: 12, weight: .regular, design: .rounded)

  /// The countdown shown in the menu bar status item itself.
  static let menuBarCountdown = Font.system(size: 12, weight: .semibold, design: .rounded)
}
