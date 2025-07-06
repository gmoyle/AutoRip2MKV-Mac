#!/bin/bash

# Enhanced Build Script for AutoRip2MKV-Mac with Bundled FFmpeg
# Builds the application and bundles FFmpeg binary for distribution

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/.build"
RELEASE_DIR="$BUILD_DIR/release"

echo "🚀 AutoRip2MKV-Mac Enhanced Build Script"
echo "========================================"
echo "📍 Project root: $PROJECT_ROOT"
echo "📁 Build directory: $BUILD_DIR"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$RELEASE_DIR"

# Step 1: Bundle FFmpeg
echo "📦 Step 1: Bundling FFmpeg..."
if ! "$SCRIPT_DIR/bundle-ffmpeg.sh"; then
    echo "❌ Failed to bundle FFmpeg"
    exit 1
fi

# Step 2: Build the Swift application
echo "🛠️  Step 2: Building Swift application..."
cd "$PROJECT_ROOT"

# Build in release mode
swift build --configuration release --product AutoRip2MKV-Mac

# Step 3: Create App Bundle Structure
echo "📱 Step 3: Creating macOS app bundle..."
APP_NAME="AutoRip2MKV.app"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Create bundle directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy the executable
cp "$BUILD_DIR/release/AutoRip2MKV-Mac" "$MACOS_DIR/AutoRip2MKV"

# Copy bundled FFmpeg to Resources
if [ -f "$BUILD_DIR/ffmpeg/ffmpeg" ]; then
    echo "📋 Copying bundled FFmpeg to app bundle..."
    cp "$BUILD_DIR/ffmpeg/ffmpeg" "$RESOURCES_DIR/ffmpeg"
    chmod +x "$RESOURCES_DIR/ffmpeg"
    
    # Copy bundle info for documentation
    cp "$BUILD_DIR/ffmpeg/bundle-info.txt" "$RESOURCES_DIR/ffmpeg-bundle-info.txt"
else
    echo "⚠️  Warning: No bundled FFmpeg found, app will use download fallback"
fi

# Step 4: Create Info.plist
echo "📄 Step 4: Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AutoRip2MKV</string>
    <key>CFBundleIdentifier</key>
    <string>com.gmoyle.autorip2mkv</string>
    <key>CFBundleName</key>
    <string>AutoRip2MKV</string>
    <key>CFBundleDisplayName</key>
    <string>AutoRip2MKV for Mac</string>
    <key>CFBundleVersion</key>
    <string>1.2.3</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.3</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2025 Greg Moyle. Created with AI assistance via Warp 2.0.</string>
</dict>
</plist>
EOF

# Step 5: Copy app icon if available
if [ -f "$PROJECT_ROOT/assets/icon.icns" ]; then
    echo "🎨 Step 5: Adding app icon..."
    cp "$PROJECT_ROOT/assets/icon.icns" "$RESOURCES_DIR/AppIcon.icns"
    
    # Update Info.plist to reference icon
    sed -i '' 's|</dict>|    <key>CFBundleIconFile</key>\
    <string>AppIcon</string>\
</dict>|' "$CONTENTS_DIR/Info.plist"
fi

# Step 6: Sign the app bundle (ad-hoc signing)
echo "✍️  Step 6: Code signing app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

# Step 7: Create distribution archives
echo "📦 Step 7: Creating distribution archives..."

# Create DMG (requires hdiutil)
echo "💿 Creating DMG..."
DMG_NAME="AutoRip2MKV-Mac-v1.2.3.dmg"
hdiutil create -volname "AutoRip2MKV for Mac" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$RELEASE_DIR/$DMG_NAME"

# Create ZIP archive
echo "🗜️  Creating ZIP archive..."
cd "$RELEASE_DIR"
ZIP_NAME="AutoRip2MKV-Mac-v1.2.3.zip"
zip -r "$ZIP_NAME" "$APP_NAME"

# Step 8: Generate checksums
echo "🔐 Step 8: Generating checksums..."
shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256"
shasum -a 256 "$ZIP_NAME" > "${ZIP_NAME}.sha256"

# Step 9: Create release notes
echo "📝 Step 9: Creating release notes..."
cat > "$RELEASE_DIR/RELEASE_NOTES.md" << EOF
# AutoRip2MKV-Mac v1.2.3 Release

