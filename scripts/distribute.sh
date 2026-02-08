#!/bin/bash

# AutoRip2MKV-Mac Master Distribution Builder
# Builds, signs, and packages the complete distribution

set -e

# Configuration
APP_NAME="AutoRip2MKV-Mac"
VERSION="1.2.4"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ASCII Art Header
cat << "EOF"
    ___         __       ____  _      ___   __  __ _  ____     __  ___          
   /   | __  __/ /_____/  _/ / ___  |__ \ /  |/  // |/ /\   / / /  |/ /   ____
  / /| |/ / / / __/ __ \/ // / __ \/  _/ / /|_/ //    /  \ / / / /|  / | / /
 / ___ / /_/ / /_/ /_/ // // / /_/ / /___/ /  / // /|  |   V / / ___ / /| |/ /
/_/  |_\__,_/\__/\____/___/_/ .___/____/_/  /_//_/ |_|    /_/_/_/  |_/ |___/ 
                           /_/                                               
EOF

echo -e "${PURPLE}=== AutoRip2MKV-Mac Distribution Builder v${VERSION} ===${NC}\n"

# Functions
show_help() {
    echo -e "${BLUE}Usage: $0 [OPTIONS]${NC}"
    echo
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  --clean-only     Clean build artifacts and exit"
    echo -e "  --no-notarize    Skip notarization step"
    echo -e "  --debug          Build with debug information"
    echo -e "  --help           Show this help"
    echo
    echo -e "${YELLOW}Environment Variables:${NC}"
    echo -e "  APPLE_ID         Your Apple ID for notarization"
    echo -e "  APPLE_ID_PASSWORD App-specific password"
    echo -e "  TEAM_ID          Your Developer Team ID"
    echo
    echo -e "${YELLOW}Distribution Steps:${NC}"
    echo -e "  1. Clean previous builds"
    echo -e "  2. Build Swift executable"
    echo -e "  3. Create app bundle"
    echo -e "  4. Code sign with Developer ID"
    echo -e "  5. Create DMG installer"
    echo -e "  6. Notarize for distribution"
    echo -e "  7. Generate distribution summary"
}

check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Load environment variables from .env file if it exists
    if [ -f ".env" ]; then
        echo -e "${GREEN}✓ Loading credentials from .env file${NC}"
        export $(grep -v '^#' .env | xargs)
    elif [ -f "developer-credentials.sh" ]; then
        echo -e "${GREEN}✓ Loading credentials from developer-credentials.sh${NC}"
        source developer-credentials.sh
    fi
    
    local errors=0
    
    # Check for Xcode Command Line Tools
    if ! command -v swift &> /dev/null; then
        echo -e "${RED}✗ Swift not found - install Xcode Command Line Tools${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✓ Swift $(swift --version | head -1 | cut -d' ' -f4)${NC}"
    fi
    
    # Check for codesign
    if ! command -v codesign &> /dev/null; then
        echo -e "${RED}✗ codesign not found${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✓ codesign available${NC}"
    fi
    
    # Check for Developer ID certificate
    if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        echo -e "${GREEN}✓ Developer ID Application certificate found${NC}"
    else
        echo -e "${YELLOW}⚠ No Developer ID Application certificate found${NC}"
        echo -e "${YELLOW}  App will be built but cannot be distributed outside Mac App Store${NC}"
    fi
    
    # Check for hdiutil
    if ! command -v hdiutil &> /dev/null; then
        echo -e "${RED}✗ hdiutil not found${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✓ hdiutil available for DMG creation${NC}"
    fi
    
    # Check source files
    if [ ! -f "Sources/AutoRip2MKV-Mac/main.swift" ]; then
        echo -e "${RED}✗ Source files not found${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✓ Source files present${NC}"
    fi
    
    if [ $errors -gt 0 ]; then
        echo -e "${RED}❌ $errors prerequisite(s) missing${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites satisfied${NC}\n"
}

clean_build() {
    echo -e "${BLUE}🧹 Cleaning build artifacts...${NC}"
    
    # Remove Swift build artifacts
    rm -rf .build
    
    # Remove app bundle
    rm -rf build
    
    # Remove distribution files
    rm -f AutoRip2MKV-Mac-v*.dmg
    rm -f AutoRip2MKV-Mac-v*.zip
    rm -f AutoRip2MKV-Mac-notarization.zip
    
    echo -e "${GREEN}✓ Build artifacts cleaned${NC}\n"
}

