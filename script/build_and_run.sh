#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Dex"
BUNDLE_ID="app.dex.notch"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build --package-path "$ROOT_DIR" --product "$APP_NAME"
BUILD_DIR="$(swift build --package-path "$ROOT_DIR" --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_DIR/$APP_NAME" "$APP_BINARY"
cp "$ROOT_DIR/Support/Info.plist" "$APP_CONTENTS/Info.plist"
chmod +x "$APP_BINARY"

SIGNING_IDENTITY="${DEX_CODESIGN_IDENTITY:-}"
if [[ -n "$SIGNING_IDENTITY" ]]; then
    if ! /usr/bin/codesign \
        --force \
        --sign "$SIGNING_IDENTITY" \
        --identifier "$BUNDLE_ID" \
        --timestamp=none \
        "$APP_BUNDLE"; then
        echo "Development signing was unavailable; using ad-hoc signing." >&2
        echo "Set DEX_CODESIGN_IDENTITY after granting codesign access to avoid repeated Keychain prompts." >&2
        /usr/bin/codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"
    fi
else
    echo "Using ad-hoc signing for this development build." >&2
    echo "Set DEX_CODESIGN_IDENTITY to keep Keychain access stable across rebuilds." >&2
    /usr/bin/codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"
fi

open_app() {
    /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
    run)
        open_app
        ;;
    --debug|debug)
        lldb -- "$APP_BINARY"
        ;;
    --expanded|expanded)
        /usr/bin/open -n "$APP_BUNDLE" --args --expanded
        ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify|verify)
        open_app
        for _ in {1..20}; do
            if pgrep -x "$APP_NAME" >/dev/null; then
                echo "$APP_NAME is running from $APP_BUNDLE"
                exit 0
            fi
            sleep 0.25
        done
        echo "$APP_NAME did not start" >&2
        exit 1
        ;;
    *)
        echo "usage: $0 [run|--debug|--expanded|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
