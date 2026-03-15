#!/bin/bash
set -euo pipefail

APP_NAME="TimeTracker"
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
cp "TimeTracker/Info.plist" "$CONTENTS/Info.plist"

# Copy entitlements (for reference)
cp "TimeTracker/TimeTracker.entitlements" "$CONTENTS/Resources/"

# Copy resources
if [ -d "$BUILD_DIR/TimeTracker_TimeTracker.resources" ]; then
    cp -R "$BUILD_DIR/TimeTracker_TimeTracker.resources/"* "$CONTENTS/Resources/" 2>/dev/null || true
fi

# Sign with entitlements
codesign --force --sign - \
    --entitlements "TimeTracker/TimeTracker.entitlements" \
    "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
echo "Run:   open $APP_BUNDLE"
