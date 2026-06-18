#!/bin/bash

# AutoRip2MKV-Mac App Bundle Creator
# This script creates a proper macOS app bundle with all dependencies

set -e

# Configuration
APP_NAME="AutoRip2MKV-Mac"
BUNDLE_ID="com.autorip2mkv.mac"
VERSION="1.2.4"
BUILD_DIR="build"
WORK_DIR="$(/usr/bin/mktemp -d)"
APP_BUNDLE="${WORK_DIR}/${APP_NAME}.app"
FINAL_APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== AutoRip2MKV-Mac App Bundle Creator ===${NC}"

# Check if we have a developer identity
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo -e "${YELLOW}Warning: No Developer ID Application certificate found${NC}"
    echo -e "${YELLOW}You'll need to sign the app manually before distribution${NC}"
    SHOULD_SIGN=false
else
    echo -e "${GREEN}✓ Found Developer ID Application certificate${NC}"
    SHOULD_SIGN=true
fi

# Clean previous build
echo -e "${BLUE}Cleaning previous build...${NC}"
rm -rf "${BUILD_DIR}" "${WORK_DIR}"

# Create app bundle structure
echo -e "${BLUE}Creating app bundle structure...${NC}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${FRAMEWORKS_DIR}"

# Build the executable
echo -e "${BLUE}Building executable...${NC}"
swift build -c release --product AutoRip2MKV-Mac

# Copy executable
echo -e "${BLUE}Copying executable...${NC}"
/usr/bin/ditto --noextattr --noqtn .build/release/AutoRip2MKV-Mac "${MACOS_DIR}/AutoRip2MKV-Mac"
/usr/bin/xattr -d com.apple.provenance "${MACOS_DIR}/AutoRip2MKV-Mac" 2>/dev/null || true

# Create Info.plist in the bundle
echo -e "${BLUE}Creating Info.plist...${NC}"
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSRemovableVolumesUsageDescription</key>
    <string>This app needs access to removable volumes to rip DVDs and Blu-ray discs.</string>
    <key>NSRemovableVolumesUsageDescription</key>
    <string>Access to removable volumes is required for disc reading and ripping operations.</string>
</dict>
</plist>
EOF

# Remove any bundled entitlements file
echo -e "${BLUE}Removing bundled entitlements...${NC}"
rm -f "${CONTENTS_DIR}/AutoRip2MKV.entitlements"

# Bundle FFmpeg if available
if [ -f "/usr/local/bin/ffmpeg" ] || [ -f "/opt/homebrew/bin/ffmpeg" ]; then
    echo -e "${BLUE}Bundling FFmpeg...${NC}"
    
    # Find FFmpeg location
    FFMPEG_PATH=""
    if [ -f "/opt/homebrew/bin/ffmpeg" ]; then
        FFMPEG_PATH="/opt/homebrew/bin/ffmpeg"
    elif [ -f "/usr/local/bin/ffmpeg" ]; then
        FFMPEG_PATH="/usr/local/bin/ffmpeg"
    fi
    
    if [ -n "$FFMPEG_PATH" ]; then
        /usr/bin/ditto --noextattr --noqtn "$FFMPEG_PATH" "${MACOS_DIR}/ffmpeg"
        chmod +x "${MACOS_DIR}/ffmpeg"
        /usr/bin/xattr -d com.apple.provenance "${MACOS_DIR}/ffmpeg" 2>/dev/null || true
        echo -e "${GREEN}✓ FFmpeg bundled successfully${NC}"
    fi
else
    echo -e "${YELLOW}Warning: FFmpeg not found, app will try to use system FFmpeg${NC}"
fi

# Copy any required frameworks/libraries
echo -e "${BLUE}Checking for required frameworks...${NC}"

# Strip extended attributes to avoid signing failures
echo -e "${BLUE}Cleaning extended attributes...${NC}"
/usr/bin/xattr -cr "${APP_BUNDLE}" 2>/dev/null || true
/usr/bin/dot_clean -m "${APP_BUNDLE}" 2>/dev/null || true
/usr/bin/xattr -cr "${APP_BUNDLE}" 2>/dev/null || true

# Sign the app if we have a certificate
if [ "$SHOULD_SIGN" = true ]; then
    echo -e "${BLUE}Code signing the application...${NC}"
    
    # Sign the executable first
    codesign --force --options runtime --entitlements "AutoRip2MKV.entitlements" --sign "Developer ID Application: Gregory Moyle (85XT8FWW2B)" "${MACOS_DIR}/AutoRip2MKV-Mac"
    
    # Sign any bundled executables
    if [ -f "${MACOS_DIR}/ffmpeg" ]; then
        codesign --force --options runtime --sign "Developer ID Application: Gregory Moyle (85XT8FWW2B)" "${MACOS_DIR}/ffmpeg"
    fi
    
    # Sign the app bundle
    codesign --force --options runtime --entitlements "AutoRip2MKV.entitlements" --sign "Developer ID Application: Gregory Moyle (85XT8FWW2B)" "${APP_BUNDLE}"
    
    echo -e "${GREEN}✓ App bundle signed successfully${NC}"
    
    # Verify the signature
    echo -e "${BLUE}Verifying signature...${NC}"
    codesign --verify --deep --strict "${APP_BUNDLE}"
    echo -e "${GREEN}✓ Signature verification passed${NC}"
    
    # Display signature info
    echo -e "${BLUE}Signature details:${NC}"
    codesign -dv "${APP_BUNDLE}"
else
    echo -e "${YELLOW}Skipping code signing (no certificate found)${NC}"
fi

# Create a simple test to verify the bundle works
echo -e "${BLUE}Testing app bundle...${NC}"
if [ -x "${MACOS_DIR}/AutoRip2MKV-Mac" ]; then
    echo -e "${GREEN}✓ Executable is present and executable${NC}"
else
    echo -e "${RED}✗ Executable is missing or not executable${NC}"
    exit 1
fi

# Copy signed bundle to build directory without xattrs
echo -e "${BLUE}Copying signed bundle to build directory...${NC}"
mkdir -p "${BUILD_DIR}"
/usr/bin/ditto --noextattr --noqtn "${APP_BUNDLE}" "${FINAL_APP_BUNDLE}"
rm -rf "${WORK_DIR}"

# Show bundle information
echo -e "\n${GREEN}=== App Bundle Created Successfully ===${NC}"
echo -e "${BLUE}Location:${NC} ${FINAL_APP_BUNDLE}"
echo -e "${BLUE}Size:${NC} $(du -sh "${FINAL_APP_BUNDLE}" | cut -f1)"
echo -e "${BLUE}Bundle ID:${NC} ${BUNDLE_ID}"
echo -e "${BLUE}Version:${NC} ${VERSION}"

# Next steps
echo -e "\n${BLUE}=== Next Steps ===${NC}"
echo -e "1. Test the app: open '${FINAL_APP_BUNDLE}'"
echo -e "2. For distribution, create a DMG: scripts/create-dmg.sh"
if [ "$SHOULD_SIGN" = true ]; then
    echo -e "3. Submit for notarization: scripts/notarize-app.sh"
else
    echo -e "3. Set up code signing and notarization for distribution"
fi

echo -e "\n${GREEN}App bundle creation completed!${NC}"