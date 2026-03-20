#!/bin/bash
set -euo pipefail

APP_NAME="Loom"
BUILD_DIR=".build/release"
STAGING_DIR=".build/dmg-staging"
DMG_OUTPUT="Loom.dmg"
SIGN_IDENTITY="-" # ad-hoc by default

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --sign) SIGN_IDENTITY="$2"; shift 2 ;;
        --output) DMG_OUTPUT="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "Building $APP_NAME..."
swift build -c release

# Create .app bundle
APP_BUNDLE="$STAGING_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
rm -rf "$STAGING_DIR"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

cp "$BUILD_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"
cp "Loom/Info.plist" "$CONTENTS/Info.plist"
cp "Loom/Loom.entitlements" "$CONTENTS/Resources/"

if [ -d "$BUILD_DIR/Loom_Loom.resources" ]; then
    cp -R "$BUILD_DIR/Loom_Loom.resources/"* "$CONTENTS/Resources/" 2>/dev/null || true
fi

# Copy app icon
if [ -f "Loom/Resources/AppIcon.icns" ]; then
    cp "Loom/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi

echo "Signing with: $SIGN_IDENTITY"
codesign --force --sign "$SIGN_IDENTITY" \
    --entitlements "Loom/Loom.entitlements" \
    "$APP_BUNDLE"

# Create DMG
ln -sf /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_OUTPUT"
hdiutil create "$DMG_OUTPUT" \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO

rm -rf "$STAGING_DIR"

echo ""
echo "Created: $DMG_OUTPUT"
echo "Open it and drag $APP_NAME.app to Applications."
