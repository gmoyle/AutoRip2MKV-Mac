# AutoRip2MKV for Mac

A native macOS application for automatically ripping DVDs and Blu-rays to MKV format with **native CSS decryption** - no third-party applications required!

## Features

- **Native DVD decryption** - Built-in CSS (Content Scramble System) decryption
- **No dependencies on MakeMKV** - Completely self-contained solution
- Native macOS interface built with Swift and AppKit
- Easy-to-use GUI for selecting source and output directories
- Progress tracking and logging with real-time updates
- Automatic DVD structure analysis and title detection
- Chapter preservation and metadata inclusion
- Multiple video/audio codec support (H.264, H.265, AV1, AAC, AC3, DTS, FLAC)
- Configurable quality settings

## Requirements

- macOS 13.0 or later
- FFmpeg for video conversion (install via: `brew install ffmpeg`)
- Swift 5.8 or later for building from source
- Xcode or Xcode Command Line Tools

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/gmoyle/AutoRip2MKV-Mac.git
   cd AutoRip2MKV-Mac
   ```

2. Build the project:
   ```bash
   swift build
   ```

3. Run the application:
   ```bash
   swift run
   ```

## Usage

1. Launch the application
2. Select the source DVD directory using the "Browse" button (mount your DVD first)
3. Select the output directory where MKV files will be saved
4. Click "Start Ripping" to begin the native decryption and conversion process
5. Monitor progress in the real-time log area

### First Time Setup

Ensure FFmpeg is installed:
```bash
brew install ffmpeg
```

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

To build the project:

```bash
swift build
```

To run tests:

```bash
swift test
```

To run the application:

```bash
swift run
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

## Acknowledgments

- The Swift and macOS development communities
- FFmpeg project for video conversion capabilities
- DVD Forum specifications for DVD structure documentation
