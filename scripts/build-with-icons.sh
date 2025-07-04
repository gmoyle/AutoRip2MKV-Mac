#!/bin/bash

# Build AutoRip2MKV with icons integrated
# This script generates all icon assets and builds the application

set -e

echo "🚀 Building AutoRip2MKV-Mac with integrated icons..."

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Please run this script from the project root directory"
    exit 1
fi

# Generate icon assets
echo "🎨 Generating icon assets..."

# Generate PNG versions (if rsvg-convert is available)
if command -v rsvg-convert &> /dev/null; then
    echo "📐 Converting icons to PNG..."
    ./scripts/generate-png.sh
    
    echo "📱 Generating .icns file for macOS..."
    ./scripts/generate-icns.sh
else
    echo "⚠️  rsvg-convert not available. Skipping PNG/ICNS generation."
    echo "   Install with: brew install librsvg"
fi

# Build the Swift package
echo "🔨 Building Swift package..."
swift build --configuration release

# Create application bundle structure
echo "📦 Creating application bundle..."
APP_NAME="AutoRip2MKV"
BUILD_DIR=".build/release"
BUNDLE_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Create bundle directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "${BUILD_DIR}/AutoRip2MKV-Mac" "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
cp "Info.plist" "${CONTENTS_DIR}/"

# Copy icon assets if they exist
if [ -f "assets/AppIcon.icns" ]; then
    cp "assets/AppIcon.icns" "${RESOURCES_DIR}/"
    echo "✅ Included AppIcon.icns in bundle"
fi

# Copy additional resources
if [ -d "assets" ]; then
    cp -r "assets" "${RESOURCES_DIR}/"
    echo "✅ Included assets directory in bundle"
fi

# Make executable
chmod +x "${MACOS_DIR}/${APP_NAME}"

echo "✅ Application bundle created: ${BUNDLE_DIR}"
echo "📊 Bundle size: $(du -sh "$BUNDLE_DIR" | cut -f1)"

# Show bundle structure
echo "📁 Bundle structure:"
find "$BUNDLE_DIR" -type f | head -20 | sed 's/^/   /'

# Create DMG if hdiutil is available (macOS only)
if command -v hdiutil &> /dev/null; then
    echo "💿 Creating DMG installer..."
    DMG_NAME="${APP_NAME}-$(date +%Y%m%d).dmg"
    
    # Create temporary DMG directory
    DMG_DIR="${BUILD_DIR}/dmg"
    mkdir -p "$DMG_DIR"
    cp -r "$BUNDLE_DIR" "$DMG_DIR/"
    
    # Create DMG
    hdiutil create -srcfolder "$DMG_DIR" -format UDZO -o "${BUILD_DIR}/${DMG_NAME}"
    echo "✅ DMG created: ${BUILD_DIR}/${DMG_NAME}"
    
    # Clean up
    rm -rf "$DMG_DIR"
fi

echo ""
echo "🎉 Build completed successfully!"
echo "📱 Application: ${BUNDLE_DIR}"
if [ -f "${BUILD_DIR}/${DMG_NAME}" ]; then
    echo "💿 Installer: ${BUILD_DIR}/${DMG_NAME}"
fi
echo ""
echo "🚀 Ready for distribution!"
