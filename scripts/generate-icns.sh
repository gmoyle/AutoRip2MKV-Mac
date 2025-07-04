#!/bin/bash

# Generate macOS .icns file from SVG icon
# This script converts the SVG icon to PNG at various sizes and creates an .icns file

set -e

echo "🎨 Generating macOS .icns file from SVG icon..."

# Check if we have the required tools
if ! command -v rsvg-convert &> /dev/null; then
    echo "❌ rsvg-convert not found. Installing librsvg..."
    if command -v brew &> /dev/null; then
        brew install librsvg
    else
        echo "Please install librsvg: brew install librsvg"
        exit 1
    fi
fi

# Create temporary directory for icon generation
TEMP_DIR="$(mktemp -d)"
ICONSET_DIR="$TEMP_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

# Source SVG file
SVG_FILE="assets/icon.svg"

# Check if source SVG exists
if [ ! -f "$SVG_FILE" ]; then
    echo "❌ Source SVG file not found: $SVG_FILE"
    exit 1
fi

echo "📐 Converting SVG to PNG at various sizes..."

# Generate PNG files at required sizes for macOS icons
# Standard sizes for macOS app icons
declare -a sizes=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

for size_info in "${sizes[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"
    echo "  → ${size}x${size} (${filename})"
    rsvg-convert -w "$size" -h "$size" "$SVG_FILE" > "$ICONSET_DIR/$filename"
done

echo "🔧 Creating .icns file..."

# Create the .icns file using iconutil
iconutil -c icns "$ICONSET_DIR" -o "assets/AppIcon.icns"

# Clean up
rm -rf "$TEMP_DIR"

echo "✅ Successfully created assets/AppIcon.icns"
echo "📁 Icon is ready for macOS app bundle!"

# Display file info
if [ -f "assets/AppIcon.icns" ]; then
    file_size=$(du -h "assets/AppIcon.icns" | cut -f1)
    echo "📊 File size: $file_size"
fi
