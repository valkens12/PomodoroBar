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
BUNDLE_ID="com.pomodorobar.app"
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

echo "==> Assembling bundle at ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${RELEASE_BIN}" "${MACOS_DIR}/${APP_NAME}"
cp "${INFO_PLIST}" "${CONTENTS_DIR}/Info.plist"
cp "${APP_ICON}" "${RESOURCES_DIR}/AppIcon.icns"
chmod 755 "${MACOS_DIR}/${APP_NAME}"

echo "==> Code signing..."
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
codesign --force --deep --options runtime --timestamp=none \
  --sign "${CODESIGN_IDENTITY}" "${APP_DIR}"
codesign --verify --deep --strict "${APP_DIR}"

echo "==> Done."
echo "${APP_DIR}"