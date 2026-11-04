#!/bin/bash
#
# Builds Hop in Release and restarts it from the new build, to try a change right away.
# If the build fails, the running Hop is left alone.

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT=Hop.xcodeproj
SCHEME=Hop-macOS
DERIVED_DATA=build
LOG=$DERIVED_DATA/rebuild.log
APP=$DERIVED_DATA/Build/Products/Release/Hop.app

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

echo "Restarting Hop"
pkill -x Hop || true
while pgrep -x Hop > /dev/null; do sleep 0.1; done
open "$APP"
