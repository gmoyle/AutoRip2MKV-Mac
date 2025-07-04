<div align="center">
  <img src="assets/icon-simple.svg" alt="AutoRip2MKV for Mac" width="96" height="96">
  <h1>📦 AutoRip2MKV Installation Guide</h1>
  <p><em>Step-by-step installation instructions for macOS</em></p>
</div>

This guide helps you install and run AutoRip2MKV on macOS despite Apple's security restrictions.

## 🚀 Quick Installation

### Step 1: Download and Install
1. **Download the latest DMG** from [GitHub Releases](https://github.com/gmoyle/AutoRip2MKV-Mac/releases)
2. **Open the DMG file** and drag AutoRip2MKV to Applications
3. **Install FFmpeg** (required for video conversion):
   ```bash
   brew install ffmpeg
   ```

### Step 2: First Launch (Security Override)

Since AutoRip2MKV isn't code-signed with an Apple Developer certificate, macOS will block it initially. Choose one of these methods:

## ✅ Method 1: Right-Click Open (Recommended)

1. **Navigate to Applications** in Finder
2. **Right-click** (or Control+click) on AutoRip2MKV
3. **Select "Open"** from the context menu
4. **Click "Open"** in the security dialog

This permanently allows the app to run.

## ✅ Method 2: System Preferences

1. **Try to open** AutoRip2MKV normally (it will be blocked)
2. **Open System Preferences** → Security & Privacy → General
3. **Look for the message** about AutoRip2MKV being blocked
4. **Click "Open Anyway"** next to the message
5. **Try opening** the app again

## ✅ Method 3: Terminal (Advanced Users)

Remove the quarantine attribute that macOS adds to downloaded files:

```bash
# Remove quarantine from the app
sudo xattr -r -d com.apple.quarantine /Applications/AutoRip2MKV.app

# Verify it was removed
xattr -l /Applications/AutoRip2MKV.app
```

## 🛡️ Security Information

### Why does macOS block the app?

- AutoRip2MKV is **not notarized** by Apple (requires paid Developer Program)
- The app is **ad-hoc signed** during build process
- macOS **Gatekeeper** blocks unsigned/unnotarized applications by default

### Is it safe?

✅ **Yes, the app is completely safe:**
- **100% open source** - all code is visible in this repository
- **No malicious code** - you can inspect every line
- **No network activity** - the app only processes local files
- **AI-generated code** - thoroughly tested with 100+ unit tests

### Alternative: Build from Source

If you prefer, you can build from source instead:

```bash
git clone https://github.com/gmoyle/AutoRip2MKV-Mac.git
cd AutoRip2MKV-Mac
swift build && swift run
```

## 🔧 Troubleshooting

### App Won't Open After Following Steps

1. **Check if FFmpeg is installed**: `ffmpeg -version`
2. **Verify app permissions**: Right-click → Get Info → ensure you have read/write access
3. **Try the terminal method** to remove quarantine completely

### "Operation not permitted" Error

This usually means you need to grant additional permissions:

1. **System Preferences** → Security & Privacy → Privacy
2. **Add AutoRip2MKV** to:
   - Full Disk Access (for reading DVD files)
   - Accessibility (if needed for automation)

### FFmpeg Not Found

Install FFmpeg using Homebrew:

```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install FFmpeg
brew install ffmpeg

# Verify installation
ffmpeg -version
```

## 📋 System Requirements

- **macOS 13.0** or later (macOS Ventura+)
- **FFmpeg** for video conversion
- **Optical drive** or mounted DVD/Blu-ray images
- **Admin privileges** for some operations

## 🆘 Need Help?

If you encounter issues:

1. **Check the [Issues](https://github.com/gmoyle/AutoRip2MKV-Mac/issues)** for similar problems
2. **Create a new issue** with:
   - Your macOS version
   - Error messages (if any)
   - Steps you tried
   - Whether you can build from source

## 🎯 Pro Tips

- **First launch takes longer** - FFmpeg may be downloaded automatically
- **Keep the app in Applications** - don't run it from Downloads
- **Use right-click method** - it's the most reliable for unsigned apps
- **FFmpeg path is cached** - restart the app if you install FFmpeg after first launch

---

*This app represents a groundbreaking AI development experiment - see [WARP_AI_EXPERIMENT.md](WARP_AI_EXPERIMENT.md) for the full story!*
