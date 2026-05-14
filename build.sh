#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="PRPing"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"

swiftc -O \
  -framework Cocoa \
  -o "$MACOS/$APP_NAME" \
  Sources/main.swift

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>PRPing</string>
    <key>CFBundleIdentifier</key><string>com.tamara.prping</string>
    <key>CFBundleName</key><string>PRPing</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "Built: $APP_BUNDLE"
