#!/bin/bash
# Bundle decryption libraries (libdvdcss & libaacs) into app bundle
# This ensures the app can run standalone without requiring Homebrew installations

set -e

echo "🔐 Bundling Decryption Libraries..."

# Detect architecture and set paths
if [[ $(uname -m) == "arm64" ]]; then
    HOMEBREW_PREFIX="/opt/homebrew"
else
    HOMEBREW_PREFIX="/usr/local"
fi

# Library paths
LIBDVDCSS_PATH="$HOMEBREW_PREFIX/opt/libdvdcss/lib/libdvdcss.2.dylib"
LIBAACS_PATH="$HOMEBREW_PREFIX/opt/libaacs/lib/libaacs.0.dylib"

# App bundle path
APP_BUNDLE="build/AutoRip2MKV.app"
FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App bundle not found at $APP_BUNDLE"
    echo "   Run the build script first: ./scripts/build-with-bundled-ffmpeg.sh"
    exit 1
fi

# Create Frameworks directory if it doesn't exist
mkdir -p "$FRAMEWORKS_DIR"

# Function to bundle a library
bundle_library() {
    local lib_path="$1"
    local lib_name=$(basename "$lib_path")
    
    if [ ! -f "$lib_path" ]; then
        echo "⚠️  Library not found: $lib_path"
        echo "   Install with: brew install $(basename $(dirname $(dirname $lib_path)))"
        return 1
    fi
    
    echo "📦 Bundling $lib_name..."
    
    # Copy library to Frameworks directory
    cp "$lib_path" "$FRAMEWORKS_DIR/"
    
    # Update install name to use @rpath
    install_name_tool -id "@rpath/$lib_name" "$FRAMEWORKS_DIR/$lib_name"
    
    # Update executable to look for library in  @rpath
    install_name_tool -change \
        "$lib_path" \
        "@rpath/$lib_name" \
        "$APP_BUNDLE/Contents/MacOS/AutoRip2MKV" || true
    
    # Also update the library to reference any dependencies in @rpath
    for dep in $(otool -L "$FRAMEWORKS_DIR/$lib_name" | grep "$HOMEBREW_PREFIX" | awk '{print $1}'); do
        dep_name=$(basename "$dep")
        install_name_tool -change \
            "$dep" \
            "@rpath/$dep_name" \
            "$FRAMEWORKS_DIR/$lib_name" || true
    done
    
    echo "✅ $lib_name bundled successfully"
}

# Bundle libdvdcss
bundle_library "$LIBDVDCSS_PATH"

# Bundle libaacs
bundle_library "$LIBAACS_PATH"

# Bundle dependencies of libaacs (libgpg-error, libgcrypt)
LIBGPGERROR_PATH="$HOMEBREW_PREFIX/opt/libgpg-error/lib/libgpg-error.0.dylib"
LIBGCRYPT_PATH="$HOMEBREW_PREFIX/opt/libgcrypt/lib/libgcrypt.20.dylib"

bundle_library "$LIBGPGERROR_PATH" || echo "⚠️  libgpg-error not bundled (optional)"
bundle_library "$LIBGCRYPT_PATH" || echo "⚠️  libgcrypt not bundled (optional)"

# Add @rpath pointing to Frameworks directory
echo "🔗 Setting up runtime library paths..."
install_name_tool -add_rpath "@executable_path/../Frameworks" \
    "$APP_BUNDLE/Contents/MacOS/AutoRip2MKV" 2>/dev/null || \
    echo "   (rpath already exists)"

echo ""
echo "✅ Decryption libraries bundled successfully!"
echo ""
echo "Bundled libraries:"
ls -lh "$FRAMEWORKS_DIR"

echo ""
echo "📋 Verify with:"
echo "   otool -L build/AutoRip2MKV.app/Contents/MacOS/AutoRip2MKV"
echo ""
echo "🎉 App is now standalone and ready for distribution!"
