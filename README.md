# PomodoroBar

> A quiet Pomodoro timer that lives in your menu bar. Native macOS app, no Dock icon, no extra window — just a glance.

Built with SwiftUI on the macOS 26 SDK with the Liquid Glass look. Single-target SwiftPM executable, zero third-party dependencies.

## Features

- **Menu bar only** — runs entirely in the status bar (`LSUIElement`), no Dock icon.
- **Work / short break / long break** phases with a configurable long-break cadence.
- **Focus Mode** — the timer only counts down while one of your chosen apps is frontmost. Switch to anything off-list and it pauses itself; switch back and it resumes.
- **Safari website restriction** — limit the Safari focus-app entry to specific domains, so only chosen tabs count as work (others hold the timer with a "wrong tab" banner).
- **Statistics** — daily / weekly / monthly focus time and session counts, plus a 7-day bar chart and 30-day trend (Swift Charts).
- **Global hotkey** — optional system-wide start/pause shortcut (default ⌃⌥P, recordable).
- **Launch at login**, sound cues, actionable end-of-phase notifications, and a sleep-aware wall-clock timer that resumes on wake.
- **Per-phase tomato glyph** in the progress ring — sun-ripened red/orange for focus, fresh leaf green for short breaks, deep vine green-teal for long breaks.

## Requirements

- macOS 26
- Swift 6 toolchain (Xcode targeting the macOS 26 SDK)

## Build & Run

```sh
swift run
```

The menu bar item appears immediately. No Dock icon is shown because the bundled `Info.plist` sets `LSUIElement = true`.

## Package as a `.app`

```sh
./Scripts/package.sh
open build/PomodoroBar.app
```

`package.sh` builds in release mode, assembles the `.app` bundle, and ad-hoc code-signs it so it launches cleanly on Apple Silicon. This is **not** notarization — distributing the `.app` to other machines still requires a paid Apple Developer ID and `notarytool`. To sign with a real identity, set `CODESIGN_IDENTITY` before running the script.

To regenerate the app icon after a design change, run `./Scripts/generate-icon.sh`.

## Controls

| Action | How |
| --- | --- |
| Start / Pause / Resume | Primary button in the popover |
| Reset | Secondary button — back to idle at full duration |
| Skip | Secondary button — advance to the next phase |
| Open Settings | "Settings…" button at the bottom of the popover |
| Add / remove focus apps | Settings → Focus Apps |
| Restrict Safari to specific sites | Settings → Focus Apps → under the Safari entry |
| Clear statistics | Settings → Statistics → "Clear History" |
| Quit | "Quit" button at the bottom of the popover |

## Architecture

A single-target SwiftPM executable under `Sources/PomodoroBar/`, using only SwiftUI, Foundation, AppKit, and Swift Charts.

- **`@Observable` models** (Swift 6 strict concurrency, `@MainActor`):
  - `AppSettings` — persisted user preferences (`UserDefaults`).
  - `PomodoroTimer` — phase + run-state, the 1-second ticker, phase-advance logic, auto-start, and focus gating.
  - `FocusGuard` — the focus-app allowlist, frontmost-app monitor, and Safari tab-domain restriction.
  - `StatisticsStore` — focus-session records persisted as JSON, with daily/weekly/monthly aggregates and chart series.
- **`MenuBarExtra`** scene hosts the popover; a separate `Settings` scene hosts preferences. Both receive all models via `.environment(_:)`.
- **Views** are pure functions of the injected models: `MenuContentView` (popover), `CircularProgressView` (progress ring + tomato), `TimerMenuBarLabel` (status bar item), and `SettingsView` (General / Focus Apps / Statistics tabs).
- **Support**: `Theme` (tomato palette + `TomatoGlyph`), `SoundManager` (`NSSound` cues), `SafariTabQuery` (subprocess `osascript` with a hard timeout so a slow Apple Event never blocks the app).

## Privacy

Everything stays on your Mac. PomodoroBar has no account and sends nothing anywhere. The only thing it ever reads is the address of your active Safari tab — and only when you've turned on Safari focus domains — so it can tell whether the current tab counts as work. That address is used for that one check and is never stored or sent anywhere.