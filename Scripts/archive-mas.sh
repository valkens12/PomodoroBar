#!/bin/bash
# archive-mas.sh -- build a Mac App Store archive of PomodoroBar with the
# signing team injected from the environment, so no identity is ever written
# into tracked project files. Run:
#
#   DEVELOPMENT_TEAM=ABCDE12345 ./Scripts/archive-mas.sh
#
# Requires an active paid Apple Developer account, an "Apple Distribution"
# certificate in your keychain, and (with Automatic signing) network access so
# Xcode can fetch a matching App Store provisioning profile. The App Store build
# is the ONLY channel that carries your identity -- it uses the sandboxed
# PomodoroBar-MAS.entitlements. The Homebrew build stays ad-hoc and anonymous
# (Scripts/package.sh).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
  echo "error: DEVELOPMENT_TEAM is not set." >&2
  echo "       Run: DEVELOPMENT_TEAM=<your 10-char Team ID> ./Scripts/archive-mas.sh" >&2
  exit 1
fi

ARCHIVE_PATH="${PROJECT_ROOT}/build/PomodoroBar-MAS.xcarchive"

echo "==> Regenerating Xcode project from project.yml (clean, team-less)..."
xcodegen generate

echo "==> Archiving Release-MAS (team injected in-memory, not persisted)..."
xcodebuild -project PomodoroBar.xcodeproj \
  -scheme PomodoroBar \
  -configuration Release-MAS \
  -archivePath "${ARCHIVE_PATH}" \
  archive \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
  CODE_SIGN_STYLE=Automatic

echo
echo "==> Archived: ${ARCHIVE_PATH}"
echo "Next: distribute to App Store Connect either by opening the archive in"
echo "Xcode's Organizer (Distribute App -> App Store Connect), or with"
echo "xcodebuild -exportArchive and an ExportOptions.plist you keep locally."