build_executable() {
    echo -e "${BLUE}🔨 Building Swift executable...${NC}"
    
    if [ "$DEBUG_BUILD" = true ]; then
        swift build --product AutoRip2MKV-Mac
    else
        swift build -c release --product AutoRip2MKV-Mac
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Executable built successfully${NC}\n"
    else
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi
}

create_bundle() {
    echo -e "${BLUE}📦 Creating application bundle...${NC}"
    
    if [ -x "scripts/create-app-bundle.sh" ]; then
        chmod +x scripts/create-app-bundle.sh
        ./scripts/create-app-bundle.sh
    else
        echo -e "${RED}❌ App bundle creation script not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ App bundle created${NC}\n"
}

create_installer() {
    echo -e "${BLUE}💿 Creating DMG installer...${NC}"
    
    if [ -x "scripts/create-dmg.sh" ]; then
        chmod +x scripts/create-dmg.sh
        ./scripts/create-dmg.sh
    else
        echo -e "${RED}❌ DMG creation script not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ DMG installer created${NC}\n"
}

notarize_distribution() {
    if [ "$SKIP_NOTARIZE" = true ]; then
        echo -e "${YELLOW}⏭ Skipping notarization${NC}\n"
        return
    fi
    
    echo -e "${BLUE}🔐 Notarizing for distribution...${NC}"
    
    # Check if we have the required environment variables
    if [ -z "$APPLE_ID" ] || [ -z "$APPLE_ID_PASSWORD" ] || [ -z "$TEAM_ID" ]; then
        echo -e "${YELLOW}⚠ Notarization credentials not set${NC}"
        echo -e "${YELLOW}  Set APPLE_ID, APPLE_ID_PASSWORD, and TEAM_ID environment variables${NC}"
        echo -e "${YELLOW}  Skipping notarization...${NC}\n"
        return
    fi
    
    if [ -x "scripts/notarize-app.sh" ]; then
        chmod +x scripts/notarize-app.sh
        ./scripts/notarize-app.sh both
    else
        echo -e "${RED}❌ Notarization script not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Distribution notarized${NC}\n"
}

generate_summary() {
    echo -e "${PURPLE}📋 Distribution Summary${NC}"
    echo -e "${BLUE}===========================================${NC}"
    
    local app_bundle="build/AutoRip2MKV-Mac.app"
    local dmg_file="AutoRip2MKV-Mac-v${VERSION}.dmg"
    
    if [ -d "$app_bundle" ]; then
        echo -e "${GREEN}✓ App Bundle:${NC} $app_bundle"
        echo -e "  ${BLUE}Size:${NC} $(du -sh "$app_bundle" | cut -f1)"
        
        if xcrun stapler validate "$app_bundle" 2>/dev/null; then
            echo -e "  ${GREEN}Status: Notarized ✓${NC}"
        else
            echo -e "  ${YELLOW}Status: Not notarized${NC}"
        fi
    fi
    
    if [ -f "$dmg_file" ]; then
        echo -e "${GREEN}✓ DMG Installer:${NC} $dmg_file"
        echo -e "  ${BLUE}Size:${NC} $(du -sh "$dmg_file" | cut -f1)"
        echo -e "  ${BLUE}SHA256:${NC} $(shasum -a 256 "$dmg_file" | cut -d' ' -f1)"
        
        if xcrun stapler validate "$dmg_file" 2>/dev/null; then
            echo -e "  ${GREEN}Status: Notarized ✓${NC}"
        else
            echo -e "  ${YELLOW}Status: Not notarized${NC}"
        fi
    fi
    
    echo -e "\n${BLUE}Distribution files created in:${NC} $(pwd)"
    echo -e "${GREEN}🎉 Distribution build complete!${NC}"
}

# Parse command line arguments
DEBUG_BUILD=false
SKIP_NOTARIZE=false
CLEAN_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean-only)
            CLEAN_ONLY=true
            shift
            ;;
        --no-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
        --debug)
            DEBUG_BUILD=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
echo -e "${BLUE}Starting distribution build for ${APP_NAME} v${VERSION}${NC}\n"

# Always clean first
clean_build

if [ "$CLEAN_ONLY" = true ]; then
    echo -e "${GREEN}✅ Clean completed${NC}"
    exit 0
fi

# Make scripts executable
chmod +x scripts/*.sh

# Execute build pipeline
check_prerequisites
build_executable
create_bundle
create_installer
notarize_distribution
generate_summary

echo -e "\n${GREEN}🚀 Ready for distribution!${NC}"