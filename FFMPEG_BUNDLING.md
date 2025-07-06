# FFmpeg Bundling Documentation

## Overview

AutoRip2MKV-Mac includes a bundled FFmpeg binary for completely self-contained operation. This eliminates the need for users to install FFmpeg separately and ensures consistent behavior across all installations.

## What's Bundled

- **FFmpeg Version**: 7.1.1-tessus
- **Architecture**: Universal binary (ARM64 + x86_64)
- **Source**: https://evermeet.cx/ffmpeg/
- **Size**: ~76MB
- **Location**: `AutoRip2MKV.app/Contents/Resources/ffmpeg`

## Benefits

### For Users
- ✅ **No downloads required** - Works immediately after installation
- ✅ **Offline operation** - No internet connection needed for ripping
- ✅ **Consistent experience** - Same FFmpeg version for all users
- ✅ **No dependency conflicts** - Isolated from system FFmpeg installations
- ✅ **Professional quality** - Tessus builds with comprehensive codec support

### For Developers
- ✅ **Simplified testing** - Consistent FFmpeg environment
- ✅ **Reduced support burden** - No FFmpeg installation issues
- ✅ **Predictable behavior** - Known codec support and features
- ✅ **Easy distribution** - Single app bundle contains everything

## Technical Implementation

### Path Resolution Priority

The application searches for FFmpeg in this order:

1. **Bundled Binary** (Primary): `Bundle.main.bundlePath/Contents/Resources/ffmpeg`
2. **Application Support** (Fallback): `~/Library/Application Support/AutoRip2MKV-Mac/ffmpeg`
3. **System PATH** (Legacy): Standard system FFmpeg installation

### Code Implementation

```swift
func getFFmpegExecutablePath() -> String? {
    // 1. Check bundled FFmpeg first
    if let bundledPath = getBundledFFmpegPath(), 
       FileManager.default.fileExists(atPath: bundledPath) {
        return bundledPath
    }
    
    // 2. Check Application Support installation
    let installedPath = getInstalledFFmpegPath()
    if FileManager.default.fileExists(atPath: installedPath) {
        return installedPath
    }
    
    // 3. Check system PATH as final fallback
    return getSystemFFmpegPath()
}
```

## Building with Bundled FFmpeg

### Using the Enhanced Build Script

```bash
# Run the complete build process with FFmpeg bundling
./scripts/build-with-bundled-ffmpeg.sh
```

This script:
1. Downloads FFmpeg binary (if not already cached)
2. Verifies the binary integrity
3. Builds the Swift application
4. Creates app bundle structure
5. Copies FFmpeg to `Contents/Resources/`
6. Signs the complete app bundle
7. Creates distribution packages (DMG, ZIP)

### Manual Bundling Process

If you prefer to bundle FFmpeg manually:

```bash
# 1. Download and prepare FFmpeg
./scripts/bundle-ffmpeg.sh

# 2. Build the application
swift build --configuration release

# 3. Create app bundle
mkdir -p MyApp.app/Contents/{MacOS,Resources}

# 4. Copy executable and FFmpeg
cp .build/release/AutoRip2MKV-Mac MyApp.app/Contents/MacOS/AutoRip2MKV
cp .build/ffmpeg/ffmpeg MyApp.app/Contents/Resources/ffmpeg
chmod +x MyApp.app/Contents/Resources/ffmpeg

# 5. Create Info.plist and sign
# (see build-with-bundled-ffmpeg.sh for complete example)
```

## FFmpeg Features Included

The bundled FFmpeg binary includes comprehensive codec support:

### Video Codecs
- **H.264 (libx264)** - Most compatible
- **H.265 (libx265)** - Better compression
- **AV1 (libaom-av1)** - Next-generation codec
- **VP9** - Open-source alternative

### Audio Codecs
- **AAC** - High-quality lossy
- **AC3 (Dolby Digital)** - DVD/Blu-ray standard
- **DTS** - High-quality surround
- **FLAC** - Lossless compression

### Container Formats
- **MKV (Matroska)** - Primary output format
- **MP4** - Alternative container
- **AVI** - Legacy support

### Additional Features
- **Hardware acceleration** (when available)
- **Subtitle support** (ASS, SRT, VobSub)
- **Chapter preservation**
- **Metadata handling**
- **Multiple audio tracks**

## Licensing Considerations

