#!/bin/bash
set -euo pipefail

# Builds and installs the local RPG development app without touching /Applications/Pawprint.app.
#
# Its identifier-only designated requirement is intentional and local-development-only. A normal
# ad-hoc signature's designated requirement is its changing cdhash, which makes macOS treat every
# rebuild as a new Accessibility/Input Monitoring client. Keeping this requirement stable lets the
# grants survive rebuilds. Release artifacts continue to use scripts/build_app.sh and never take
# this path.

export DEVELOPER_DIR="/Library/Developer/CommandLineTools"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/build/Pawprint.app"
TARGET_APP="/Applications/Pawprint RPG Dev.app"
OFFICIAL_APP="/Applications/Pawprint.app"
DEV_BUNDLE_ID="com.pawprint.app.rpgdev"
OFFICIAL_BUNDLE_ID="com.pawprint.app"
DEV_APP_NAME="Pawprint RPG Dev"
DEV_REQUIREMENT="designated => identifier \"$DEV_BUNDLE_ID\""
RPG_DEV_SCRATCH_PATH="${PAWPRINT_RPG_DEV_SCRATCH_PATH:-/private/tmp/pawprint-rpg-dev-build}"

RESET_PERMISSIONS=false
CONFIG="debug"

for argument in "$@"; do
    case "$argument" in
        --reset-permissions)
            RESET_PERMISSIONS=true
            ;;
        --release)
            CONFIG="release"
            ;;
        --help|-h)
            echo "Usage: $0 [--reset-permissions] [--release]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $argument" >&2
            echo "Usage: $0 [--reset-permissions] [--release]" >&2
            exit 2
            ;;
    esac
done

STAGING_ROOT="$(mktemp -d "/private/tmp/pawprint-rpg-dev-install.XXXXXX")"
STAGING_APP="$STAGING_ROOT/$DEV_APP_NAME.app"
PREVIOUS_APP="$STAGING_ROOT/previous.app"

cleanup() {
    rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

stop_exact_app() {
    local bundle_id="$1"
    local executable_path="$2"
    local display_name="$3"
    local wait_count=0
    local process_pattern="^$executable_path( |$)"

    if ! pgrep -f "$process_pattern" >/dev/null 2>&1; then
        return
    fi

    echo "==> Stopping $display_name"
    osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || true

    while pgrep -f "$process_pattern" >/dev/null 2>&1; do
        if [ "$wait_count" -ge 40 ]; then
            while IFS= read -r process_id; do
                kill "$process_id" 2>/dev/null || true
            done < <(pgrep -f "$process_pattern")
            break
        fi
        sleep 0.1
        wait_count=$((wait_count + 1))
    done

    sleep 0.2
    if pgrep -f "$process_pattern" >/dev/null 2>&1; then
        echo "Refusing to replace a development app that is still running: $display_name" >&2
        return 1
    fi
}

echo "==> Building the current RPG development source"
PAWPRINT_LEGACY_UI=1 \
    PAWPRINT_SWIFTPM_SCRATCH_PATH="$RPG_DEV_SCRATCH_PATH" \
    "$ROOT_DIR/scripts/build_app.sh" "$CONFIG"

echo "==> Preparing the isolated development bundle"
ditto "$SOURCE_APP" "$STAGING_APP"

# Never install an SDK-26-linked development binary: it would silently reintroduce the wider,
# taller controls and changed popover/scroller rendering that made the base UI diverge from 0.10.
LINKED_SDKS="$(xcrun vtool -show-build "$STAGING_APP/Contents/MacOS/Pawprint" \
    | awk '$1 == "sdk" { print $2 }')"
if [ -z "$LINKED_SDKS" ]; then
    echo "Refusing to install: the development binary has no LC_BUILD_VERSION SDK." >&2
    exit 1
fi
while IFS= read -r linked_sdk; do
    case "$linked_sdk" in
        15.*) ;;
        *)
            echo "Refusing to install: the development binary links SDK $linked_sdk, not 15.x." >&2
            exit 1
            ;;
    esac
done <<< "$LINKED_SDKS"
LINKED_SDK_MARKER="$(printf '%s\n' "$LINKED_SDKS" | awk '!seen[$0]++' | paste -sd, -)"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $DEV_BUNDLE_ID" \
    "$STAGING_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $DEV_APP_NAME" \
    "$STAGING_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $DEV_APP_NAME" \
    "$STAGING_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :PawprintDevelopmentBuild bool true" \
    "$STAGING_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :PawprintUICompatibilitySDK string $LINKED_SDK_MARKER" \
    "$STAGING_APP/Contents/Info.plist"

codesign --force --deep --timestamp=none --sign - \
    --requirements "=$DEV_REQUIREMENT" "$STAGING_APP"
codesign --verify --deep --strict "$STAGING_APP"

if ! codesign -d -r- "$STAGING_APP" 2>&1 | grep -Fxq "$DEV_REQUIREMENT"; then
    echo "Refusing to install: the development designated requirement is not stable." >&2
    exit 1
fi

# Both bundles intentionally share today's Pawprint statistics. Never run both collectors at once,
# or every physical event would be counted twice. The official bundle stays installed and intact.
stop_exact_app "$OFFICIAL_BUNDLE_ID" "$OFFICIAL_APP/Contents/MacOS/Pawprint" "the official Pawprint app"
stop_exact_app "$DEV_BUNDLE_ID" "$TARGET_APP/Contents/MacOS/Pawprint" "$DEV_APP_NAME"

echo "==> Installing $TARGET_APP"
if [ -d "$TARGET_APP" ]; then
    mv "$TARGET_APP" "$PREVIOUS_APP"
fi

if ! mv "$STAGING_APP" "$TARGET_APP"; then
    if [ -d "$PREVIOUS_APP" ]; then
        mv "$PREVIOUS_APP" "$TARGET_APP"
    fi
    echo "Installation failed; the previous development app was restored." >&2
    exit 1
fi

if ! codesign --verify --deep --strict "$TARGET_APP"; then
    rm -rf "$TARGET_APP"
    if [ -d "$PREVIOUS_APP" ]; then
        mv "$PREVIOUS_APP" "$TARGET_APP"
    fi
    echo "Installed signature verification failed; the previous app was restored." >&2
    exit 1
fi

rm -rf "$PREVIOUS_APP"
rm -rf "$SOURCE_APP"

if [ "$RESET_PERMISSIONS" = true ]; then
    echo "==> Removing only stale $DEV_APP_NAME permission records"
    tccutil reset Accessibility "$DEV_BUNDLE_ID"
    tccutil reset ListenEvent "$DEV_BUNDLE_ID"
fi

echo "==> Launching $DEV_APP_NAME"
if [ "$RESET_PERMISSIONS" = true ]; then
    open "$TARGET_APP" --args --permission-repair
else
    open "$TARGET_APP"
fi
echo "==> Done. Production /Applications/Pawprint.app was not changed."
