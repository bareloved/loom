#!/bin/bash
set -euo pipefail

APP_NAME="Loom"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

# Build release
swift build -c release

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"

# Copy Info.plist
cp "Loom/Info.plist" "$CONTENTS/Info.plist"

# Copy entitlements (for reference)
cp "Loom/Loom.entitlements" "$CONTENTS/Resources/"

# Copy resources
if [ -d "$BUILD_DIR/Loom_Loom.resources" ]; then
    cp -R "$BUILD_DIR/Loom_Loom.resources/"* "$CONTENTS/Resources/" 2>/dev/null || true
fi

# Sign with entitlements
codesign --force --sign - \
    --entitlements "Loom/Loom.entitlements" \
    "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
echo "Run:   open $APP_BUNDLE"
