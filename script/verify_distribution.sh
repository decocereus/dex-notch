#!/usr/bin/env bash
set -euo pipefail

DMG_PATH="${1:-}"
if [[ ! -f "$DMG_PATH" ]]; then
  echo "usage: $0 <notarized-dmg>" >&2
  exit 2
fi

MOUNT_DIR="$(mktemp -d)"
INSTALL_DIR="$(mktemp -d)"
APP_PATH="$INSTALL_DIR/Dex.app"

cleanup() {
  hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
  rm -rf "$MOUNT_DIR" "$INSTALL_DIR"
}
trap cleanup EXIT

hdiutil verify "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR" -quiet
ditto "$MOUNT_DIR/Dex.app" "$APP_PATH"
hdiutil detach "$MOUNT_DIR" -quiet

xattr -r -w com.apple.quarantine "0081;$(printf '%x' "$(date +%s)");DexRelease;" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"
lipo "$APP_PATH/Contents/MacOS/Dex" -verify_arch arm64 x86_64

"$APP_PATH/Contents/MacOS/Dex" --expanded &
APP_PID=$!
for _ in {1..20}; do
  if kill -0 "$APP_PID" >/dev/null 2>&1; then
    sleep 0.25
  else
    wait "$APP_PID"
    echo "Dex exited during clean-install launch verification" >&2
    exit 1
  fi
done
kill "$APP_PID"
wait "$APP_PID" 2>/dev/null || true

echo "Verified notarized, quarantined, universal Dex installation from $DMG_PATH"