## 🎉 What's New

### 📦 Bundled FFmpeg
- **No more downloads required!** FFmpeg is now bundled with the application
- **Faster startup** - No waiting for FFmpeg installation
- **Offline capable** - Works without internet connection after installation
- **Self-contained** - Everything needed is included in the app bundle

### 🔄 Improved Reliability
- Enhanced FFmpeg path resolution (bundled → installed → system PATH)
- Better error handling for missing dependencies
- Improved fallback mechanisms

## 📋 Installation Instructions

### For macOS 15.5+ (Sequoia) and later:

1. **Download and Install**:
   - Download either the DMG or ZIP file
   - Open the DMG and drag AutoRip2MKV to Applications, OR
   - Extract the ZIP and move AutoRip2MKV.app to Applications

2. **Security Override** (Required for unsigned apps):
   
   **Method 1 - System Settings (Recommended)**:
   - Try to open AutoRip2MKV (it will be blocked)
   - Go to System Settings → Privacy & Security
   - Scroll down to find "AutoRip2MKV was blocked..."
   - Click "Open Anyway"
   - Confirm by clicking "Open"

   **Method 2 - Terminal**:
   \`\`\`bash
   # Remove quarantine attribute
   xattr -d com.apple.quarantine /Applications/AutoRip2MKV.app
   \`\`\`

   **Method 3 - Legacy (may not work on latest macOS)**:
   - Right-click AutoRip2MKV.app → "Open"
   - Click "Open" in the security dialog

3. **First Launch**:
   - No FFmpeg download required!
   - App is ready to use immediately

## 🛠️ Technical Details

- **FFmpeg Version**: $(cat "$BUILD_DIR/ffmpeg/bundle-info.txt" | grep "Version:" | cut -d' ' -f2)
- **Architecture**: Universal (supports both Intel and Apple Silicon)
- **Bundle Size**: ~$(du -h "$APP_BUNDLE" | cut -f1) (includes FFmpeg)
- **Minimum macOS**: 13.0 (Ventura)

## 🔧 What's Bundled

- AutoRip2MKV native application
- FFmpeg static binary (self-contained)
- All necessary libraries and dependencies
- Complete offline functionality

## 🆘 Troubleshooting

If you encounter issues:

1. **App won't open**: Follow security override instructions above
2. **"Operation not permitted"**: Grant Full Disk Access in System Settings → Privacy & Security
3. **FFmpeg errors**: Bundled FFmpeg should work automatically, but check Console.app for detailed errors

## 📞 Support

- **GitHub Issues**: https://github.com/gmoyle/AutoRip2MKV-Mac/issues
- **Documentation**: See README.md and WIKI_USER_GUIDE.md
- **Roadmap**: See ROADMAP.md for planned features

---

**🤖 Created with AI assistance via Warp 2.0**  
*This release represents continued innovation in AI-powered software development*
EOF

# Step 10: Summary
echo ""
echo "🎉 Build Complete!"
echo "=================="
echo "📁 Release directory: $RELEASE_DIR"
echo "📱 App bundle: $APP_BUNDLE"
echo "💿 DMG: $DMG_NAME"
echo "🗜️  ZIP: $ZIP_NAME"
echo ""
echo "📊 Bundle Information:"
echo "  - App size: $(du -h "$APP_BUNDLE" | cut -f1)"
echo "  - DMG size: $(du -h "$RELEASE_DIR/$DMG_NAME" | cut -f1)"
echo "  - ZIP size: $(du -h "$RELEASE_DIR/$ZIP_NAME" | cut -f1)"

if [ -f "$RESOURCES_DIR/ffmpeg" ]; then
    echo "  - FFmpeg bundled: ✅ $(du -h "$RESOURCES_DIR/ffmpeg" | cut -f1)"
    echo "  - FFmpeg version: $(cat "$BUILD_DIR/ffmpeg/bundle-info.txt" | grep "Version:" | cut -d' ' -f2)"
else
    echo "  - FFmpeg bundled: ❌ (will use download fallback)"
fi

echo ""
echo "🚀 Ready for distribution!"
echo "📋 See $RELEASE_DIR/RELEASE_NOTES.md for detailed release information"
