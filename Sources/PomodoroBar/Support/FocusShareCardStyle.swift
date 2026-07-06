import SwiftUI

/// Visual variants of the shareable Focus Card. Same data, same layout —
/// each style swaps the full color palette, so the picker sheet can cycle
/// through genuinely different-looking cards without three view
/// implementations drifting apart.
///
/// Raw values are persisted (`AppSettings.shareCardStyle`), so renaming a
/// case is a migration, not a refactor.
enum FocusShareCardStyle: String, CaseIterable, Identifiable, Sendable {
  /// The original: near-black warm dark with a tomato glow.
  case ember
  /// Warm cream paper with dark text, for feeds where dark cards drown.
  case harvest
  /// Deep vine green-teal dark with leaf-green accents.
  case midnight

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .ember:
      return String(localized: "share.style.ember", defaultValue: "Ember")
    case .harvest:
      return String(localized: "share.style.harvest", defaultValue: "Harvest")
    case .midnight:
      return String(localized: "share.style.midnight", defaultValue: "Midnight")
    }
  }

  /// Every color the card view needs, resolved per style. All values are
  /// explicit (no dynamic appearance colors): an exported image has no
  /// system appearance to adapt to.
  struct Palette {
    let backgroundTop: Color
    let backgroundBottom: Color
    /// Radial glow behind the bloom.
    let glow: Color
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    /// The uppercase kicker line above the persona title.
    let kicker: Color
    /// Marks for hours/days with no focus (bloom nubs, trend-strip bars).
    let emptyMark: Color
    let badgeBackground: Color
    /// Text tint of the week-over-week badge when the delta is positive
    /// (negative deltas use `secondaryText` — factual, not scolding red).
    let positiveDelta: Color
  }

  var palette: Palette {
    switch self {
    case .ember:
      return Palette(
        backgroundTop: Color(red: 0.12, green: 0.075, blue: 0.07),
        backgroundBottom: Color(red: 0.045, green: 0.03, blue: 0.04),
        glow: Theme.tomatoRed.opacity(0.22),
        primaryText: .white,
        secondaryText: .white.opacity(0.65),
        tertiaryText: .white.opacity(0.45),
        kicker: Theme.tomatoOrange,
        emptyMark: .white.opacity(0.13),
        badgeBackground: .white.opacity(0.07),
        positiveDelta: Theme.leafGreen,
      )
    case .harvest:
      return Palette(
        backgroundTop: Color(red: 0.985, green: 0.945, blue: 0.895),
        backgroundBottom: Color(red: 0.945, green: 0.875, blue: 0.805),
        glow: Theme.tomatoOrange.opacity(0.16),
        primaryText: Color(red: 0.22, green: 0.11, blue: 0.09),
        secondaryText: Color(red: 0.22, green: 0.11, blue: 0.09).opacity(0.7),
        tertiaryText: Color(red: 0.22, green: 0.11, blue: 0.09).opacity(0.5),
        kicker: Theme.tomatoRed,
        emptyMark: .black.opacity(0.10),
        badgeBackground: .black.opacity(0.06),
        positiveDelta: Theme.vineGreen,
      )
    case .midnight:
      return Palette(
        backgroundTop: Color(red: 0.04, green: 0.085, blue: 0.09),
        backgroundBottom: Color(red: 0.012, green: 0.03, blue: 0.045),
        glow: Theme.vineGreen.opacity(0.26),
        primaryText: .white,
        secondaryText: .white.opacity(0.65),
        tertiaryText: .white.opacity(0.45),
        kicker: Theme.leafGreen,
        emptyMark: .white.opacity(0.13),
        badgeBackground: .white.opacity(0.07),
        positiveDelta: Theme.leafGreen,
      )
    }
  }
}
