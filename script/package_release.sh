#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Dex"
BUNDLE_ID="app.dex.notch"
MINIMUM_MACOS="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
BUILD_NUMBER="${2:-}"
SIGNING_IDENTITY="${DEX_CODESIGN_IDENTITY:-}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "usage: $0 <version> <numeric-build-number>" >&2
  exit 2
fi
if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "build number must be a positive integer" >&2
  exit 2
fi
if [[ -z "$SIGNING_IDENTITY" && "${DEX_ALLOW_ADHOC:-0}" != "1" ]]; then
  echo "DEX_CODESIGN_IDENTITY is required; set DEX_ALLOW_ADHOC=1 only for local artifact checks" >&2
  exit 2
fi

DIST_DIR="$ROOT_DIR/dist/release"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
CHECKSUM_PATH="$DIST_DIR/$APP_NAME-$VERSION.sha256"
ARM_BUILD="$ROOT_DIR/.build/release-arm64"
INTEL_BUILD="$ROOT_DIR/.build/release-x86_64"
DMG_ROOT="$ROOT_DIR/.build/release-dmg-root"

rm -rf "$APP_BUNDLE" "$ARM_BUILD" "$INTEL_BUILD" "$DMG_ROOT"
rm -f "$DMG_PATH" "$CHECKSUM_PATH"
mkdir -p "$DIST_DIR" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Frameworks" "$DMG_ROOT"

swift build \
  --package-path "$ROOT_DIR" \
  --scratch-path "$ARM_BUILD" \
  --triple "arm64-apple-macosx$MINIMUM_MACOS" \
  --configuration release \
  --product "$APP_NAME"
swift build \
  --package-path "$ROOT_DIR" \
  --scratch-path "$INTEL_BUILD" \
  --triple "x86_64-apple-macosx$MINIMUM_MACOS" \
  --configuration release \
  --product "$APP_NAME"

ARM_BINARY="$(swift build --package-path "$ROOT_DIR" --scratch-path "$ARM_BUILD" --triple "arm64-apple-macosx$MINIMUM_MACOS" --configuration release --show-bin-path)/$APP_NAME"
INTEL_BINARY="$(swift build --package-path "$ROOT_DIR" --scratch-path "$INTEL_BUILD" --triple "x86_64-apple-macosx$MINIMUM_MACOS" --configuration release --show-bin-path)/$APP_NAME"
SPARKLE_FRAMEWORK="$ARM_BUILD/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"

lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
ditto "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
cp "$ROOT_DIR/Support/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"

FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
if [[ -n "$SIGNING_IDENTITY" ]]; then
  SIGNATURE_ARGS=(--force --sign "$SIGNING_IDENTITY" --timestamp --options runtime)
else
  SIGNATURE_ARGS=(--force --sign -)
fi

codesign "${SIGNATURE_ARGS[@]}" "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc"
codesign "${SIGNATURE_ARGS[@]}" --preserve-metadata=entitlements "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc"
codesign "${SIGNATURE_ARGS[@]}" "$FRAMEWORK/Versions/B/Autoupdate"
codesign "${SIGNATURE_ARGS[@]}" "$FRAMEWORK/Versions/B/Updater.app"
codesign "${SIGNATURE_ARGS[@]}" "$FRAMEWORK"
codesign "${SIGNATURE_ARGS[@]}" --identifier "$BUNDLE_ID" "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
lipo "$APP_BUNDLE/Contents/MacOS/$APP_NAME" -verify_arch arm64 x86_64
lipo "$FRAMEWORK/Versions/B/Sparkle" -verify_arch arm64 x86_64

ditto "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
  -fs APFS \
  -format ULFO \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  "$DMG_PATH"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi
hdiutil verify "$DMG_PATH"

(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo "App: $APP_BUNDLE"
echo "DMG: $DMG_PATH"
echo "Checksum: $CHECKSUM_PATH"
