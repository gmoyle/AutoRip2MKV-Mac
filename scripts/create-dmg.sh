#!/bin/bash

# AutoRip2MKV-Mac DMG Creator
# Creates a distributable DMG file with the app bundle

set -e

# Configuration
APP_NAME="AutoRip2MKV-Mac"
VERSION="1.2.4"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-v${VERSION}"
TEMP_DMG="temp_${DMG_NAME}.dmg"
FINAL_DMG="${DMG_NAME}.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== AutoRip2MKV-Mac DMG Creator ===${NC}"

# Check if app bundle exists
if [ ! -d "${APP_BUNDLE}" ]; then
    echo -e "${RED}Error: App bundle not found at ${APP_BUNDLE}${NC}"
    echo -e "${YELLOW}Run scripts/create-app-bundle.sh first${NC}"
    exit 1
fi

# Clean up any existing DMGs
echo -e "${BLUE}Cleaning up previous DMGs...${NC}"
rm -f "${TEMP_DMG}" "${FINAL_DMG}"

# Create temporary directory for DMG contents
TEMP_DIR=$(mktemp -d)
echo -e "${BLUE}Creating DMG contents in ${TEMP_DIR}...${NC}"

# Copy app bundle to temp directory
cp -R "${APP_BUNDLE}" "${TEMP_DIR}/"

# Copy documentation
if [ -f "README.md" ]; then
    cp "README.md" "${TEMP_DIR}/"
fi
if [ -f "INSTALLATION.md" ]; then
    cp "INSTALLATION.md" "${TEMP_DIR}/"
fi

# Create Applications symlink for easy installation
ln -s /Applications "${TEMP_DIR}/Applications"

# Calculate size needed (add 10MB buffer)
SIZE=$(du -sm "${TEMP_DIR}" | cut -f1)
SIZE=$((SIZE + 10))

echo -e "${BLUE}Creating DMG with ${SIZE}MB...${NC}"

# Create the DMG
hdiutil create -srcfolder "${TEMP_DIR}" -volname "${VOLUME_NAME}" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${SIZE}m "${TEMP_DMG}"

# Mount the DMG
echo -e "${BLUE}Mounting DMG for customization...${NC}"
DEVICE=$(hdiutil attach -readwrite -noverify "${TEMP_DMG}" | \
    egrep '^/dev/' | sed 1q | awk '{print $1}')

# Set DMG window properties
echo -e "${BLUE}Customizing DMG appearance...${NC}"
sleep 2

# Use AppleScript to customize the DMG window
osascript << EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 420}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        set background picture of viewOptions to file ".background:background.png"
        set position of item "${APP_NAME}.app" of container window to {160, 205}
        set position of item "Applications" of container window to {360, 205}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Unmount the DMG
echo -e "${BLUE}Finalizing DMG...${NC}"
hdiutil detach "${DEVICE}"

# Convert to final compressed format
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${FINAL_DMG}"

# Clean up
rm -f "${TEMP_DMG}"
rm -rf "${TEMP_DIR}"

# Verify the DMG
echo -e "${BLUE}Verifying DMG...${NC}"
hdiutil verify "${FINAL_DMG}"

# Show results
echo -e "\n${GREEN}=== DMG Created Successfully ===${NC}"
echo -e "${BLUE}Location:${NC} $(pwd)/${FINAL_DMG}"
echo -e "${BLUE}Size:${NC} $(du -sh "${FINAL_DMG}" | cut -f1)"

# Calculate SHA256 for verification
echo -e "${BLUE}SHA256:${NC} $(shasum -a 256 "${FINAL_DMG}" | cut -d' ' -f1)"

echo -e "\n${GREEN}DMG creation completed!${NC}"
echo -e "${YELLOW}You can now distribute ${FINAL_DMG}${NC}"