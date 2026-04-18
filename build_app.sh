#!/bin/bash
# Build PerfMonitor as a proper macOS .app bundle
set -e

APP_NAME="SystemPulse"
BUILD_DIR=".build/release"
APP_DIR="$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Building release binary..."
swift build -c release

echo "==> Creating app bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BUILD_DIR/$APP_NAME" "$MACOS/$APP_NAME"
cp AppIcon.icns "$RESOURCES/"

cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SystemPulse</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.SystemPulse</string>
    <key>CFBundleName</key>
    <string>SystemPulse</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleDisplayName</key>
    <string>SystemPulse</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>SystemPulse detects when the camera is in use.</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc signing..."
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "✅ Done: $(pwd)/$APP_DIR"
echo "   Open:   open $APP_DIR"
echo "   Move:   mv $APP_DIR /Applications/"
