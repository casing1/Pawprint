#!/bin/bash
set -euo pipefail

# Uses the CommandLineTools toolchain directly so this script doesn't require accepting the
# full Xcode license (run `sudo xcodebuild -license accept` yourself if you'd rather use Xcode.app).
export DEVELOPER_DIR="/Library/Developer/CommandLineTools"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="Pawprint"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONFIG="${1:-debug}"
# SwiftPM's SQLite build database can be unreliable in synced/Desktop folders on some machines.
# Keep the existing repository-local default, while allowing development builds to put only
# SwiftPM's disposable cache elsewhere:
#   PAWPRINT_SWIFTPM_SCRATCH_PATH=/private/tmp/pawprint-build ./scripts/build_app.sh
SWIFTPM_SCRATCH_PATH="${PAWPRINT_SWIFTPM_SCRATCH_PATH:-$ROOT_DIR/.build}"

echo "==> Building ($CONFIG)..."
cd "$ROOT_DIR"
if [ "$CONFIG" = "release" ]; then
    # Release builds are universal. Sequoia still runs on Intel Macs (2018-2020), and an
    # arm64-only app on one of those shows the prohibitory badge on its icon and refuses to
    # launch — there is no Rosetta in that direction. Shipping arm64-only silently excluded
    # every Intel user, with an error message that says nothing about why.
    #
    # Built one architecture at a time and joined with `lipo`, rather than `swift build --arch
    # arm64 --arch x86_64`: that form needs xcbuild from a full Xcode install, and this script
    # deliberately uses the CommandLineTools toolchain so no Xcode licence is required.
    MIN_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$ROOT_DIR/scripts/Info.plist")"
    for arch in arm64 x86_64; do
        echo "    ...$arch"
        swift build --scratch-path "$SWIFTPM_SCRATCH_PATH" \
            -c release --triple "$arch-apple-macosx$MIN_MACOS"
    done
    BIN_PATH="$BUILD_DIR/$APP_NAME-universal"
    mkdir -p "$BUILD_DIR"
    lipo -create -output "$BIN_PATH" \
        "$SWIFTPM_SCRATCH_PATH/arm64-apple-macosx/release/$APP_NAME" \
        "$SWIFTPM_SCRATCH_PATH/x86_64-apple-macosx/release/$APP_NAME"
    echo "==> Universal binary: $(lipo -archs "$BIN_PATH")"
else
    # Debug builds stay native — they only ever run on the machine that produced them, and
    # building twice would double every edit-run cycle.
    swift build --scratch-path "$SWIFTPM_SCRATCH_PATH"
    BIN_PATH="$SWIFTPM_SCRATCH_PATH/debug/$APP_NAME"
fi

# Assemble into a staging bundle and only swap it into place once it is signed *and* verified.
# Signing can fail (or need a keychain prompt) — building in place would then leave a corrupt,
# half-signed app where the working one used to be, silently invalidating its TCC permissions.
STAGING="$BUILD_DIR/.staging-$APP_NAME.app"
echo "==> Assembling app bundle"
rm -rf "$STAGING"
mkdir -p "$STAGING/Contents/MacOS"
mkdir -p "$STAGING/Contents/Resources"

cp "$BIN_PATH" "$STAGING/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/scripts/Info.plist" "$STAGING/Contents/Info.plist"

if [ ! -f "$ROOT_DIR/Assets/AppIcon.icns" ]; then
    echo "==> Generating app icon"
    "$ROOT_DIR/scripts/make_icon.sh"
fi
cp "$ROOT_DIR/Assets/AppIcon.icns" "$STAGING/Contents/Resources/AppIcon.icns"

# Language packs go somewhere `Bundle.main` can find them. Relying on SwiftPM's resource bundle
# alone shipped a build that crashed on launch: its accessor traps when the bundle isn't at the
# path baked in at compile time, which no assembled .app matches.
mkdir -p "$STAGING/Contents/Resources/Localization"
cp "$ROOT_DIR/Sources/Pawprint/Resources/Localization/"*.json "$STAGING/Contents/Resources/Localization/"

# Copy SwiftPM-processed resource bundle if it exists
RESOURCE_BUNDLE="$(dirname "$BIN_PATH")/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$STAGING/Contents/Resources/"
fi

# Prefer a stable identity so Accessibility/Input Monitoring grants survive rebuilds: macOS keys
# those permissions off the code signature, and an ad-hoc signature changes with every build.
#
# `PAWPRINT_SIGN_IDENTITY` lets CI name the identity outright. That matters because a self-signed
# certificate imported into a fresh keychain has no trust settings, so `find-identity -v` reports
# it as invalid and the search below would miss it — which silently produced ad-hoc release builds.
# Trust is only needed to *verify* a signature, not to create one, so signing with it is fine.
if [ -n "${PAWPRINT_SIGN_IDENTITY:-}" ]; then
    SIGN_IDENTITY="$PAWPRINT_SIGN_IDENTITY"
elif security find-identity -p codesigning 2>/dev/null | grep -q "Pawprint Dev"; then
    SIGN_IDENTITY="Pawprint Dev"
else
    SIGN_IDENTITY="-"
    echo "==> Note: 'Pawprint Dev' signing identity not found, falling back to ad-hoc signing."
    echo "    Accessibility/Input Monitoring permissions will need to be re-granted after this rebuild."
fi

signing_failed() {
    echo ""
    echo "!! Signing failed — the existing app in build/ was left untouched."
    echo "!! macOS is most likely waiting on a keychain dialog for the 'Pawprint Dev' key."
    echo "!! Authorize it once (asks for your login password), then re-run this script:"
    echo ""
    echo "   security set-key-partition-list -S apple-tool:,apple:,codesign: -s -l 'Pawprint Dev' ~/Library/Keychains/login.keychain-db"
    echo ""
    rm -rf "$STAGING"
    exit 1
}

echo "==> Signing with identity: $SIGN_IDENTITY"
# codesign blocks forever on the keychain authorization dialog if nobody is at the keyboard, so
# give it a deadline. Killing it is safe here: it is only ever signing the staging copy, which is
# discarded on failure — the installed app is never touched until signing has been verified.
codesign --force --deep --timestamp=none --sign "$SIGN_IDENTITY" "$STAGING" &
CODESIGN_PID=$!
SIGN_TIMEOUT=45
SIGN_DEADLINE=$SIGN_TIMEOUT
while kill -0 "$CODESIGN_PID" 2>/dev/null && [ "$SIGN_DEADLINE" -gt 0 ]; do
    sleep 1
    SIGN_DEADLINE=$((SIGN_DEADLINE - 1))
done
if kill -0 "$CODESIGN_PID" 2>/dev/null; then
    kill -9 "$CODESIGN_PID" 2>/dev/null
    # `|| true` matters: under `set -e` a non-zero wait status would abort the script here,
    # before the diagnostic below ever printed.
    wait "$CODESIGN_PID" 2>/dev/null || true
    echo "!! codesign timed out after ${SIGN_TIMEOUT}s — it is waiting on a keychain prompt."
    signing_failed
fi
wait "$CODESIGN_PID" 2>/dev/null || signing_failed

# A killed or partial codesign can still exit 0 in odd cases, so confirm the result is sound
# before letting it replace a known-good bundle.
codesign --verify --deep --strict "$STAGING" 2>/dev/null || signing_failed

echo "==> Installing to $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mv "$STAGING" "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
