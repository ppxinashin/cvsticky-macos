#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/CVSticky.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/CVSticky" "$APP_DIR/Contents/MacOS/CVSticky"
cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
cp -R "$BIN_DIR/CVSticky_CVSticky.bundle" "$APP_DIR/Contents/Resources/"
chmod +x "$APP_DIR/Contents/MacOS/CVSticky"
codesign --force --deep --sign - "$APP_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$PROJECT_DIR/dist/CVSticky-macOS-arm64.zip"
echo "Built $APP_DIR"
