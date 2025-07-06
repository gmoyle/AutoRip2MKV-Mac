AutoRip2MKV-Mac v1.0.0
=====================

AutoRip2MKV-Mac is a native macOS application for ripping DVD and Blu-ray discs with built-in decryption support.

## Features

### Native DVD Support
- **DVD Structure Parsing**: Analyzes VIDEO_TS structure and extracts title information
- **CSS Decryption**: Native CSS (Content Scramble System) decryption for DVDs
- **Title Analysis**: Automatically detects titles, chapters, and duration
- **Multi-angle Support**: Handles DVDs with multiple viewing angles

### Native Blu-ray Support  
- **Blu-ray Structure Parsing**: Analyzes BDMV structure and playlist information
- **AACS Decryption**: Native AACS (Advanced Access Content System) decryption for Blu-rays
- **Playlist Analysis**: Automatically detects playlists, chapters, and stream information
- **Main Movie Detection**: Identifies the main movie content automatically

### Unified Ripping Interface
- **MediaRipper Class**: Single interface for both DVD and Blu-ray media
- **Automatic Detection**: Automatically detects media type (DVD vs Blu-ray)
- **Flexible Configuration**: Support for multiple codecs, quality settings, and features
- **Progress Tracking**: Real-time progress updates and status reporting

### Output Features
- **Multiple Video Codecs**: H.264, H.265 (HEVC), AV1 support
- **Multiple Audio Codecs**: AAC, AC3, DTS, FLAC support
- **Quality Settings**: Low, Medium, High, and Lossless quality presets
- **Chapter Support**: Preserves chapter information in output files
- **Subtitle Support**: Includes subtitle tracks when available
- **Metadata**: Automatically adds source type and duration metadata

## System Requirements

- **macOS**: 13.0 (Ventura) or later
- **Architecture**: Apple Silicon (ARM64) native
- **FFmpeg**: Required for video conversion (install via Homebrew: `brew install ffmpeg`)

## Installation

1. Download the `AutoRip2MKV-Mac` executable from this release
2. Place it in a convenient location (e.g., `/usr/local/bin` or `~/Applications`)
3. Make sure it's executable: `chmod +x AutoRip2MKV-Mac`
4. Install FFmpeg if not already installed: `brew install ffmpeg`

## Usage

### Command Line Interface
The application provides a native macOS Cocoa interface. Run the executable:

```bash
./AutoRip2MKV-Mac
```

### Programmatic Usage
The MediaRipper class can be used programmatically:

```swift
let ripper = MediaRipper()
let config = MediaRipper.RippingConfiguration(
    outputDirectory: "/path/to/output",
    selectedTitles: [], // Empty = rip all
    videoCodec: .h264,
    audioCodec: .aac,
    quality: .high,
    includeSubtitles: true,
    includeChapters: true,
    mediaType: nil // Auto-detect
)

ripper.startRipping(mediaPath: "/path/to/disc", configuration: config)
```

## Technical Details

### Architecture
- **Swift**: Written entirely in Swift for native macOS performance
- **Cocoa**: Uses native Cocoa/AppKit for the user interface
- **Native Decryption**: No external dependencies for DVD/Blu-ray decryption
- **Swift Package Manager**: Built using SPM for easy compilation

### Decryption Support
- **DVD CSS**: Complete CSS decryption implementation
- **Blu-ray AACS**: Native AACS v1 decryption support
- **Key Management**: Secure handling of decryption keys
- **Device Authentication**: Proper DVD/Blu-ray drive authentication

### File Format Support
- **Input**: DVD (VIDEO_TS), Blu-ray (BDMV)
- **Output**: MKV with complete metadata and chapter information
- **Streams**: Video, audio, subtitle, and chapter preservation

## Security & Legal

This software is designed for legitimate backup purposes of media you own. Users are responsible for complying with applicable copyright laws and license agreements in their jurisdiction.

## Build Information

- **Version**: 1.0.0
- **Build Date**: July 3, 2025
- **Target**: macOS 13.0+ (ARM64)
- **Swift Version**: 5.8+
- **Binary Size**: ~240KB native executable

## License

See the project repository for license information.

## Support

For issues, feature requests, or contributions, please visit the GitHub repository.
