#!/bin/bash
# Builds Hop.app in this directory.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

app=Hop.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Hop "$app/Contents/MacOS/"
cp Info.plist "$app/Contents/"
cp AppIcon.icns "$app/Contents/Resources/"
codesign --force --sign - "$app"
