#!/bin/bash
#
# Builds a signed and notarized Hop DMG for the Mac and adds it to the appcast.
# Everything it produces lands in releases/, and the new DMG and appcast are then
# uploaded to the updates bucket in Cloudflare R2.

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT=Hop.xcodeproj
SCHEME=Hop-macOS
TARGET=Hop-macOS
NOTARY_PROFILE=notary
BUCKET=apps
DERIVED_DATA=build
WORK=build/release
RELEASES=releases
GENERATE_APPCAST=$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast

fail() {
    echo "error: $1" >&2
    exit 1
}

setting() {
    printf '%s\n' "$SETTINGS" | awk -v key="$1" '$1 == key && $2 == "=" { print $3; exit }'
}

upload() {
    npx --yes wrangler r2 object put "$BUCKET/hop/$2" --file "$1" --remote "${@:3}"
}

[ -f Config/Release.xcconfig ] || fail "Config/Release.xcconfig is missing. Copy the example and fill it in."

IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n 1)
[ -n "$IDENTITY" ] || fail "No Developer ID Application certificate. Create one under Xcode > Settings > Accounts > Manage Certificates."

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "No working notarytool login. Run: xcrun notarytool store-credentials $NOTARY_PROFILE"

CLOUDFLARE_ACCOUNT=$(npx --yes wrangler whoami 2>&1 || true)
[[ $CLOUDFLARE_ACCOUNT == *"You are logged in"* ]] || fail "Wrangler is not logged in to Cloudflare. Run: npx wrangler login"

xcodegen generate

SETTINGS=$(xcodebuild -project "$PROJECT" -target "$TARGET" -configuration Release -showBuildSettings 2>/dev/null)
VERSION=$(setting MARKETING_VERSION)
BUILD=$(setting CURRENT_PROJECT_VERSION)
TEAM=$(setting DEVELOPMENT_TEAM)
UPDATES_HOST=$(setting HOP_UPDATES_HOST)

[ -n "$VERSION" ] && [ -n "$BUILD" ] || fail "Could not read the version and build number from the project."
[ -n "$TEAM" ] || fail "DEVELOPMENT_TEAM is not set in Config/Release.xcconfig."
[ -n "$UPDATES_HOST" ] || fail "HOP_UPDATES_HOST is not set in Config/Release.xcconfig."

mkdir -p "$RELEASES"

if [ -f "$RELEASES/appcast.xml" ]; then
    LATEST_BUILD=$(sed -n 's/.*<sparkle:version>\([0-9]*\)<.*/\1/p' "$RELEASES/appcast.xml" | sort -n | tail -n 1)
    if [ -n "$LATEST_BUILD" ] && [ "$BUILD" -le "$LATEST_BUILD" ]; then
        fail "Build $BUILD is not newer than released build $LATEST_BUILD. Raise CURRENT_PROJECT_VERSION in project.yml."
    fi
fi

rm -rf "$WORK"
mkdir -p "$WORK"

ARCHIVE=$WORK/Hop.xcarchive
EXPORT=$WORK/export
STAGE=$WORK/stage
APP=$EXPORT/Hop.app
DMG=$RELEASES/Hop-$VERSION.dmg

echo "Archiving Hop $VERSION ($BUILD)"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -archivePath "$ARCHIVE" \
    > "$WORK/archive.log" 2>&1 \
    || fail "Archiving failed. See $WORK/archive.log"

cat > "$WORK/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>Developer ID Application</string>
	<key>teamID</key>
	<string>$TEAM</string>
</dict>
</plist>
EOF

echo "Exporting with Developer ID"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT" \
    -exportOptionsPlist "$WORK/ExportOptions.plist" \
    > "$WORK/export.log" 2>&1 \
    || fail "Exporting failed. See $WORK/export.log"

codesign --verify --deep --strict "$APP"

echo "Building the DMG"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Hop.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -ov -volname Hop -srcfolder "$STAGE" -format UDZO "$DMG"
codesign --sign "$IDENTITY" --timestamp "$DMG"

echo "Notarizing, which usually takes a few minutes"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature "$DMG"

echo "Updating the appcast"
"$GENERATE_APPCAST" --download-url-prefix "https://$UPDATES_HOST/hop/" "$RELEASES"

echo "Uploading to the $BUCKET bucket"
upload "$DMG" "$(basename "$DMG")"
upload "$DMG" Hop.dmg --cache-control no-cache
upload "$RELEASES/appcast.xml" appcast.xml

echo "Released Hop $VERSION ($BUILD) to https://$UPDATES_HOST/hop/"
