#!/bin/bash
# Build Loom, package into a DMG, and upload as a GitHub release.
#
# Usage:
#   ./scripts/release.sh v1.0
#   ./scripts/release.sh v1.1 --notes "Fixed idle detection bug"
set -euo pipefail

CERT="Apple Development: bareloved@gmail.com (K2V49Q795A)"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: ./scripts/release.sh <version> [--notes \"Release notes\"]"
    echo "Example: ./scripts/release.sh v1.0"
    exit 1
fi
shift

# Parse optional args
NOTES="Loom $VERSION"
while [[ $# -gt 0 ]]; do
    case $1 in
        --notes) NOTES="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Check for gh CLI
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is required. Install with: brew install gh"
    exit 1
fi

# Build and create DMG
echo "Building and packaging Loom $VERSION..."
./scripts/create-dmg.sh --sign "$CERT"

# Create GitHub release with DMG attached
echo "Creating GitHub release $VERSION..."
gh release create "$VERSION" Loom.dmg \
    --title "Loom $VERSION" \
    --notes "$NOTES"

rm -f Loom.dmg

echo ""
echo "Done! Release $VERSION is live."
echo "Users can download from: $(gh release view "$VERSION" --json url -q .url)"
