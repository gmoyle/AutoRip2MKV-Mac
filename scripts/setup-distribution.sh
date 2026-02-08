#!/bin/bash

# AutoRip2MKV-Mac Distribution Setup
# Helps configure the environment for app distribution

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== AutoRip2MKV-Mac Distribution Setup ===${NC}\n"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${BLUE}🔍 Checking system prerequisites...${NC}"

if command_exists swift; then
    SWIFT_VERSION=$(swift --version | head -1 | cut -d'(' -f1)
    echo -e "${GREEN}✓ Swift: $SWIFT_VERSION${NC}"
else
    echo -e "${RED}✗ Swift not found${NC}"
    echo -e "${YELLOW}  Install Xcode Command Line Tools: xcode-select --install${NC}"
fi

if command_exists codesign; then
    echo -e "${GREEN}✓ codesign available${NC}"
else
    echo -e "${RED}✗ codesign not found${NC}"
fi

if command_exists hdiutil; then
    echo -e "${GREEN}✓ hdiutil available${NC}"
else
    echo -e "${RED}✗ hdiutil not found${NC}"
fi

if command_exists xcrun; then
    echo -e "${GREEN}✓ Xcode command line tools${NC}"
else
    echo -e "${RED}✗ Xcode command line tools not found${NC}"
fi

# Check for Developer ID certificate
echo -e "\n${BLUE}🔐 Checking code signing certificates...${NC}"
CERT_COUNT=$(security find-identity -v -p codesigning | grep -c "Developer ID Application" || true)

if [ "$CERT_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $CERT_COUNT Developer ID Application certificate(s)${NC}"
    security find-identity -v -p codesigning | grep "Developer ID Application"
else
    echo -e "${YELLOW}⚠ No Developer ID Application certificates found${NC}"
    echo -e "${YELLOW}  Download from: https://developer.apple.com/account/resources/certificates/list${NC}"
fi

# Check environment variables
echo -e "\n${BLUE}🌍 Checking environment variables...${NC}"

if [ -n "$APPLE_ID" ]; then
    echo -e "${GREEN}✓ APPLE_ID: $APPLE_ID${NC}"
else
    echo -e "${YELLOW}⚠ APPLE_ID not set${NC}"
fi

if [ -n "$APPLE_ID_PASSWORD" ]; then
    echo -e "${GREEN}✓ APPLE_ID_PASSWORD: [hidden]${NC}"
else
    echo -e "${YELLOW}⚠ APPLE_ID_PASSWORD not set${NC}"
fi

if [ -n "$TEAM_ID" ]; then
    echo -e "${GREEN}✓ TEAM_ID: $TEAM_ID${NC}"
else
    echo -e "${YELLOW}⚠ TEAM_ID not set${NC}"
fi

# Interactive setup
echo -e "\n${BLUE}⚙️ Interactive setup${NC}"

if [ -z "$APPLE_ID" ]; then
    read -p "Enter your Apple ID email (or press Enter to skip): " INPUT_APPLE_ID
    if [ -n "$INPUT_APPLE_ID" ]; then
        echo "export APPLE_ID=\"$INPUT_APPLE_ID\"" >> ~/.zshrc
        export APPLE_ID="$INPUT_APPLE_ID"
        echo -e "${GREEN}✓ APPLE_ID added to ~/.zshrc${NC}"
    fi
fi

if [ -z "$TEAM_ID" ]; then
    read -p "Enter your Team ID (or press Enter to skip): " INPUT_TEAM_ID
    if [ -n "$INPUT_TEAM_ID" ]; then
        echo "export TEAM_ID=\"$INPUT_TEAM_ID\"" >> ~/.zshrc
        export TEAM_ID="$INPUT_TEAM_ID"
        echo -e "${GREEN}✓ TEAM_ID added to ~/.zshrc${NC}"
    fi
fi

# FFmpeg check
echo -e "\n${BLUE}🎬 Checking FFmpeg...${NC}"

if command_exists ffmpeg; then
    FFMPEG_VERSION=$(ffmpeg -version | head -1 | cut -d' ' -f3)
    FFMPEG_PATH=$(which ffmpeg)
    echo -e "${GREEN}✓ FFmpeg $FFMPEG_VERSION at $FFMPEG_PATH${NC}"
else
    echo -e "${YELLOW}⚠ FFmpeg not found${NC}"
    echo -e "${YELLOW}  Install with: brew install ffmpeg${NC}"
fi

# Project structure check
echo -e "\n${BLUE}📁 Checking project structure...${NC}"

if [ -f "Package.swift" ]; then
    echo -e "${GREEN}✓ Package.swift found${NC}"
else
    echo -e "${RED}✗ Package.swift not found${NC}"
fi

if [ -f "Sources/AutoRip2MKV-Mac/main.swift" ]; then
    echo -e "${GREEN}✓ Source files found${NC}"
else
    echo -e "${RED}✗ Source files not found${NC}"
fi

if [ -f "AutoRip2MKV.entitlements" ]; then
    echo -e "${GREEN}✓ Entitlements file found${NC}"
else
    echo -e "${RED}✗ Entitlements file not found${NC}"
fi

# Scripts check
echo -e "\n${BLUE}📜 Checking distribution scripts...${NC}"

SCRIPTS=("create-app-bundle.sh" "create-dmg.sh" "notarize-app.sh" "distribute.sh")
for script in "${SCRIPTS[@]}"; do
    if [ -x "scripts/$script" ]; then
        echo -e "${GREEN}✓ scripts/$script (executable)${NC}"
    elif [ -f "scripts/$script" ]; then
        chmod +x "scripts/$script"
        echo -e "${YELLOW}✓ scripts/$script (made executable)${NC}"
    else
        echo -e "${RED}✗ scripts/$script not found${NC}"
    fi
done

# Summary and next steps
echo -e "\n${BLUE}📋 Setup Summary${NC}"
echo -e "${BLUE}=================${NC}"

ISSUES=0

# Count issues
if ! command_exists swift; then ((ISSUES++)); fi
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then ((ISSUES++)); fi
if [ -z "$APPLE_ID" ]; then ((ISSUES++)); fi
if [ -z "$APPLE_ID_PASSWORD" ]; then ((ISSUES++)); fi
if [ -z "$TEAM_ID" ]; then ((ISSUES++)); fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}🎉 Setup complete! Ready for distribution.${NC}"
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "  1. Run: ${YELLOW}./scripts/distribute.sh${NC}"
    echo -e "  2. Test the generated app bundle"
    echo -e "  3. Distribute the signed DMG"
else
    echo -e "${YELLOW}⚠ $ISSUES issue(s) need attention:${NC}"
    
    if ! command_exists swift; then
        echo -e "  • Install Xcode Command Line Tools"
    fi
    
    if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        echo -e "  • Install Developer ID Application certificate"
    fi
    
    if [ -z "$APPLE_ID" ]; then
        echo -e "  • Set APPLE_ID environment variable"
    fi
    
    if [ -z "$APPLE_ID_PASSWORD" ]; then
        echo -e "  • Set APPLE_ID_PASSWORD (app-specific password)"
    fi
    
    if [ -z "$TEAM_ID" ]; then
        echo -e "  • Set TEAM_ID from Apple Developer account"
    fi
    
    echo -e "\n${BLUE}Run this script again after addressing the issues.${NC}"
fi

echo -e "\n${BLUE}For detailed help, see: DISTRIBUTION_GUIDE.md${NC}"