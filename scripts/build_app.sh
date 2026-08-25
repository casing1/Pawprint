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
LEGACY_UI_BUILD="${PAWPRINT_LEGACY_UI:-0}"
LEGACY_UI_SDK="${PAWPRINT_LEGACY_UI_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk}"

# Pawprint 0.10.0 was linked against the macOS 15 SDK. On macOS 26, merely keeping the
# SwiftUI source unchanged is not enough: AppKit intentionally gives apps linked against the
# newer SDK different control metrics, popover material, corner geometry, and scrollers.
# Development builds that include Adventure therefore compile against the available macOS 15
# SDK so the untouched Pawprint UI keeps its 0.10 appearance.
#
# Swift 6.3's Observation macro emits one additional private member that the 15.4 SDK's macro
# declaration does not list. Patch only that declaration in a disposable overlay; all AppKit and
# SwiftUI interfaces still come from the real 15.4 SDK.
if [ "$LEGACY_UI_BUILD" = "1" ]; then
    if [ ! -d "$LEGACY_UI_SDK" ]; then
        echo "Legacy Pawprint UI SDK not found: $LEGACY_UI_SDK" >&2
        exit 1
    fi

    LEGACY_UI_SDK_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :Version' \
        "$LEGACY_UI_SDK/SDKSettings.plist")"
    case "$LEGACY_UI_SDK_VERSION" in
        15.*) ;;
        *)
            echo "Refusing legacy UI build with non-macOS-15 SDK: $LEGACY_UI_SDK_VERSION" >&2
            exit 1
            ;;
    esac

    OBSERVATION_OVERLAY_ROOT="$SWIFTPM_SCRATCH_PATH/pawprint-sdk15-overlay"
    OBSERVATION_OVERLAY_MODULE="$OBSERVATION_OVERLAY_ROOT/Observation.swiftmodule"
    rm -rf "$OBSERVATION_OVERLAY_ROOT"
    mkdir -p "$OBSERVATION_OVERLAY_ROOT"
    cp -R "$LEGACY_UI_SDK/usr/lib/swift/Observation.swiftmodule" \
        "$OBSERVATION_OVERLAY_MODULE"

    for interface in "$OBSERVATION_OVERLAY_MODULE/"*.swiftinterface; do
        sed -i '' \
            's/named(withMutation))/named(withMutation), named(shouldNotifyObservers))/' \
            "$interface"
    done

    if ! grep -q 'named(shouldNotifyObservers)' \
        "$OBSERVATION_OVERLAY_MODULE/arm64e-apple-macos.swiftinterface"; then
        echo "Failed to prepare the Swift 6 Observation compatibility overlay." >&2
        exit 1
    fi

    export SDKROOT="$LEGACY_UI_SDK"
    SWIFT_BUILD_ARGUMENTS=(
        --sdk "$LEGACY_UI_SDK"
        -Xswiftc -I
        -Xswiftc "$OBSERVATION_OVERLAY_ROOT"
    )
    echo "==> Pawprint 0.10 UI compatibility SDK: macOS $LEGACY_UI_SDK_VERSION"
fi

run_swift_build() {
    # macOS still ships Bash 3.2, where expanding an empty array under `set -u` aborts. Keep the
    # normal release path argument-free instead of relying on an empty compatibility array.
    if [ "$LEGACY_UI_BUILD" = "1" ]; then
        swift build --scratch-path "$SWIFTPM_SCRATCH_PATH" \
            "${SWIFT_BUILD_ARGUMENTS[@]}" "$@"
    else
        swift build --scratch-path "$SWIFTPM_SCRATCH_PATH" "$@"
    fi
}

verify_legacy_ui_sdk() {
    local binary_path="$1"
    local build_versions
    local linked_sdk
    local found_sdk=false

    build_versions="$(xcrun vtool -show-build "$binary_path")"
    while IFS= read -r linked_sdk; do
        found_sdk=true
        case "$linked_sdk" in
            15.*) ;;
            *)
                echo "Refusing legacy UI build linked against SDK $linked_sdk: $binary_path" >&2
                exit 1
                ;;
        esac
    done < <(printf '%s\n' "$build_versions" | awk '$1 == "sdk" { print $2 }')

    if [ "$found_sdk" != true ]; then
        echo "Could not find LC_BUILD_VERSION in legacy UI binary: $binary_path" >&2
        exit 1
    fi
}

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
        run_swift_build \
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
    run_swift_build
    BIN_PATH="$(run_swift_build --show-bin-path)/$APP_NAME"
fi

if [ "$LEGACY_UI_BUILD" = "1" ]; then
    verify_legacy_ui_sdk "$BIN_PATH"
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
