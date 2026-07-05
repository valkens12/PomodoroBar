#!/bin/bash
# package.sh -- build PomodoroBar in release mode and bundle it into a
# menu-bar-only .app package. Run from the project root:
#   ./Scripts/package.sh

set -euo pipefail

# Resolve project root from the script location so it can be invoked
# from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="PomodoroBar"
BUNDLE_ID="com.archiet4.pomodorobar"
BUILD_DIR="${PROJECT_ROOT}/build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building ${APP_NAME} (release)..."
cd "${PROJECT_ROOT}"
swift build -c release

RELEASE_BIN="${PROJECT_ROOT}/.build/release/${APP_NAME}"
INFO_PLIST="${PROJECT_ROOT}/Resources/Info.plist"
APP_ICON="${PROJECT_ROOT}/Resources/AppIcon.icns"
ALARM_SOUND="${PROJECT_ROOT}/Resources/harp_alarm.wav"

if [[ ! -f "${RELEASE_BIN}" ]]; then
  echo "error: release executable not found at ${RELEASE_BIN}" >&2
  exit 1
fi
if [[ ! -f "${INFO_PLIST}" ]]; then
  echo "error: Info.plist not found at ${INFO_PLIST}" >&2
  exit 1
fi
if [[ ! -f "${APP_ICON}" ]]; then
  echo "error: AppIcon.icns not found at ${APP_ICON} (run ./Scripts/generate-icon.sh)" >&2
  exit 1
fi
if [[ ! -f "${ALARM_SOUND}" ]]; then
  echo "error: harp_alarm.wav not found at ${ALARM_SOUND}" >&2
  exit 1
fi

echo "==> Assembling bundle at ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${RELEASE_BIN}" "${MACOS_DIR}/${APP_NAME}"
cp "${INFO_PLIST}" "${CONTENTS_DIR}/Info.plist"
cp "${APP_ICON}" "${RESOURCES_DIR}/AppIcon.icns"
cp "${ALARM_SOUND}" "${RESOURCES_DIR}/harp_alarm.wav"
chmod 755 "${MACOS_DIR}/${APP_NAME}"

echo "==> Compiling asset catalog..."
# The Xcode target compiles Resources/Assets.xcassets into Assets.car, which
# is where Image("KoFiBadge") looks at runtime. swift build does not, so
# compile it here or in-app images render as empty space.
xcrun actool "${PROJECT_ROOT}/Resources/Assets.xcassets" \
  --compile "${RESOURCES_DIR}" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --output-format human-readable-text > /dev/null

if [[ ! -f "${RESOURCES_DIR}/Assets.car" ]]; then
  echo "error: actool did not produce Assets.car" >&2
  exit 1
fi

echo "==> Copying localized resources..."
# Ship any *.lproj directories from Resources/ into the bundle so the app
# carries its translated strings (Localizable.strings, InfoPlist.strings).
shopt -s nullglob
for lproj in "${PROJECT_ROOT}/Resources"/*.lproj; do
  cp -R "${lproj}" "${RESOURCES_DIR}/"
done
shopt -u nullglob

echo "==> Code signing..."
# The direct build must carry the automation.apple-events entitlement: with the
# hardened runtime enabled (--options runtime), in-process Apple Events to
# Safari are blocked without it. No sandbox here — that is the App Store build.
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
ENTITLEMENTS="${PROJECT_ROOT}/PomodoroBar-Direct.entitlements"
codesign --force --deep --options runtime --timestamp=none \
  --entitlements "${ENTITLEMENTS}" \
  --sign "${CODESIGN_IDENTITY}" "${APP_DIR}"
codesign --verify --deep --strict "${APP_DIR}"

echo "==> Done."
echo "${APP_DIR}"