#!/bin/bash
# Build, sign, and deploy AutoRip2MKV-Mac to ~/Applications

set -e
REPO="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/AutoRip2MKV-Mac.app"

echo "Building..."
cd "$REPO"
swift build -c release

echo "Stopping running instance and any child ffmpeg processes..."
pkill -x AutoRip2MKV-Mac 2>/dev/null || true
pkill -x ffmpeg 2>/dev/null || true
sleep 1

echo "Deploying binary and Info.plist..."
cp "$REPO/.build/release/AutoRip2MKV-Mac" "$APP/Contents/MacOS/AutoRip2MKV-Mac"
cp "$REPO/Info.plist" "$APP/Contents/Info.plist"

echo "Signing with entitlements..."
codesign --force --deep --sign - \
  --entitlements "$REPO/AutoRip2MKV.entitlements" \
  "$APP"

echo "Launching..."
open "$APP"
echo "Done."
