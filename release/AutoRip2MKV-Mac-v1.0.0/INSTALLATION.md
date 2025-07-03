# AutoRip2MKV-Mac Installation Guide

## Quick Start

1. **Download** the release archive
2. **Extract** the files: `tar -xzf AutoRip2MKV-Mac-v1.0.0-arm64-signed.tar.gz`
3. **Make executable**: `chmod +x AutoRip2MKV-Mac-v1.0.0/AutoRip2MKV-Mac`
4. **Run**: `./AutoRip2MKV-Mac-v1.0.0/AutoRip2MKV-Mac`

## macOS Security Solutions

If macOS blocks the app with "cannot be opened because it is from an unidentified developer":

### Method 1: System Settings (Recommended)
1. Try to run the app - this will show a security dialog
2. Open **System Settings** → **Privacy & Security**
3. Scroll down to find "AutoRip2MKV-Mac was blocked..."
4. Click **"Open Anyway"**
5. Confirm in the follow-up dialog

### Method 2: Remove Quarantine (Terminal)
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine AutoRip2MKV-Mac

# Or remove all extended attributes
xattr -c AutoRip2MKV-Mac
```

### Method 3: Bypass Gatekeeper (Terminal)
```bash
# Give explicit permission
sudo spctl --add AutoRip2MKV-Mac

# Verify the app is allowed
spctl -a AutoRip2MKV-Mac
```

### Method 4: Control+Click Method
1. **Control+Click** (or right-click) on the AutoRip2MKV-Mac file
2. Select **"Open"** from the context menu
3. Click **"Open"** in the security dialog

## Prerequisites

### Required
- **macOS 13.0** (Ventura) or later
- **Apple Silicon** (ARM64) Mac
- **FFmpeg**: Install via Homebrew: `brew install ffmpeg`

### Optional
- **Homebrew**: For FFmpeg installation: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

## Troubleshooting

### "Permission denied" error
```bash
chmod +x AutoRip2MKV-Mac
```

### "Bad CPU type in executable"
- This app requires Apple Silicon (M1/M2/M3) Mac
- Intel Macs are not supported in v1.0.0

### "FFmpeg not found"
```bash
# Install FFmpeg via Homebrew
brew install ffmpeg

# Or install Homebrew first, then FFmpeg
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install ffmpeg
```

### App crashes immediately
- Check Console.app for crash logs
- Ensure you have the correct permissions for DVD/Blu-ray drives
- Make sure the media is properly mounted

### Gatekeeper still blocking
```bash
# Temporarily disable Gatekeeper (not recommended)
sudo spctl --master-disable

# Run the app, then re-enable
sudo spctl --master-enable
```

## Advanced Usage

### Command Line Options
```bash
# Basic execution
./AutoRip2MKV-Mac

# Run with specific output directory
./AutoRip2MKV-Mac --output /path/to/output

# Get help
./AutoRip2MKV-Mac --help
```

### Environment Variables
```bash
# Set custom FFmpeg path
export FFMPEG_PATH=/usr/local/bin/ffmpeg

# Set default output directory
export AUTORIP_OUTPUT_DIR=~/Movies/Ripped
```

## Security Notes

- The app is **ad-hoc signed** for basic compatibility
- For production use, consider getting a proper Apple Developer certificate
- The app only accesses DVD/Blu-ray drives and your specified output directory
- No network access or external data transmission

## Support

If you encounter issues:

1. **Check the logs** in Console.app under "AutoRip2MKV-Mac"
2. **Verify prerequisites** (macOS version, FFmpeg installation)
3. **Try different security bypass methods** listed above
4. **Report issues** on the GitHub repository with:
   - macOS version
   - Mac model (M1/M2/M3)
   - Error messages
   - Console.app logs
