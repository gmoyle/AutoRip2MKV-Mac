#!/bin/bash

# AutoRip2MKV-Mac Notarization Script
# Handles notarization with Apple for distribution outside the Mac App Store

set -e

# Configuration
APP_NAME="AutoRip2MKV-Mac"
VERSION="1.2.4"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
BUNDLE_ID="com.autorip2mkv.mac"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== AutoRip2MKV-Mac Notarization ===${NC}"

# Check for required tools
if ! command -v xcrun &> /dev/null; then
    echo -e "${RED}Error: Xcode command line tools not found${NC}"
    exit 1
fi

# Function to check notarization requirements
check_requirements() {
    echo -e "${BLUE}Checking notarization requirements...${NC}"
    
    # Load environment variables from .env file if it exists
    if [ -f ".env" ]; then
        echo -e "${GREEN}✓ Loading credentials from .env file${NC}"
        export $(grep -v '^#' .env | xargs)
    elif [ -f "developer-credentials.sh" ]; then
        echo -e "${GREEN}✓ Loading credentials from developer-credentials.sh${NC}"
        source developer-credentials.sh
    fi
    
    # Check for Apple ID credentials
    if [ -z "$APPLE_ID" ]; then
        echo -e "${YELLOW}Please set APPLE_ID environment variable${NC}"
        read -p "Enter your Apple ID email: " APPLE_ID
        export APPLE_ID
    fi
    
    if [ -z "$APPLE_ID_PASSWORD" ]; then
        echo -e "${YELLOW}Please set APPLE_ID_PASSWORD environment variable${NC}"
        echo -e "${YELLOW}Use an app-specific password from appleid.apple.com${NC}"
        read -s -p "Enter your app-specific password: " APPLE_ID_PASSWORD
        export APPLE_ID_PASSWORD
        echo
    fi
    
    if [ -z "$TEAM_ID" ]; then
        echo -e "${YELLOW}Please set TEAM_ID environment variable${NC}"
        read -p "Enter your Team ID (from Developer Account): " TEAM_ID
        export TEAM_ID
    fi
    
    echo -e "${GREEN}✓ Credentials configured${NC}"
}

# Function to notarize app bundle
notarize_app() {
    if [ ! -d "${APP_BUNDLE}" ]; then
        echo -e "${RED}Error: App bundle not found at ${APP_BUNDLE}${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Notarizing app bundle...${NC}"
    
    # Create a zip file for notarization
    ZIP_FILE="${APP_NAME}-notarization.zip"
    ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_FILE}"
    
    echo -e "${BLUE}Submitting for notarization...${NC}"
    
    # Submit for notarization
    RESULT=$(xcrun notarytool submit "${ZIP_FILE}" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait)
    
    echo "$RESULT"
    
    # Check if successful
    if echo "$RESULT" | grep -q "status: Accepted"; then
        echo -e "${GREEN}✓ Notarization successful!${NC}"
        
        # Staple the notarization
        echo -e "${BLUE}Stapling notarization ticket...${NC}"
        xcrun stapler staple "${APP_BUNDLE}"
        
        # Verify stapling
        echo -e "${BLUE}Verifying stapled ticket...${NC}"
        xcrun stapler validate "${APP_BUNDLE}"
        
        echo -e "${GREEN}✓ App bundle notarized and stapled successfully${NC}"
        
        # Clean up
        rm -f "${ZIP_FILE}"
        return 0
    else
        echo -e "${RED}✗ Notarization failed${NC}"
        rm -f "${ZIP_FILE}"
        return 1
    fi
}

# Function to notarize DMG
notarize_dmg() {
    if [ ! -f "${DMG_NAME}" ]; then
        echo -e "${RED}Error: DMG not found at ${DMG_NAME}${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Notarizing DMG...${NC}"
    
    # Submit DMG for notarization
    RESULT=$(xcrun notarytool submit "${DMG_NAME}" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait)
    
    echo "$RESULT"
    
    # Check if successful
    if echo "$RESULT" | grep -q "status: Accepted"; then
        echo -e "${GREEN}✓ DMG notarization successful!${NC}"
        
        # Staple the notarization
        echo -e "${BLUE}Stapling notarization ticket to DMG...${NC}"
        xcrun stapler staple "${DMG_NAME}"
        
        # Verify stapling
        echo -e "${BLUE}Verifying stapled DMG...${NC}"
        xcrun stapler validate "${DMG_NAME}"
        
        echo -e "${GREEN}✓ DMG notarized and stapled successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ DMG notarization failed${NC}"
        return 1
    fi
}

# Function to check existing notarization status
check_status() {
    echo -e "${BLUE}Checking current notarization status...${NC}"
    
    if [ -d "${APP_BUNDLE}" ]; then
        echo -e "${BLUE}App bundle status:${NC}"
        if xcrun stapler validate "${APP_BUNDLE}" 2>/dev/null; then
            echo -e "${GREEN}✓ App bundle is properly notarized${NC}"
        else
            echo -e "${YELLOW}○ App bundle is not notarized${NC}"
        fi
    fi
    
    if [ -f "${DMG_NAME}" ]; then
        echo -e "${BLUE}DMG status:${NC}"
        if xcrun stapler validate "${DMG_NAME}" 2>/dev/null; then
            echo -e "${GREEN}✓ DMG is properly notarized${NC}"
        else
            echo -e "${YELLOW}○ DMG is not notarized${NC}"
        fi
    fi
}

# Main script logic
case "${1:-}" in
    "app")
        check_requirements
        notarize_app
        ;;
    "dmg")
        check_requirements
        notarize_dmg
        ;;
    "both")
        check_requirements
        notarize_app && notarize_dmg
        ;;
    "status")
        check_status
        ;;
    *)
        echo -e "${BLUE}Usage: $0 {app|dmg|both|status}${NC}"
        echo
        echo -e "${YELLOW}Commands:${NC}"
        echo -e "  app    - Notarize the app bundle"
        echo -e "  dmg    - Notarize the DMG"
        echo -e "  both   - Notarize both app bundle and DMG"
        echo -e "  status - Check current notarization status"
        echo
        echo -e "${YELLOW}Environment Variables:${NC}"
        echo -e "  APPLE_ID          - Your Apple ID email"
        echo -e "  APPLE_ID_PASSWORD - App-specific password"
        echo -e "  TEAM_ID           - Your Developer Team ID"
        exit 1
        ;;
esac