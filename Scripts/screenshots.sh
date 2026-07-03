#!/bin/bash
# screenshots.sh -- capture PomodoroBar UI and composite it onto App-Store-
# sized 2880x1800 marketing screenshots. Run from the project root:
#   ./Scripts/screenshots.sh capture   # interactive: click each window/region
#   ./Scripts/screenshots.sh compose   # build final PNGs from captured raws
#   ./Scripts/screenshots.sh all       # capture, then compose
#
# Capture tips:
#   - Set a neutral desktop wallpaper and hide other menu-bar items first.
#   - In capture mode, click a window to grab it, or press Space to drag-select
#     a region (useful for the menu-bar strip + popover together).
#   - Raw captures are saved at native retina pixels. For the small popover,
#     set a higher SCALE below so it reads well on the 2880x1800 canvas.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${PROJECT_ROOT}/build/screenshots"
RAW_DIR="${OUT_DIR}/raw"
FINAL_DIR="${OUT_DIR}/final"

# ---- Brand palette (mirrors Sources/PomodoroBar/Support/Theme.swift) --------
TOMATO_RED="#D42924"
TOMATO_ORANGE="#F96B29"
TOP_LIGHT="#FBF1EC"
BOT_LIGHT="#F2DFD2"
TOP_DARK="#1F1714"
BOT_DARK="#120E0B"
MUTED_LIGHT="#6B5847"
MUTED_DARK="#BFAE9F"
THEME="${THEME:-light}"   # light | dark

# ---- Fonts ------------------------------------------------------------------
# ImageMagick on this machine has no fontconfig catalog, so we pass font file
# paths directly. SF Pro Rounded reads as a friendly display weight for
# headlines/wordmark; SF Pro (SFNS) is the clean system regular for body copy.
FONT_BOLD="/System/Library/Fonts/SFNSRounded.ttf"
FONT_REG="/System/Library/Fonts/SFNS.ttf"
for _f in "${FONT_BOLD}" "${FONT_REG}"; do
  [[ -f "${_f}" ]] || { echo "error: font not found: ${_f}" >&2; exit 1; }
done
unset _f

# ---- Shot list: name|headline|subheadline|raw file|scale --------------------
# Edit copy here. Scale multiplies the captured UI on the canvas (popover
# shots typically need ~1.8; full Settings windows are fine at 1.0).
SHOTS=(
  "menubar|A quiet Pomodoro timer in your menu bar.|No Dock icon. No extra window. Just a glance.|menubar.png|1.8"
  "focus|Focus mode pauses the timer for you.|Switch away from your chosen apps and it stops on its own.|focus.png|1.0"
  "safari|Only the sites you choose count as work.|Time on other Safari tabs doesn't tick.|safari.png|1.0"
  "stats|See how your focus adds up.|Today, this week, and this month at a glance.|stats.png|1.0"
  "shortcut|Start it without opening the menu.|A global shortcut and launch-at-login.|shortcut.png|1.0"
)

# ---- Helpers ----------------------------------------------------------------
resolve_colors() {
  if [[ "${THEME}" == "dark" ]]; then
    TOP="${TOP_DARK}"; BOT="${BOT_DARK}"; MUTED="${MUTED_DARK}"
  else
    TOP="${TOP_LIGHT}"; BOT="${BOT_LIGHT}"; MUTED="${MUTED_LIGHT}"
  fi
}

capture_shot() {
  local name="$1" raw="$2"
  local path="${RAW_DIR}/${raw}"
  echo "  Capture: ${name}  ->  ${path}"
  echo "  (Click the window, or press Space to drag a region. Esc to skip.)"
  if screencapture -o -x -W "${path}" 2>/dev/null; then
    echo "    saved."
  else
    echo "    skipped."
  fi
}

compose_shot() {
  local name="$1" headline="$2" sub="$3" raw="$4" scale="$5"
  local raw_path="${RAW_DIR}/${raw}"
  local out_path="${FINAL_DIR}/${name}.png"
  if [[ ! -f "${raw_path}" ]]; then
    echo "  skip ${name}: no raw at ${raw_path}" >&2
    return 0
  fi

  local ui="${OUT_DIR}/.ui.png" ui_shadow="${OUT_DIR}/.ui_shadow.png"
  local bg="${OUT_DIR}/.bg.png"

  # Trim transparent edges and scale the captured UI onto the canvas.
  # '2400x1180>' keeps it within the lower content area; -filter Lanczos
  # softens upscaling reasonably for the small popover.
  magick "${raw_path}" -trim +repage -filter Lanczos \
    -resize "2400x1180>" -resize "${scale}%" "${ui}"

  # Soft drop shadow so the UI lifts off the background.
  magick "${ui}" \
    \( +clone -background none -shadow 80x14+0+36 \) \
    +swap -background none -layers merge +repage "${ui_shadow}"

  # Background gradient + headline + subheadline.
  magick -size 2880x1800 "gradient:${TOP}-${BOT}" \
    -gravity northwest \
    -font "${FONT_BOLD}" -fill "${TOMATO_RED}" -pointsize 92 \
    -annotate +144+224 "${headline}" \
    -font "${FONT_REG}" -fill "${MUTED}" -pointsize 50 \
    -annotate +148+338 "${sub}" \
    "${bg}"

  # Composite UI (centered, nudged down) and add the wordmark.
  magick "${bg}" "${ui_shadow}" \
    -gravity center -geometry +0+96 -compose over -composite \
    -gravity southwest -font "${FONT_BOLD}" -fill "${TOMATO_RED}" -pointsize 46 \
    -annotate +144+84 "PomodoroBar" \
    "${out_path}"

  rm -f "${ui}" "${ui_shadow}" "${bg}"
  echo "  composed: ${out_path}"
}

# ---- Commands ---------------------------------------------------------------
cmd_capture() {
  mkdir -p "${RAW_DIR}"
  echo "==> Capturing raw UI into ${RAW_DIR}"
  for shot in "${SHOTS[@]}"; do
    IFS='|' read -r name headline sub raw scale <<< "${shot}"
    capture_shot "${name}" "${raw}"
  done
}

cmd_compose() {
  mkdir -p "${FINAL_DIR}"
  resolve_colors
  echo "==> Composing final screenshots (${THEME}) into ${FINAL_DIR}"
  for shot in "${SHOTS[@]}"; do
    IFS='|' read -r name headline sub raw scale <<< "${shot}"
    compose_shot "${name}" "${headline}" "${sub}" "${raw}" "${scale}"
  done
  echo "==> Done. Upload the PNGs in ${FINAL_DIR} to App Store Connect."
}

case "${1:-}" in
  capture) cmd_capture ;;
  compose) cmd_compose ;;
  all)     cmd_capture; cmd_compose ;;
  *) echo "usage: $0 {capture|compose|all}  [THEME=light|dark]"; exit 1 ;;
esac