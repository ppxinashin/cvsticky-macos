#!/bin/bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: create-pretty-dmg.sh STAGING_DIR DMG_PATH VOLUME_NAME" >&2
  exit 2
fi

STAGING_DIR="$1"
DMG_PATH="$2"
VOLUME_NAME="$3"

if [[ ! -d "$STAGING_DIR" ]]; then
  echo "Missing DMG staging directory: $STAGING_DIR" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cvsticky-dmg.XXXXXX")"
RW_DMG="$TMP_DIR/CVSticky-rw.dmg"
MOUNT_DIR="$TMP_DIR/mount"
BG_SWIFT="$TMP_DIR/make-dmg-background.swift"
mkdir -p "$MOUNT_DIR"

cleanup() {
  if mount | grep -q " on $MOUNT_DIR "; then
    hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$RW_DMG" >/dev/null

hdiutil attach \
  -readwrite \
  -noverify \
  -noautoopen \
  -mountpoint "$MOUNT_DIR" \
  "$RW_DMG" >/dev/null

BACKGROUND_DIR="$MOUNT_DIR/.background"
BACKGROUND_PATH="$BACKGROUND_DIR/CVSticky-dmg-background.png"
mkdir -p "$BACKGROUND_DIR"

cat > "$BG_SWIFT" <<'SWIFT'
import AppKit
import Foundation

let output = ProcessInfo.processInfo.environment["CVSTICKY_DMG_BACKGROUND"]!
let size = NSSize(width: 720, height: 460)
let image = NSImage(size: size)

func drawText(_ text: String, at point: NSPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor, alignment: NSTextAlignment = .center) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    let string = NSAttributedString(string: text, attributes: attrs)
    string.draw(in: NSRect(x: point.x, y: point.y, width: 620, height: size + 14))
}

func drawText(_ text: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor, alignment: NSTextAlignment = .center) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    let string = NSAttributedString(string: text, attributes: attrs)
    string.draw(in: rect)
}

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let background = NSGradient(colors: [
    NSColor(red: 0.96, green: 0.98, blue: 0.96, alpha: 1.0),
    NSColor(red: 0.85, green: 0.93, blue: 0.96, alpha: 1.0),
    NSColor(red: 0.99, green: 0.94, blue: 0.86, alpha: 1.0)
])!
background.draw(in: rect, angle: 25)

NSColor.white.withAlphaComponent(0.72).setFill()
NSBezierPath(roundedRect: NSRect(x: 34, y: 36, width: 652, height: 388), xRadius: 32, yRadius: 32).fill()

let accent = NSColor(red: 0.12, green: 0.42, blue: 0.45, alpha: 1.0)
let softAccent = NSColor(red: 0.12, green: 0.42, blue: 0.45, alpha: 0.16)
let warm = NSColor(red: 0.95, green: 0.55, blue: 0.23, alpha: 1.0)

softAccent.setFill()
NSBezierPath(ovalIn: NSRect(x: 500, y: 285, width: 145, height: 92)).fill()
NSColor(red: 0.95, green: 0.55, blue: 0.23, alpha: 0.18).setFill()
NSBezierPath(ovalIn: NSRect(x: 86, y: 78, width: 172, height: 108)).fill()

drawText("CVSticky", at: NSPoint(x: 50, y: 376), size: 31, weight: .bold, color: NSColor(red: 0.08, green: 0.14, blue: 0.16, alpha: 1.0))
drawText("Drag CVSticky to Applications", at: NSPoint(x: 50, y: 346), size: 17, weight: .medium, color: NSColor(red: 0.26, green: 0.34, blue: 0.36, alpha: 1.0))

let arrow = NSBezierPath()
arrow.lineWidth = 8
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 270, y: 215))
arrow.curve(to: NSPoint(x: 452, y: 215), controlPoint1: NSPoint(x: 325, y: 252), controlPoint2: NSPoint(x: 398, y: 252))
accent.setStroke()
arrow.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: 452, y: 215))
head.line(to: NSPoint(x: 420, y: 237))
head.move(to: NSPoint(x: 452, y: 215))
head.line(to: NSPoint(x: 420, y: 193))
head.lineWidth = 8
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()

warm.setFill()
NSBezierPath(roundedRect: NSRect(x: 322, y: 196, width: 76, height: 39), xRadius: 19, yRadius: 19).fill()
drawText("Install", in: NSRect(x: 322, y: 204, width: 76, height: 20), size: 15, weight: .semibold, color: .white)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render DMG background")
}
try data.write(to: URL(fileURLWithPath: output))
SWIFT

CVSTICKY_DMG_BACKGROUND="$BACKGROUND_PATH" swift "$BG_SWIFT"

/usr/bin/SetFile -a V "$BACKGROUND_DIR" || true

osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to POSIX file "$MOUNT_DIR" as alias
  open dmgFolder
  delay 1
  tell folder dmgFolder
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {120, 120, 840, 630}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 112
    set text size of theViewOptions to 10
    set label position of theViewOptions to bottom
    set background picture of theViewOptions to file ".background:CVSticky-dmg-background.png"
    set position of item "CVSticky.app" of container window to {180, 326}
    set position of item "Applications" of container window to {540, 326}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR" >/dev/null
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_PATH" >/dev/null

echo "Created styled DMG $DMG_PATH"
