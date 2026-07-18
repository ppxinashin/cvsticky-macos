#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PROJECT_DIR="${CVSTICKY_PROJECT_DIR:-$DEFAULT_PROJECT_DIR}"
BUILD_FROM_EXISTING=0
VERSION_OVERRIDE="${CVSTICKY_VERSION:-}"
BUILD_NUMBER="${CVSTICKY_BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

usage() {
  cat <<'USAGE'
Usage: package_cvsticky.sh [--from-existing-release]

Build or repackage CVSticky for macOS arm64.

Options:
  --from-existing-release  Skip swift build and use .build/out/Products/Release artifacts.

Environment:
  CVSTICKY_PROJECT_DIR     Defaults to the repository containing this project-level skill
  CVSTICKY_VERSION         Optional version override, leading "v" allowed
  CVSTICKY_BUILD_NUMBER    Optional integer build number
  CODE_SIGN_IDENTITY       Defaults to ad-hoc signing with "-"
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-existing-release)
      BUILD_FROM_EXISTING=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "$PROJECT_DIR"

VERSION="${VERSION_OVERRIDE#v}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Packaging/Info.plist")"
fi
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9]+)*$ ]]; then
  echo "Invalid CVSticky version: $VERSION" >&2
  exit 1
fi
if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Invalid CVSticky build number: $BUILD_NUMBER" >&2
  exit 1
fi

if [[ "$BUILD_FROM_EXISTING" -eq 0 ]]; then
  swift build -c release --arch arm64
  BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
elif [[ -d "$PROJECT_DIR/.build/out/Products/Release" ]]; then
  BIN_DIR="$PROJECT_DIR/.build/out/Products/Release"
else
  BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
fi

APP_DIR="$PROJECT_DIR/dist/CVSticky.app"
DMG_STAGING_DIR="$PROJECT_DIR/dist/dmg-staging"
DMG_PATH="$PROJECT_DIR/dist/CVSticky-macOS-arm64.dmg"
ZIP_PATH="$PROJECT_DIR/dist/CVSticky-macOS-arm64.zip"
RESOURCE_BUNDLE="$BIN_DIR/CVSticky_CVSticky.bundle"

if [[ ! -x "$BIN_DIR/CVSticky" ]]; then
  echo "Missing release executable: $BIN_DIR/CVSticky" >&2
  exit 1
fi
if [[ ! -f "$RESOURCE_BUNDLE/Contents/Info.plist" ]]; then
  echo "Missing valid SwiftPM resource bundle: $RESOURCE_BUNDLE/Contents/Info.plist" >&2
  exit 1
fi

rm -rf "$APP_DIR" "$DMG_STAGING_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/CVSticky" "$APP_DIR/Contents/MacOS/CVSticky"
cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Packaging/CVSticky.icns" "$APP_DIR/Contents/Resources/CVSticky.icns"
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
chmod +x "$APP_DIR/Contents/MacOS/CVSticky"

for required in \
  "$APP_DIR/Contents/Resources/CVSticky_CVSticky.bundle/Contents/Info.plist" \
  "$APP_DIR/Contents/Resources/CVSticky_CVSticky.bundle/Contents/Resources/milkdown-editor.js" \
  "$APP_DIR/Contents/Resources/CVSticky_CVSticky.bundle/Contents/Resources/milkdown-editor.css"
do
  if [[ ! -f "$required" ]]; then
    echo "Packaged app is missing required resource: $required" >&2
    exit 1
  fi
done

if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP_DIR"
else
  codesign --force --deep --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$APP_DIR"
fi
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -f "$DMG_PATH" "$ZIP_PATH"
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
echo "Verify the DMG by mounting it read-only and checking CVSticky_CVSticky.bundle/Contents/Resources."
