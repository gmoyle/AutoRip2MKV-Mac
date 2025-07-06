#!/bin/bash

# Bundle FFmpeg Script for AutoRip2MKV-Mac
# Downloads and bundles FFmpeg binary with the application

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/.build"
FFMPEG_DIR="$BUILD_DIR/ffmpeg"
TEMP_DIR="$(mktemp -d)"

echo "🎬 AutoRip2MKV-Mac FFmpeg Bundling Script"
echo "=========================================="

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    FFMPEG_ARCH="arm64"
elif [[ "$ARCH" == "x86_64" ]]; then
    FFMPEG_ARCH="x86_64"
else
    FFMPEG_ARCH="universal"
fi

echo "📱 Detected architecture: $FFMPEG_ARCH"

# Create directories
mkdir -p "$FFMPEG_DIR"
mkdir -p "$BUILD_DIR/release"

# Download FFmpeg
echo "⬇️  Downloading FFmpeg binary..."
FFMPEG_URL="https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip"

if ! curl -L "$FFMPEG_URL" -o "$TEMP_DIR/ffmpeg.zip"; then
    echo "❌ Failed to download FFmpeg"
    exit 1
fi

echo "📦 Extracting FFmpeg..."
cd "$TEMP_DIR"
unzip -q ffmpeg.zip

# Find the extracted ffmpeg binary
FFMPEG_BINARY=$(find . -name "ffmpeg" -type f | head -1)
if [[ -z "$FFMPEG_BINARY" ]]; then
    echo "❌ Could not find ffmpeg binary in downloaded archive"
    exit 1
fi

# Copy to our ffmpeg directory
cp "$FFMPEG_BINARY" "$FFMPEG_DIR/ffmpeg"
chmod +x "$FFMPEG_DIR/ffmpeg"

# Verify the binary works
echo "🔍 Verifying FFmpeg binary..."
if ! "$FFMPEG_DIR/ffmpeg" -version >/dev/null 2>&1; then
    echo "❌ FFmpeg binary verification failed"
    exit 1
fi

# Get version info
FFMPEG_VERSION=$("$FFMPEG_DIR/ffmpeg" -version | head -1 | cut -d' ' -f3)
echo "✅ FFmpeg $FFMPEG_VERSION verified and ready"

# Create bundle info
cat > "$FFMPEG_DIR/bundle-info.txt" << EOF
FFmpeg Bundle Information
========================
Version: $FFMPEG_VERSION
Architecture: $FFMPEG_ARCH
Downloaded: $(date)
Source: $FFMPEG_URL
Binary Path: ffmpeg
Size: $(stat -f%z "$FFMPEG_DIR/ffmpeg" 2>/dev/null || stat -c%s "$FFMPEG_DIR/ffmpeg") bytes

Usage:
- This bundled FFmpeg eliminates the need for runtime downloads
- The binary is statically linked and self-contained
- Compatible with macOS 10.15+ on $FFMPEG_ARCH architecture

License:
FFmpeg is licensed under LGPL v2.1+
Source code: https://github.com/FFmpeg/FFmpeg
EOF

echo "📄 Bundle info created at: $FFMPEG_DIR/bundle-info.txt"

# Clean up
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 FFmpeg bundling complete!"
echo "📁 Binary location: $FFMPEG_DIR/ffmpeg"
echo "📋 Bundle info: $FFMPEG_DIR/bundle-info.txt"
echo ""
echo "Next steps:"
echo "1. Update build scripts to include bundled FFmpeg"
echo "2. Modify app to check for bundled FFmpeg first"
echo "3. Test the bundled version"