### FFmpeg License
- FFmpeg is licensed under **LGPL v2.1+**
- Bundling is permitted under LGPL terms
- No source code changes to FFmpeg
- LGPL compliance through dynamic linking equivalent

### Attribution Requirements
- FFmpeg attribution included in app about section
- License information in bundled documentation
- Source availability through evermeet.cx

### Legal Compliance
```
This application uses FFmpeg (https://ffmpeg.org/) licensed under the LGPL v2.1+.
FFmpeg binary provided by evermeet.cx with comprehensive codec support.
Source code and build information: https://evermeet.cx/ffmpeg/
```

## Security and Verification

### Binary Verification
The bundling script verifies FFmpeg integrity:

```bash
# Check executable permissions
if [ -x "$FFMPEG_PATH" ]; then
    echo "✅ FFmpeg binary is executable"
fi

# Verify version and functionality
FFMPEG_VERSION=$("$FFMPEG_PATH" -version 2>&1 | head -1)
echo "📋 FFmpeg version: $FFMPEG_VERSION"

# Test basic operation
if "$FFMPEG_PATH" -f lavfi -i testsrc=duration=1:rate=1 -f null - &>/dev/null; then
    echo "✅ FFmpeg functionality verified"
fi
```

### Code Signing Integration
The entire app bundle (including FFmpeg) is code-signed:

```bash
# Sign the complete app bundle
codesign --force --deep --sign - "AutoRip2MKV.app"
```

## Troubleshooting

### Common Issues

**FFmpeg not found**
```bash
# Check if FFmpeg is present in bundle
ls -la /Applications/AutoRip2MKV.app/Contents/Resources/ffmpeg

# Verify executable permissions
chmod +x /Applications/AutoRip2MKV.app/Contents/Resources/ffmpeg
```

**Permission denied errors**
```bash
# Remove quarantine attributes
xattr -d com.apple.quarantine /Applications/AutoRip2MKV.app
```

**Performance issues**
- Hardware acceleration automatically detected
- CPU usage normal for video encoding
- Monitor system temperature during intensive operations

### Debug Information

Enable debug logging to see FFmpeg path resolution:

```swift
if isDebugMode {
    print("Checking FFmpeg paths:")
    print("Bundled: \(getBundledFFmpegPath() ?? "not found")")
    print("Installed: \(getInstalledFFmpegPath())")
    print("System: \(getSystemFFmpegPath() ?? "not found")")
}
```

## Development Notes

### Testing Bundled FFmpeg

```bash
# Test the bundled binary directly
/Applications/AutoRip2MKV.app/Contents/Resources/ffmpeg -version

# Verify codec support
/Applications/AutoRip2MKV.app/Contents/Resources/ffmpeg -codecs | grep -i h264

# Test conversion functionality
/Applications/AutoRip2MKV.app/Contents/Resources/ffmpeg \
  -f lavfi -i testsrc=duration=5:rate=30 \
  -c:v libx264 -t 5 test_output.mkv
```

### CI/CD Integration

For automated builds and testing:

```bash
# In CI environment, build with bundled FFmpeg
if [ "$CI" = "true" ]; then
    ./scripts/build-with-bundled-ffmpeg.sh
    
    # Verify bundle integrity
    test -x ".build/release/AutoRip2MKV.app/Contents/Resources/ffmpeg"
    
    # Test functionality
    .build/release/AutoRip2MKV.app/Contents/Resources/ffmpeg -version
fi
```

## Future Considerations

### Updates and Maintenance
- **FFmpeg updates**: Monitor evermeet.cx for new releases
- **Security patches**: Update bundled binary when needed
- **Codec improvements**: Newer versions may include better codecs
- **Architecture support**: Future Apple Silicon optimizations

### Alternative Approaches
- **Native Swift bindings**: Potential future implementation
- **Modular framework**: Component-based architecture
- **Dynamic loading**: Runtime codec selection

## References

- **FFmpeg Project**: https://ffmpeg.org/
- **Evermeet Builds**: https://evermeet.cx/ffmpeg/
- **LGPL License**: https://www.gnu.org/licenses/lgpl-2.1.html
- **macOS App Bundling**: https://developer.apple.com/documentation/bundleresources

---

*This documentation covers FFmpeg bundling implementation in AutoRip2MKV-Mac v1.3.0+*
