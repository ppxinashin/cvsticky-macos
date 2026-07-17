#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

VERSION="${CVSTICKY_VERSION:-}"
VERSION="${VERSION#v}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Packaging/Info.plist")"
fi
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9]+)*$ ]]; then
  echo "Invalid CVSticky version: $VERSION" >&2
  exit 1
fi
BUILD_NUMBER="${CVSTICKY_BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Invalid CVSticky build number: $BUILD_NUMBER" >&2
  exit 1
fi
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/CVSticky.app"
DMG_STAGING_DIR="$PROJECT_DIR/dist/dmg-staging"
DMG_PATH="$PROJECT_DIR/dist/CVSticky-macOS-arm64.dmg"
ZIP_PATH="$PROJECT_DIR/dist/CVSticky-macOS-arm64.zip"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/CVSticky" "$APP_DIR/Contents/MacOS/CVSticky"
cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Packaging/CVSticky.icns" "$APP_DIR/Contents/Resources/CVSticky.icns"
cp -R "$BIN_DIR/CVSticky_CVSticky.bundle" "$APP_DIR/Contents/Resources/"
chmod +x "$APP_DIR/Contents/MacOS/CVSticky"
if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP_DIR"
else
  codesign --force --deep --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$APP_DIR"
fi

rm -rf "$DMG_STAGING_DIR" "$DMG_PATH" "$ZIP_PATH"
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_DIR" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
  -volname "CVSticky" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$CODE_SIGN_IDENTITY" "$DMG_PATH"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
rm -rf "$DMG_STAGING_DIR"
echo "Built $APP_DIR ($VERSION build $BUILD_NUMBER)"
echo "Built $DMG_PATH"
echo "Built $ZIP_PATH"
