#!/bin/bash
# Builds WindowSwitcher.app in this directory.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

app=WindowSwitcher.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/WindowSwitcher "$app/Contents/MacOS/"
cp Info.plist "$app/Contents/"
cp AppIcon.icns "$app/Contents/Resources/"
codesign --force --sign - "$app"
