# PomodoroBar

A native macOS menu bar Pomodoro timer with a refined tomato aesthetic, built with SwiftUI and the macOS 26 Liquid Glass design.

<!-- TODO: add screenshots of the menu bar popover, Focus Apps tab, and Statistics tab. -->

## Features

- **Tomato design** — a hand-drawn `TomatoGlyph` (squashed sphere + green calyx) sits inside the progress ring, tints itself per phase, and appears in the menu bar, popover, stat cards, and settings tabs. Focus = sun-ripened red/orange, short break = fresh leaf green, long break = deep vine green-teal.
- **Menu bar only** — lives in the status bar, no Dock icon (`LSUIElement`).
- **Focus / Short Break / Long Break** phases with a configurable long-break cadence.
- **Animated circular progress ring** tinted per phase, with a tomato at its center.
- **Focus Mode (anti-procrastination)** — opt to only count down while one of your chosen focus apps is frontmost. Open YouTube, Slack, or anything off-list and the tomato pauses itself; switch back to a focus app and it resumes. A small "Paused — open a focus app" banner appears in the popover while waiting.
- **Safari website restriction** — the Safari focus-app entry can optionally be limited to specific websites (e.g. `coursera.org`, subdomains included). While Safari is frontmost, the current tab is checked every couple of seconds via Apple Events; on an off-list site the timer holds and the popover shows a "Paused — wrong tab" banner with the current and allowed domains. Requires a one-time Automation permission grant (only works from the packaged `.app`); if the tab can't be verified for any reason, gating falls back to app-level only — it never blocks the timer.
- **Statistics** — every completed focus session is recorded. A dedicated Statistics window (opened from the popover, or by clicking the "Today" summary line) shows today's / this week's / this month's focus minutes and session counts, plus a 7-day bar chart and a 30-day trend (Swift Charts, tomato-tinted). Clear history anytime.
- **Session dots** showing how many focus sessions are completed before a long break.
- **Auto-start** of breaks and/or focus sessions, configurable per preference.
- **Sound cues** for phase changes and an optional subtle tick while running.
- **Settings window** with three tabs — General, Focus Apps, Statistics — all persisted across relaunches via `UserDefaults`.
- **Liquid Glass** appearance — built against the macOS 26 SDK, so the system automatically applies the latest material styling; `.glassEffect()` is used where appropriate.

## Build & Run

### Requirements

- macOS 26 SDK (Xcode targeting `.v26`)
- Swift 6 toolchain

### Development

From the project root:

```sh
swift run
```

This builds and launches the executable directly. The menu bar item appears immediately; no Dock icon is shown because the bundled `Info.plist` sets `LSUIElement = true`, and the SwiftPM run inherits the bundle settings when launched via `swift run` against the configured executable.

### Packaged .app

To produce a real, double-clickable `PomodoroBar.app` bundle:

```sh
./Scripts/package.sh
open /Users/Vale/Documents/PomodoroBar/build/PomodoroBar.app
```

The script:

1. Runs `swift build -c release`.
2. Creates `build/PomodoroBar.app/Contents/{MacOS,Resources}`.
3. Copies the release executable into `Contents/MacOS/`.
4. Copies `Resources/Info.plist` and `Resources/AppIcon.icns` into the bundle.
5. Marks the executable as runnable (`chmod 755`).
6. Ad-hoc code-signs the bundle (`codesign --options runtime`) so it launches
   cleanly on Apple Silicon and Gatekeeper doesn't flag it as damaged on this
   Mac. This is **not** notarization — distributing the `.app` to another
   machine still requires a paid Apple Developer ID and `notarytool`. To sign
   with a real identity instead of ad-hoc, set `CODESIGN_IDENTITY` before
   running the script.
7. Prints the final bundle path.

To regenerate the app icon after a design change, run `./Scripts/generate-icon.sh`
(renders the tomato to PNG and compiles `Resources/AppIcon.icns` via `iconutil`).

