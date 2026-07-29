#!/usr/bin/env bash
set -euo pipefail

APP_NAME="StringPilot"
SCHEME="StringPilot"
CONFIGURATION="Release"
PROJECT="StringPilot.xcodeproj"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-$ROOT_DIR/build/DerivedData}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
STAGING_DIR="$ROOT_DIR/build/dmg-root"
MOUNT_DIR="$ROOT_DIR/build/dmg-mount"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
ENTITLEMENTS="$ROOT_DIR/StringPilot/StringPilot.entitlements"

is_mounted() {
    mount | grep -Fq "on $MOUNT_DIR "
}

detach_image() {
    if ! is_mounted; then
        return 0
    fi

    sync
    for attempt in 1 2 3 4 5; do
        if hdiutil detach "$MOUNT_DIR" -quiet; then
            return 0
        fi
        printf 'Disk image is temporarily busy; detach retry %s/5\n' "$attempt" >&2
        sleep 2
    done

    hdiutil detach "$MOUNT_DIR" -force -quiet
}

cleanup() {
    detach_image || true
}
trap cleanup EXIT

rm -rf "$DERIVED_DATA" "$STAGING_DIR" "$MOUNT_DIR" "$DIST_DIR"
mkdir -p "$STAGING_DIR" "$MOUNT_DIR" "$DIST_DIR"

cd "$ROOT_DIR"

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    clean build

test -d "$APP_PATH"
test -f "$APP_PATH/Contents/MacOS/$APP_NAME"
test -f "$ENTITLEMENTS"

# The public CI runner has no Developer ID certificate. Ad-hoc signing still
# seals the complete app and embeds the audio-input entitlement so the DMG can
# be structurally verified. A public notarized release can later replace this
# signature when Apple signing credentials are configured in repository secrets.
codesign \
    --force \
    --deep \
    --options runtime \
    --sign - \
    --entitlements "$ENTITLEMENTS" \
    "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

/usr/bin/ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

hdiutil verify "$DMG_PATH"
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_DIR" "$DMG_PATH" -quiet

test -d "$MOUNT_DIR/$APP_NAME.app"
test -L "$MOUNT_DIR/Applications"
test -x "$MOUNT_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
codesign --verify --deep --strict --verbose=2 "$MOUNT_DIR/$APP_NAME.app"

# APFS disk images occasionally remain busy for a fraction of a second after
# signature verification on hosted runners. Retry normal detach before using a
# forced detach so a transient mount race cannot discard an otherwise valid DMG.
detach_image
shasum -a 256 "$DMG_PATH" > "$DIST_DIR/$APP_NAME.dmg.sha256"

printf '\nCreated %s\n' "$DMG_PATH"
cat "$DIST_DIR/$APP_NAME.dmg.sha256"
