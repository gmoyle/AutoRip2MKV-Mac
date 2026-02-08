# AutoRip2MKV-Mac Distribution Guide

## Overview

This guide covers the complete process of building, signing, and distributing AutoRip2MKV-Mac as a professional macOS application with proper code signing and notarization.

## Prerequisites

### Required Tools
- **Xcode Command Line Tools**: `xcode-select --install`
- **Apple Developer Account**: Required for code signing and notarization
- **Swift 5.8+**: For building the application
- **FFmpeg**: Optional bundling for standalone operation

### Apple Developer Setup
1. **Developer ID Certificate**: Download "Developer ID Application" certificate from Apple Developer portal
2. **Team ID**: Find your Team ID in Apple Developer account settings
3. **App-Specific Password**: Create one at [appleid.apple.com](https://appleid.apple.com) under Sign-In and Security

## Distribution Scripts

### Core Distribution Scripts

#### 1. `scripts/create-app-bundle.sh`
Creates a proper macOS `.app` bundle with:
- Correct bundle structure (`Contents/MacOS`, `Resources`, `Frameworks`)
- Proper `Info.plist` with all required keys
- Code signing with entitlements
- FFmpeg bundling (if available)
- Signature verification

#### 2. `scripts/create-dmg.sh`
Builds a professional DMG installer:
- Compressed DMG format for distribution
- Applications symlink for easy installation
- Custom window layout and styling
- Includes documentation files
- SHA256 checksum generation

#### 3. `scripts/notarize-app.sh`
Handles Apple notarization:
- Submits app bundle and DMG for notarization
- Waits for Apple approval
- Staples notarization tickets
- Verifies notarized status

#### 4. `scripts/distribute.sh` (Master Script)
Coordinates the complete distribution pipeline:
- Prerequisites checking
- Clean build process
- App bundle creation
- Code signing
- DMG creation
- Notarization
- Distribution summary

## Quick Start Distribution

### 1. Set Environment Variables
```bash
export APPLE_ID="your-apple-id@example.com"
export APPLE_ID_PASSWORD="your-app-specific-password"
export TEAM_ID="YOUR_TEAM_ID"
```

### 2. Run Distribution
```bash
# Complete distribution (recommended)
./scripts/distribute.sh

# Without notarization (for testing)
./scripts/distribute.sh --no-notarize

# Debug build
./scripts/distribute.sh --debug

# Clean only
./scripts/distribute.sh --clean-only
```

### 3. Distribution Output
- `build/AutoRip2MKV-Mac.app` - Signed app bundle
- `AutoRip2MKV-Mac-v1.2.4.dmg` - Notarized DMG installer

## Manual Distribution Steps

If you prefer to run each step manually:

### Step 1: Build the Application
```bash
swift build -c release --product AutoRip2MKV-Mac
```

### Step 2: Create App Bundle
```bash
./scripts/create-app-bundle.sh
```

### Step 3: Create DMG Installer
```bash
./scripts/create-dmg.sh
```

### Step 4: Notarize for Distribution
```bash
# Notarize app bundle only
./scripts/notarize-app.sh app

# Notarize DMG only
./scripts/notarize-app.sh dmg

# Notarize both
./scripts/notarize-app.sh both

# Check status
./scripts/notarize-app.sh status
```

## Code Signing Details

### Entitlements
The app uses `AutoRip2MKV.entitlements` with these key permissions:
- `com.apple.security.device.dvd` - DVD drive access
- `com.apple.security.device.removable-volumes-usage` - External media access
- `com.apple.security.files.user-selected.read-write` - File system access
- `com.apple.security.cs.disable-executable-page-protection` - FFmpeg execution
- `com.apple.security.cs.allow-unsigned-executable-code` - External tools

### Hardened Runtime
Enabled for notarization compliance while maintaining necessary permissions for disc access and external tool execution.

## Distribution Verification

### Local Testing
```bash
# Test app bundle directly
open build/AutoRip2MKV-Mac.app

# Test DMG installer
open AutoRip2MKV-Mac-v1.2.4.dmg
```

### Signature Verification
```bash
# Verify app bundle signature
codesign --verify --deep --strict build/AutoRip2MKV-Mac.app
codesign -dv build/AutoRip2MKV-Mac.app

# Verify DMG signature
codesign --verify --deep --strict AutoRip2MKV-Mac-v1.2.4.dmg

# Check notarization status
xcrun stapler validate build/AutoRip2MKV-Mac.app
xcrun stapler validate AutoRip2MKV-Mac-v1.2.4.dmg
```

## Troubleshooting

### Common Issues

#### Code Signing Fails
- Ensure Developer ID Application certificate is installed
- Check certificate validity: `security find-identity -v -p codesigning`
- Verify Team ID matches certificate

#### Notarization Rejected
- Check hardened runtime compliance
- Ensure all executables are signed
- Verify entitlements don't conflict with hardened runtime

#### App Won't Launch
- Check code signature: `codesign --verify --deep --strict path/to/app`
- Verify all dependencies are bundled
- Check Console.app for launch errors

#### FFmpeg Issues
- Ensure FFmpeg is signed if bundled
- Check PATH configuration in launch script
- Verify FFmpeg permissions in entitlements

### Getting Help

#### Apple Developer Support
- [Developer ID and Gatekeeper](https://developer.apple.com/developer-id/)
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

#### Debugging Tools
```bash
# Check app signature details
codesign -dv --verbose=4 build/AutoRip2MKV-Mac.app

# Test Gatekeeper assessment
spctl -a -t exec -vv build/AutoRip2MKV-Mac.app

# Check notarization log
xcrun notarytool log [submission-id] --apple-id $APPLE_ID --password $APPLE_ID_PASSWORD --team-id $TEAM_ID
```

## Release Checklist

### Before Distribution
- [ ] All source code committed and tagged
- [ ] Version number updated in `Info.plist` and scripts
- [ ] Build and test locally
- [ ] Verify all features work correctly
- [ ] Check code signature validity
- [ ] Test on clean macOS system

### Distribution Steps
- [ ] Run complete distribution pipeline
- [ ] Verify notarization success
- [ ] Test DMG installation process
- [ ] Upload to distribution channels
- [ ] Update documentation and release notes

### Post-Distribution
- [ ] Monitor for user feedback
- [ ] Test on various macOS versions
- [ ] Document any distribution issues
- [ ] Plan next release cycle

## Version History

### v1.2.4 (Current)
- Complete distribution pipeline
- Apple notarization support
- Professional DMG installer
- Comprehensive code signing

## Security Considerations

### Code Signing
- Uses Developer ID for distribution outside Mac App Store
- Hardened runtime enabled for security
- Minimal required entitlements

### Notarization
- Required for macOS 10.15+ compatibility
- Automated malware scanning by Apple
- Stapled tickets for offline verification

### Distribution
- DMG format prevents tampering
- SHA256 checksums for integrity verification
- Signed installer package

This distribution setup ensures AutoRip2MKV-Mac meets all Apple security requirements while maintaining the functionality needed for DVD and Blu-ray disc processing.