## Controls

| Action | Control |
| --- | --- |
| Start / Pause / Resume | Primary button in the popover (toggled label) |
| Reset | Secondary button — returns to idle at full duration for the current phase |
| Skip | Secondary button — advance to the next phase immediately |
| Open Settings | `SettingsLink` "Settings…" button at the bottom of the popover |
| Add / remove focus apps | Settings → Focus Apps tab (file picker, `.app`) |
| Restrict Safari to specific websites | Settings → Focus Apps tab → under the Safari entry, type a domain or click "Add Current Tab's Domain" |
| Clear statistics | Settings → Statistics tab → "Clear History" |
| Quit | "Quit" button at the bottom of the popover |

The menu bar label is compact: when running or paused it shows the remaining time in `mm:ss` with a phase-tinted tomato glyph; when idle it shows a single tomato glyph.

## Architecture

PomodoroBar is a single-target SwiftPM executable (`Sources/PomodoroBar/`) with no third-party dependencies — only SwiftUI, Combine, Foundation, AppKit (`NSSound`, `NSWorkspace`), and Swift Charts (`import Charts`, a system framework on macOS 26).

Key pieces:

- **`@Observable` models** (Swift 6 strict concurrency, `@MainActor`):
  - `AppSettings` — persisted user preferences (`UserDefaults`, clamped in `didSet`).
  - `PomodoroTimer` — phase + run-state, a Combine `Timer.publish` 1-second ticker (run-loop mode `.common` so it ticks while the menu is open), phase-advance logic with auto-start and sound playback, focus-gating (skips ticking while waiting for a focus app), and statistics recording on focus completion.
  - `FocusGuard` — the focus-app allowlist and frontmost-app monitor (`NSWorkspace` activation notifications), plus the Safari tab-domain restriction: while Safari is frontmost with domains configured, a polling task queries the current tab via `SafariTabQuery` and gates the countdown on a domain match, failing open whenever the tab can't be verified. Persisted to `UserDefaults`.
  - `StatisticsStore` — focus-session records persisted as JSON, with daily/weekly/monthly aggregates and 7/30-day bucketed series for the charts.
- **`MenuBarExtra` scene** with `.window` style hosts the popover; a separate `Settings` scene hosts the preferences window. Both receive all four models via `.environment(_:)`. The popover uses `SettingsLink` (not `openSettings()`) to launch the Settings scene reliably from an `LSUIElement` menu bar popover.
- **Views** are pure functions of the injected models:
  - `MenuContentView` — the popover (phase label, `CircularProgressView` with overlaid time, waiting banner, session dots, action buttons, Settings/Quit row).
  - `CircularProgressView` — a trimmed `Circle` stroked with a per-phase gradient, with a `TomatoGlyph` at the center.
  - `TimerMenuBarLabel` — the compact status bar item.
  - `SettingsView` — a three-tab `TabView`: `GeneralTab`, `FocusAppsTab` (file importer for `.app` bundles + live app icons), `StatisticsTab` (stat cards + Swift Charts 7-day bar chart and 30-day area chart).
- **Support**:
  - `Theme` — the tomato palette, per-phase gradients/colors, `TomatoShape`, `TomatoCalyx`, `TomatoGlyph`, and card/popover backgrounds.
  - `SoundManager` — `NSSound` phase-change and tick playback.
  - `SafariTabQuery` — queries Safari's frontmost tab URL by running `osascript` in a subprocess (with a hard timeout and cancellation-driven termination) so a slow Apple Event round-trip never blocks the app.
- **Packaging**: `Resources/Info.plist` declares the bundle (`LSUIElement = true` for menu-bar-only behavior); `Scripts/package.sh` assembles the `.app` bundle from the release build.

The app targets **macOS 26** (deployment `.v26`), adopts the Liquid Glass design automatically by building against the macOS 26 SDK, and uses **Swift Charts** for the statistics visualizations.