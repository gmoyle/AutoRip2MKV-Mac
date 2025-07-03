# AutoRip2MKV for Mac

A native macOS application for automatically ripping DVDs and Blu-rays to MKV format using MakeMKV.

## Features

- Native macOS interface built with Swift and AppKit
- Easy-to-use GUI for selecting source and output directories
- Progress tracking and logging
- Automatic DVD/Blu-ray detection and ripping

## Requirements

- macOS 13.0 or later
- MakeMKV installed on the system
- Swift 5.8 or later

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
2. Select the source DVD/Blu-ray directory using the "Browse" button
3. Select the output directory where MKV files will be saved
4. Click "Start Ripping" to begin the process
5. Monitor progress in the log area

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
│       ├── main.swift
│       ├── AppDelegate.swift
│       └── MainViewController.swift
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

## Acknowledgments

- MakeMKV for the underlying ripping functionality
- The Swift and macOS development communities
