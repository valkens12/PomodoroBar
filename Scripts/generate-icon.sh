#!/bin/bash
# generate-icon.sh -- renders the tomato app icon and compiles it into
# Resources/AppIcon.icns. Run from the project root:
#   ./Scripts/generate-icon.sh
#
# This is a dev-time tool: re-run it whenever the icon design changes, then
# commit the regenerated Resources/AppIcon.icns. package.sh just copies the
# already-committed .icns into the bundle on every release build.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

MASTER_PNG="${WORK_DIR}/icon_1024.png"
ICONSET_DIR="${WORK_DIR}/AppIcon.iconset"
OUTPUT_ICNS="${PROJECT_ROOT}/Resources/AppIcon.icns"

echo "==> Rendering master icon..."
swift "${SCRIPT_DIR}/generate-icon.swift" "${MASTER_PNG}"

echo "==> Building iconset..."
mkdir -p "${ICONSET_DIR}"
sips -z 16 16     "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -z 32 32     "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -z 64 64     "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -z 256 256   "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -z 512 512   "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
cp "${MASTER_PNG}" "${ICONSET_DIR}/icon_512x512@2x.png"

echo "==> Compiling .icns..."
iconutil -c icns "${ICONSET_DIR}" -o "${OUTPUT_ICNS}"

echo "==> Done."
echo "${OUTPUT_ICNS}"
