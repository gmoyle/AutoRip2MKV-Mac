#!/bin/bash

# Generate PNG versions of icons for web and documentation use
# This script converts SVG icons to PNG at common sizes

set -e

echo "🖼️ Generating PNG versions of icons..."

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

# Create assets directory if it doesn't exist
mkdir -p assets

echo "📐 Converting main icon to PNG..."

# Generate main icon at various sizes
declare -a main_sizes=(
    "16:icon-16.png"
    "32:icon-32.png"
    "64:icon-64.png"
    "128:icon-128.png"
    "256:icon-256.png"
    "512:icon-512.png"
)

for size_info in "${main_sizes[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"
    echo "  → ${size}x${size} (${filename})"
    rsvg-convert -w "$size" -h "$size" "assets/icon.svg" > "assets/$filename"
done

echo "📐 Converting simple icon to PNG..."

# Generate simple icon at various sizes
declare -a simple_sizes=(
    "16:icon-simple-16.png"
    "32:icon-simple-32.png"
    "64:icon-simple-64.png"
    "128:icon-simple-128.png"
)

for size_info in "${simple_sizes[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"
    echo "  → ${size}x${size} (${filename})"
    rsvg-convert -w "$size" -h "$size" "assets/icon-simple.svg" > "assets/$filename"
done

echo "📐 Converting logo to PNG..."

# Generate logo PNG
rsvg-convert -w 400 -h 120 "assets/logo.svg" > "assets/logo.png"
echo "  → 400x120 (logo.png)"

# Generate high-resolution version for retina displays
rsvg-convert -w 800 -h 240 "assets/logo.svg" > "assets/logo@2x.png"
echo "  → 800x240 (logo@2x.png)"

echo "✅ Successfully generated PNG versions"
echo "📁 Ready for web, documentation, and broader compatibility!"

# Show generated files
echo "📋 Generated files:"
ls -la assets/*.png | awk '{print "   " $9 " (" $5 " bytes)"}'
