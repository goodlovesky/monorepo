#!/bin/zsh
set -euo pipefail

ROOT=${0:A:h:h}
APP_DIR="$ROOT/app"
DIST="$ROOT/dist/macos"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

cd "$APP_DIR"
flutter pub get
flutter analyze
flutter test
flutter build macos --release

APP="$APP_DIR/build/macos/Build/Products/Release/Clash RS.app"
RESOURCES="$APP/Contents/Resources"
mkdir -p "$RESOURCES"
rm -f "$RESOURCES/clash-rs-helper"
cp "$APP_DIR/macos/Runner/Resources/mihomo" "$RESOURCES/mihomo"
chmod 755 "$RESOURCES/mihomo"
SIGN_ARGS=(--force --options runtime --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  SIGN_ARGS+=(--timestamp)
fi
codesign "${SIGN_ARGS[@]}" "$RESOURCES/mihomo"
codesign --deep "${SIGN_ARGS[@]}" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "NOTARY_PROFILE 需要 Developer ID Application 签名" >&2
    exit 2
  fi
  APP_ZIP="$DIST/Clash-RS-macOS-notary.zip"
  mkdir -p "$DIST"
  ditto -c -k --keepParent "$APP" "$APP_ZIP"
  xcrun notarytool submit "$APP_ZIP" \
    --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose=4 "$APP"
elif [[ "$SIGN_IDENTITY" != "-" ]]; then
  echo "Developer ID 已签名；设置 NOTARY_PROFILE 后才生成可发布公证产物" >&2
  exit 3
fi

mkdir -p "$DIST"
rm -rf "$DIST/Clash RS.app" "$DIST/dmg-root"
ditto "$APP" "$DIST/Clash RS.app"
DMG_ROOT="$DIST/dmg-root"
mkdir -p "$DMG_ROOT"
ditto "$APP" "$DMG_ROOT/Clash RS.app"
ln -sfn /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "Clash RS" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DIST/Clash-RS-macOS.dmg"

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$DIST/Clash-RS-macOS.dmg" \
    --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DIST/Clash-RS-macOS.dmg"
  xcrun stapler validate "$DIST/Clash-RS-macOS.dmg"
  spctl --assess --type open --context context:primary-signature --verbose=4 \
    "$DIST/Clash-RS-macOS.dmg"
fi

shasum -a 256 "$DIST/Clash-RS-macOS.dmg" > "$DIST/SHA256.txt"
file "$APP/Contents/MacOS/Clash RS" "$RESOURCES/mihomo" > "$DIST/ARCHITECTURES.txt"
echo "Built: $DIST/Clash-RS-macOS.dmg"
