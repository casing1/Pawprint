#!/bin/bash
set -euo pipefail

# Builds the release app and packages it two ways:
#   Pawprint-<version>.dmg  — what a human downloads and drags to Applications
#   Pawprint-<version>.zip  — what the in-app updater downloads
#
# Both are needed. A DMG is the friendly format for a first install, but swapping a running app
# from one means attaching and detaching a disk image mid-update; a zip unpacks with `ditto` in
# one step and preserves the signature, so that is what the updater consumes.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Pawprint"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

if [ ! -d "$APP_BUNDLE" ] || [ "${1:-}" = "--build" ]; then
    "$ROOT_DIR/scripts/build_app.sh" release
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist")"
echo "==> Packaging $APP_NAME $VERSION ($BUILD_NUMBER)"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# --- zip (updater) ---
# `ditto -c -k --keepParent` is the archiver that round-trips a macOS bundle without mangling
# symlinks or extended attributes; a mangled bundle fails signature verification on the way back.
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
echo "==> $ZIP_PATH"

# --- dmg (humans) ---
STAGE="$DIST_DIR/.dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_BUNDLE" "$STAGE/"
# The Applications symlink is what makes "drag to install" obvious without a custom background.
ln -s /Applications "$STAGE/Applications"

DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null
rm -rf "$STAGE"
echo "==> $DMG_PATH"

# --- signature for the updater ---
# Signed only when the key is present, so a local `make_dmg.sh` run still works for testing.
if [ -n "${PAWPRINT_UPDATE_PRIVATE_KEY:-}" ]; then
    SIGNATURE="$(swift "$ROOT_DIR/scripts/updatekeys.swift" sign "$ZIP_PATH")"
    echo "$SIGNATURE" > "$DIST_DIR/$APP_NAME-$VERSION.zip.sig"
    echo "==> Signed update archive"
else
    SIGNATURE=""
    echo "==> No PAWPRINT_UPDATE_PRIVATE_KEY set — archive left unsigned (in-app update will refuse it)"
fi

# --- appcast entry ---
# Written here rather than in the workflow so a local run produces the same artifact set.
cat > "$DIST_DIR/appcast.json" <<JSON
{
  "version": "$VERSION",
  "build": "$BUILD_NUMBER",
  "downloadURL": "https://github.com/yhcho0405/Pawprint/releases/download/v$VERSION/$APP_NAME-$VERSION.zip",
  "signature": "$SIGNATURE",
  "minimumSystemVersion": "14.0"
}
JSON

echo "==> Done. Artifacts in $DIST_DIR"
ls -la "$DIST_DIR"
