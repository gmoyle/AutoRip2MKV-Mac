# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Build & Test Commands

```bash
# Build (debug)
swift build

# Build (release)
swift build -c release

# Run all tests
swift test

# Run specific test suite
swift test --filter UHDDetectionTests
swift test --filter DVDDecryptorTests

# Run with code coverage
swift test --enable-code-coverage

# Lint
swiftlint lint

# Safe Phase 1 tests with timeout protection
./run_phase1_tests.sh
```

## Project Overview

Native macOS DVD/Blu-ray ripper with built-in CSS/AACS decryption. Written entirely in Swift using AppKit (no SwiftUI). Targets macOS 13.0+ with Swift 5.8+.

## Architecture

### Core Components

**MediaRipper** (`MediaRipper.swift` + extensions) - Orchestrates ripping workflow
- `MediaRipper+DVD.swift` - DVD-specific ripping logic
- `MediaRipper+BluRay.swift` - Blu-ray ripping logic  
- `MediaRipper+Analysis.swift` - UHD detection, resolution analysis, quality assessment
- `MediaRipper+Conversion.swift` - FFmpeg conversion handling
- `MediaRipper+Organization.swift` - File organization

**Decryptors** - Open-source library integration for CSS/AACS decryption
- `DVDDecryptor.swift` - CSS decryption using libdvdcss
- `BluRayDecryptor.swift` - AACS decryption using libaacs

**Structure Parsers** - Parse disc filesystem formats
- `DVDStructureParser.swift` - VIDEO_TS/IFO parsing
- `BluRayStructureParser.swift` - BDMV structure parsing
- `BluRayIndexParser.swift` - Index/playlist parsing
- `HDDVDStructureParser.swift` - HD DVD support

**UI Layer** (AppKit, programmatic - no storyboards)
- `AppDelegate.swift` - App lifecycle
- `MainViewController.swift` + extensions - Main window, including the embedded
  conversion queue table (`MainViewController+QueueTable.swift`)
- `DetailedSettingsWindowController.swift` - Settings UI

**Singletons**
- `SettingsManager.shared` - UserDefaults wrapper
- `Logger.shared` - Logging utility

### Key Patterns

- **Extension-based organization**: Large classes like `MediaRipper` and `MainViewController` are split across multiple extension files
- **Delegate pattern**: `MediaRipperDelegate` for progress/status callbacks
- **Configuration structs**: `RippingConfiguration` contains all encoding options

### Media Type Detection

The `MediaRipper.detectMediaType(path:)` method checks for:
- `/VIDEO_TS` → DVD or Ultra HD DVD
- `/BDMV` → Blu-ray or 4K Blu-ray

## Testing

Tests are in `Tests/AutoRip2MKV-MacTests/`. Key test files:
- `DVDDecryptorTests.swift` - Decryption unit tests
- `UHDDetectionTests.swift` - 4K/UHD detection (35 tests)
- `ResolutionAnalysisTests.swift` - Resolution parsing (30+ tests)
- `MediaRipperIntegrationTests.swift` - Full workflow tests

Some tests may display UI dialogs; use `./run_phase1_tests.sh` for timeout-protected execution.

## Distribution

Distribution scripts are in `scripts/`:
- `distribute.sh` - Full build, sign, notarize, and DMG creation
- `create-app-bundle.sh` - Creates .app bundle structure
- `notarize-app.sh` - Apple notarization
- `create-dmg.sh` - DMG packaging

Requires Apple Developer credentials in `.env` file (see `.env.example`).

## CI/CD

GitHub Actions workflows in `.github/workflows/`:
- `ci.yml` - Build, test, lint on push/PR
- `release.yml` - Release builds
- `update-stats.yml` - Statistics updates

## SwiftLint

Custom rules in `.swiftlint.yml`:
- Line length: 120 warning, 200 error
- Function body: 50 warning, 100 error lines
- Relaxed rules for media-specific patterns (many parameters, force unwrapping for low-level ops)
