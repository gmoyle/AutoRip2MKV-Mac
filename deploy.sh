#!/bin/bash
# Build, sign, and deploy AutoRip2MKV-Mac to ~/Applications
#
# Usage: ./deploy.sh [--force]
#   --force  deploy even if a rip (makemkvcon) is running. Deploying kills the
#            app, and killing the app orphans its makemkvcon child mid-rip, so by
#            default we refuse to deploy while a rip is active.

set -e
REPO="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/AutoRip2MKV-Mac.app"

FORCE=0
[ "$1" = "--force" ] && FORCE=1

echo "Building..."
cd "$REPO"
swift build -c release

# Guard: never kill the app (and orphan/interrupt a rip) while makemkvcon runs.
# Building above is safe during a rip — it doesn't touch the drive — but the
# pkill below would cut the rip off, so we check here, after the build.
if pgrep -x makemkvcon >/dev/null 2>&1; then
    if [ "$FORCE" -ne 1 ]; then
        echo "ERROR: a rip (makemkvcon) is currently running." >&2
        echo "Deploying would kill the app and interrupt/orphan the rip." >&2
        echo "Cancel the rip from the app (Cancel Rip button) or wait for it to" >&2
        echo "finish, then re-run. Use './deploy.sh --force' to override." >&2
        exit 1
    fi
    echo "WARNING: --force set; deploying despite an active rip (it will be interrupted)."
fi

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
