#!/bin/bash
#
# Builds Hop in Release, quits the running Hop and installs the new build into /Applications,
# replacing the copy there, then reopens it. If the build fails, the running Hop is left alone.

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT=Hop.xcodeproj
SCHEME=Hop-macOS
DERIVED_DATA=build
LOG=$DERIVED_DATA/rebuild.log
APP=$DERIVED_DATA/Build/Products/Release/Hop.app
INSTALLED_APP=/Applications/Hop.app

fail() {
    echo "error: $1" >&2
    exit 1
}

mkdir -p "$DERIVED_DATA"

xcodegen generate

echo "Building Hop"
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    > "$LOG" 2>&1 \
    || fail "Building failed. See $LOG"

echo "Installing Hop in /Applications and reopening it"
pkill -x Hop || true
while pgrep -x Hop > /dev/null; do sleep 0.1; done
rm -rf "$INSTALLED_APP"
ditto "$APP" "$INSTALLED_APP"
open "$INSTALLED_APP"
