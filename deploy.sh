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
# Developer ID gives the app a stable code identity so macOS TCC grants
# (removable-volume access) persist across rebuilds; ad-hoc signing (-)
# resets the permission prompt on every deploy.
codesign --force --deep --sign "Developer ID Application: Gregory Moyle (85XT8FWW2B)" \
  --entitlements "$REPO/AutoRip2MKV.entitlements" \
  "$APP"

echo "Launching..."
open "$APP"
echo "Done."
