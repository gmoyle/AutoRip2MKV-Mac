<div align="center">
  <img src="assets/icon.svg" alt="AutoRip2MKV for Mac" width="128" height="128">
  <h1>AutoRip2MKV for Mac</h1>
  <p><em>Native DVD & Blu-ray Ripping with Built-in CSS Decryption</em></p>
  
  [![Build Status](https://github.com/gmoyle/AutoRip2MKV-Mac/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/gmoyle/AutoRip2MKV-Mac/actions/workflows/ci.yml)
  [![Update Statistics](https://github.com/gmoyle/AutoRip2MKV-Mac/actions/workflows/update-stats.yml/badge.svg?branch=master)](https://github.com/gmoyle/AutoRip2MKV-Mac/actions/workflows/update-stats.yml)
  [![Latest Release](https://github.com/gmoyle/AutoRip2MKV-Mac/actions/workflows/release.yml/badge.svg?event=push)](https://github.com/gmoyle/AutoRip2MKV-Mac/actions/workflows/release.yml)
  <!-- Badge refresh trigger: 2025-07-04-v2 -->
</div>

> 🤖 **AI Development Experiment**: This entire application was created using Warp 2.0 AI assistance by someone with zero Swift experience and an Art Degree. [Read the full experiment documentation](./WARP_AI_EXPERIMENT.md) 🎨→👨‍💻

A native macOS application for automatically ripping DVDs and Blu-rays to MKV format with **native CSS decryption** - no third-party applications required!

## 🎨 App Icon

<div align="center">
  <table>
    <tr>
      <td align="center">
        <img src="assets/icon.svg" alt="Main Icon" width="128" height="128">
        <br><strong>Main Icon</strong>
        <br><em>512×512 Application Icon</em>
      </td>
      <td align="center">
        <img src="assets/icon-simple.svg" alt="Simple Icon" width="64" height="64">
        <br><strong>Simple Icon</strong>
        <br><em>128×128 Favicon & Small UI</em>
      </td>
      <td align="center">
        <img src="assets/logo.png" alt="Logo" width="200" height="60">
        <br><strong>Horizontal Logo</strong>
        <br><em>400×120 Documentation & Web</em>
      </td>
    </tr>
  </table>
  
  <p><em>Professional macOS-style icon featuring a large DVD disc with bright orange floppy disk overlay,<br>representing the classic-to-digital conversion process. Floppy disk design recommended by<br><strong>Susanne Moyle</strong> for nostalgic throwback appeal, with anatomically correct vertical access window.</em></p>
</div>

## Features

- **Native DVD decryption** - Built-in CSS (Content Scramble System) decryption
- **Blu-ray Support** - AACS decryption framework and BDMV parsing
- **No dependencies on MakeMKV** - Completely self-contained solution
- **FFmpeg Bundled** - No separate downloads or installations required
- **Automatic Drive Detection** - Smart optical drive detection and selection
- Native macOS interface built with Swift and AppKit
- Easy-to-use GUI with persistent settings
- Progress tracking and logging with real-time updates
- Automatic DVD/Blu-ray structure analysis and title detection
- Chapter preservation and metadata inclusion
- Multiple video/audio codec support (H.264, H.265, AV1, AAC, AC3, DTS, FLAC)
- Configurable quality settings
- **🤖 100% AI-Generated**: 13,715 lines of Swift code created entirely by AI

## Installation

### 📦 **Recommended: Download Release** (Easiest)

**✨ Just download and run - no building required!**

1. **Download the latest release** from [GitHub Releases](https://github.com/gmoyle/AutoRip2MKV-Mac/releases)
2. **Open the DMG file** and drag AutoRip2MKV to Applications
3. **⚠️ First Launch**: Right-click the app → "Open" to bypass macOS security
4. **FFmpeg**: Already bundled - no downloads needed!
5. **Start ripping!** - Fully self-contained, works offline

> 📋 **Need help with installation?** See the detailed [Installation Guide](INSTALLATION.md) for step-by-step instructions to handle macOS security restrictions.

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
5. **Click "Start Ripping"** - uses bundled FFmpeg for immediate processing
6. **Monitor progress** in the real-time log area

**That's it!** The app handles everything automatically including:
- ✅ FFmpeg bundled (no downloads or Homebrew needed)
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

## 📚 Documentation

- **[Installation Guide](INSTALLATION.md)** - Detailed setup instructions for macOS
- **[User Guide](WIKI_USER_GUIDE.md)** - Comprehensive feature documentation
- **[FFmpeg Bundling](FFMPEG_BUNDLING.md)** - Technical details on bundled FFmpeg integration
- **[Roadmap](ROADMAP.md)** - Project timeline and planned features

## 🗺️ Roadmap

See our comprehensive [**Roadmap**](ROADMAP.md) for planned features, enhancements, and long-term project goals including:

- **Enhanced 4K Support**: Ultra HD Blu-ray detection and processing
- **Advanced Automation**: Intelligent batch processing and workflow tools
- **Professional Features**: Metadata management and enterprise tools
- **Cross-Platform Expansion**: Linux and Windows support evaluation
- **AI Development Evolution**: Next-generation code generation experiments

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

After decryption, the application uses bundled FFmpeg for video conversion:

- **FFmpeg v7.1.1-tessus** bundled for immediate use
- Support for multiple codecs (H.264, H.265, AV1)
- Audio codec options (AAC, AC3, DTS, FLAC)
- Chapter preservation
- Metadata inclusion
- Quality settings (CRF-based)
- No external dependencies or downloads required

## Legal Notice

This software is intended for legitimate backup purposes of DVDs you legally own. Users are responsible for complying with all applicable laws regarding DVD copying and CSS circumvention in their jurisdiction.

## 🚀 Warp 2.0 AI Experiment

This project represents a groundbreaking experiment in AI-powered software development:

- **Developer**: Art degree, zero Swift experience
- **Code Written by Human**: 0 lines
- **Git Commands by Human**: 0
- **Total Swift Code**: 13,715 lines (100% AI-generated)
- **Tests**: 277 comprehensive tests (100.0% pass rate)
- **Development Method**: 100% AI-assisted via Warp 2.0
- **Features Implemented**: DVD/Blu-ray ripping, CSS/AACS decryption, auto drive detection, persistent settings

**[📖 Read the full experiment documentation](./WARP_AI_EXPERIMENT.md)** to see how AI democratizes software development.

*"From art degree to Swift developer in one conversation"* 🎨→👨‍💻

## Acknowledgments

- **Warp 2.0 Agent Mode** for making this experiment possible
- **Susanne Moyle** for recommending the nostalgic floppy disk design element
- The Swift and macOS development communities
- FFmpeg project for video conversion capabilities
- DVD Forum specifications for DVD structure documentation
