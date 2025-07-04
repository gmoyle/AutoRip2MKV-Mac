#!/bin/bash

# AutoRip2MKV macOS Quarantine Removal Script
# This script helps remove the quarantine attribute that prevents the app from running

set -e

echo "🍎 AutoRip2MKV - macOS Quarantine Removal"
echo "=========================================="
echo ""

APP_PATH="/Applications/AutoRip2MKV.app"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ AutoRip2MKV.app not found in /Applications/"
    echo "   Please install the app first by:"
    echo "   1. Download the DMG from GitHub Releases"
    echo "   2. Drag AutoRip2MKV to Applications"
    echo ""
    exit 1
fi

echo "✅ Found AutoRip2MKV.app in Applications"

# Check current quarantine status
echo ""
echo "🔍 Checking current quarantine status..."
if xattr -l "$APP_PATH" | grep -q "com.apple.quarantine"; then
    echo "⚠️  App is currently quarantined by macOS"
    
    echo ""
    echo "🔓 Removing quarantine attribute..."
    
    # Remove quarantine attribute
    if sudo xattr -r -d com.apple.quarantine "$APP_PATH" 2>/dev/null; then
        echo "✅ Successfully removed quarantine attribute"
    else
        echo "❌ Failed to remove quarantine attribute"
        echo "   This might happen if:"
        echo "   - You don't have admin privileges"
        echo "   - The attribute is already removed"
        echo "   - System Integrity Protection is blocking the change"
        exit 1
    fi
    
    # Verify removal
    echo ""
    echo "🔍 Verifying removal..."
    if xattr -l "$APP_PATH" | grep -q "com.apple.quarantine"; then
        echo "⚠️  Quarantine attribute still present - manual removal may be needed"
    else
        echo "✅ Quarantine attribute successfully removed!"
    fi
    
else
    echo "✅ App is not quarantined - should run normally"
fi

# Check code signature
echo ""
echo "🔍 Checking code signature..."
if codesign --verify "$APP_PATH" 2>/dev/null; then
    echo "✅ App has valid ad-hoc signature"
else
    echo "⚠️  App signature verification failed - this is normal for ad-hoc signed apps"
fi

echo ""
echo "🎉 Done! You should now be able to run AutoRip2MKV normally."
echo ""
echo "💡 If the app still won't open:"
echo "   1. Try right-clicking the app → 'Open'"
echo "   2. Check System Preferences → Security & Privacy"
echo "   3. See the full installation guide: INSTALLATION.md"
echo ""
