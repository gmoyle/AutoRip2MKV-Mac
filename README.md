# AutoRip2MKV for Mac

[![CI](https://github.com/gmoyle/AutoRip2MKV-Mac/actions/workflows/ci.yml/badge.svg)](https://github.com/gmoyle/AutoRip2MKV-Mac/actions/workflows/ci.yml)
[![Update Statistics](https://github.com/gmoyle/AutoRip2MKV-Mac/actions/workflows/update-stats.yml/badge.svg)](https://github.com/gmoyle/AutoRip2MKV-Mac/actions/workflows/update-stats.yml)
[![Release](https://github.com/gmoyle/AutoRip2MKV-Mac/actions/workflows/release.yml/badge.svg)](https://github.com/gmoyle/AutoRip2MKV-Mac/actions/workflows/release.yml)

> 🤖 **AI Development Experiment**: This entire application was created using Warp 2.0 AI assistance by someone with zero Swift experience and an Art Degree. [Read the full experiment documentation](./WARP_AI_EXPERIMENT.md) 🎨→👨‍💻

A native macOS application for automatically ripping DVDs and Blu-rays to MKV format with **native CSS decryption** - no third-party applications required!

## Features

- **Native DVD decryption** - Built-in CSS (Content Scramble System) decryption
- **Blu-ray Support** - AACS decryption framework and BDMV parsing
- **No dependencies on MakeMKV** - Completely self-contained solution
- **Automatic Drive Detection** - Smart optical drive detection and selection
- Native macOS interface built with Swift and AppKit
- Easy-to-use GUI with persistent settings
- Progress tracking and logging with real-time updates
- Automatic DVD/Blu-ray structure analysis and title detection
- Chapter preservation and metadata inclusion
- Multiple video/audio codec support (H.264, H.265, AV1, AAC, AC3, DTS, FLAC)
- Configurable quality settings
- **🤖 100% AI-Generated**: 4,867 lines of Swift code created entirely by AI

## Installation

### 📦 **Recommended: Download Release** (Easiest)

**✨ Just download and run - no building required!**

1. **Download the latest release** from [GitHub Releases](https://github.com/gmoyle/AutoRip2MKV-Mac/releases)
2. **Open the DMG file** and drag AutoRip2MKV to Applications
3. **Launch the app** - FFmpeg will be downloaded automatically if needed
4. **Start ripping!** - No additional setup required

### 🛠️ **Alternative: Build from Source** (For Developers)

**⚠️ Only needed if you want to modify the code or contribute**

**Requirements:**
- macOS 13.0 or later
- Swift 5.8+ and Xcode Command Line Tools

**Steps:**
```bash
git clone https://github.com/gmoyle/AutoRip2MKV-Mac.git
cd AutoRip2MKV-Mac
swift build && swift run
```

## Usage

1. **Insert DVD/Blu-ray** into your Mac's optical drive
2. **Launch AutoRip2MKV** from Applications
3. **Select your disc** from the automatically detected drives dropdown
4. **Choose output directory** where MKV files will be saved
5. **Click "Start Ripping"** - FFmpeg will be installed automatically if needed
6. **Monitor progress** in the real-time log area

**That's it!** The app handles everything automatically including:
- ✅ FFmpeg installation (no Homebrew needed)
- ✅ Drive detection and selection
- ✅ CSS/AACS decryption
- ✅ Video conversion to MKV

### DVD Structure

The application expects a mounted DVD with the standard VIDEO_TS structure:
```
/Volumes/YOUR_DVD/
└── VIDEO_TS/
    ├── VIDEO_TS.IFO
    ├── VTS_01_0.IFO
    ├── VTS_01_1.VOB
    ├── VTS_01_2.VOB
    └── ...
```

## Development

This project is built using Swift Package Manager and native macOS frameworks:

- **Swift**: Primary programming language
- **AppKit**: Native macOS UI framework
- **Cocoa**: macOS development framework

### Project Structure

```
AutoRip2MKV-Mac/
├── Sources/
│   └── AutoRip2MKV-Mac/
│       ├── main.swift                  # Application entry point
│       ├── AppDelegate.swift           # App lifecycle management
│       ├── MainViewController.swift    # Main UI and user interaction
│       ├── DVDDecryptor.swift         # Native CSS decryption engine
│       ├── DVDStructureParser.swift   # DVD filesystem parser
│       └── DVDRipper.swift           # Main ripping coordinator
├── Tests/
│   └── AutoRip2MKV-MacTests/
│       └── AutoRip2MKV_MacTests.swift
├── Package.swift
└── README.md
```

### Building

**Note:** Most users should download the pre-built release instead of building from source.

```bash
# For development: Build, test, and run
swift build && swift test && swift run
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Technical Details

### Native CSS Decryption

This application implements native CSS (Content Scramble System) decryption without relying on external libraries like libdvdcss or applications like MakeMKV. The decryption process includes:

- CSS authentication with the DVD drive
- Disc key extraction from the lead-in area
- Title key extraction and decryption
- Sector-by-sector decryption using CSS stream cipher

### DVD Structure Analysis

The application parses the DVD structure natively:

- VMGI (Video Manager Information) parsing
- VTS (Video Title Set) analysis
- Program Chain (PGC) information extraction
- Chapter and cell information parsing
- Duration and metadata extraction

### Video Conversion

After decryption, the application uses FFmpeg for video conversion:

- Support for multiple codecs (H.264, H.265, AV1)
- Audio codec options (AAC, AC3, DTS, FLAC)
- Chapter preservation
- Metadata inclusion
- Quality settings (CRF-based)

## Legal Notice

This software is intended for legitimate backup purposes of DVDs you legally own. Users are responsible for complying with all applicable laws regarding DVD copying and CSS circumvention in their jurisdiction.

## 🚀 Warp 2.0 AI Experiment

This project represents a groundbreaking experiment in AI-powered software development:

- **Developer**: Art degree, zero Swift experience
- **Code Written by Human**: 0 lines
- **Git Commands by Human**: 0
- **Total Swift Code**: 4,867 lines (100% AI-generated)
- **Tests**: 66 comprehensive tests (100% pass rate)
- **Development Method**: 100% AI-assisted via Warp 2.0
- **Features Implemented**: DVD/Blu-ray ripping, CSS/AACS decryption, auto drive detection, persistent settings

**[📖 Read the full experiment documentation](./WARP_AI_EXPERIMENT.md)** to see how AI democratizes software development.

*"From art degree to Swift developer in one conversation"* 🎨→👨‍💻

## Acknowledgments

- **Warp 2.0 Agent Mode** for making this experiment possible
- The Swift and macOS development communities
- FFmpeg project for video conversion capabilities
- DVD Forum specifications for DVD structure documentation
