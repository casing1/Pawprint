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

RESTYLE=0
BUILD=0
for arg in "$@"; do
    case "$arg" in
        --build) BUILD=1 ;;
        # Regenerates the committed Finder layout template. Needs a real login session.
        --restyle) RESTYLE=1; BUILD=1 ;;
    esac
done

if [ ! -d "$APP_BUNDLE" ] || [ "$BUILD" = "1" ]; then
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
# The window layout — size, icon positions, background image — lives in the volume's .DS_Store.
# Producing one requires scripting the Finder, which needs a real login session and therefore
# does not work on a CI runner. So the layout is generated once with `--restyle` and committed
# as a template; normal builds just copy it in. The volume name is fixed (not per-version)
# because the template is tied to the volume it was made on.
STAGE="$DIST_DIR/.dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/.background"
cp -R "$APP_BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT_DIR/Assets/dmg-background.png" "$STAGE/.background/background.png"

VOLUME_NAME="$APP_NAME"
MOUNT_DIR="/Volumes/$VOLUME_NAME"
RW_DMG="$DIST_DIR/.rw.dmg"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
DS_TEMPLATE="$ROOT_DIR/Assets/dmg-DS_Store"
rm -f "$RW_DMG" "$DMG_PATH"

if [ "$RESTYLE" = "1" ]; then
    echo "==> Restyling: scripting the Finder to regenerate $DS_TEMPLATE"
    hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGE" -ov -format UDRW -fs HFS+ "$RW_DMG" >/dev/null
    # Not -nobrowse: the Finder has to see the volume to write its .DS_Store.
    hdiutil attach "$RW_DMG" -noautoopen >/dev/null
    for _ in $(seq 1 20); do [ -d "$MOUNT_DIR" ] && break; sleep 0.5; done

    osascript <<APPLESCRIPT >/dev/null || { echo "!! Finder layout failed"; exit 1; }
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 140, 800, 540}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        -- Relative to the disk, not a POSIX path: an absolute alias points at the temporary
        -- writable image and dangles once the released copy is mounted.
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {150, 170}
        set position of item "Applications" of container window to {450, 170}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

    sync
    for _ in $(seq 1 15); do hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 && break; sleep 1; done
    hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true

    # Read the styled .DS_Store back out and keep it as the template.
    hdiutil attach "$RW_DMG" -readonly -nobrowse -noautoopen >/dev/null
    for _ in $(seq 1 20); do [ -f "$MOUNT_DIR/.DS_Store" ] && break; sleep 0.5; done
    cp "$MOUNT_DIR/.DS_Store" "$DS_TEMPLATE"
    hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
    echo "==> Saved $DS_TEMPLATE"
elif [ -f "$DS_TEMPLATE" ]; then
    cp "$DS_TEMPLATE" "$STAGE/.DS_Store"
else
    echo "==> No $DS_TEMPLATE — the DMG will be unstyled. Run: ./scripts/make_dmg.sh --restyle"
fi

hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGE" \
    -ov -format UDRW -fs HFS+ "$RW_DMG" >/dev/null
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG"
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
