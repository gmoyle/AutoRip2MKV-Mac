# Changelog

All notable changes to AutoRip2MKV-Mac will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.4] - 2025-07-15

### 🔧 Fixed
- **FFmpeg Detection**: Fixed issue where app would show ffmpeg installation dialog even when ffmpeg was already installed via Homebrew
- **System PATH Integration**: App now properly checks system PATH for ffmpeg before attempting to download it
- **User Experience**: Eliminated unnecessary installation interruptions for users with existing ffmpeg installations

### 🚀 Improved
- **Better System Integration**: Enhanced detection of system-installed ffmpeg at `/usr/local/bin/ffmpeg` and other PATH locations
- **Improved Error Handling**: More robust ffmpeg path detection and fallback mechanisms
- **Seamless Homebrew Support**: Works flawlessly with Homebrew-installed ffmpeg

### 🧪 Testing
- All 213 tests continue to pass successfully
- CI/CD pipeline validates builds on macOS
- Memory management improvements for enhanced stability

## [1.2.3] - 2025-07-06

### 🔧 Fixed
- **Duplicate Function**: Removed duplicate `setupFileOrganizationSection` function from `DetailedSettingsWindowController.swift`
- **Memory Management**: Fixed `testViewControllerMemoryManagement` test to avoid UI control retain cycles
- **Build Issues**: Resolved compilation errors that were preventing successful builds

### 🚀 Improved
- **CI Pipeline**: Enhanced GitHub Actions workflow for better code coverage and build validation
- **Test Stability**: Improved test reliability and reduced flaky test failures
- **Code Quality**: Better separation of concerns between main controller and file organization extension

## [1.2.2] - 2025-06-27

### 🚀 Improved
- **Universal Binary Support**: Added support for both Intel and Apple Silicon Macs
- **Release Process**: Enhanced automated release workflow with proper universal binary creation
- **Package Configuration**: Updated Package.swift to be macOS-only for better compatibility

## [1.2.1] - 2025-06-27

### 🔧 Fixed
- **Package Configuration**: Fixed Package.swift to properly target macOS only
- **Release Workflow**: Improved GitHub Actions release process for better artifact generation

## [1.2.0] - 2025-06-20

### 🎉 Major Features
- **Queue System**: Implemented comprehensive conversion queue with job management
- **Batch Processing**: Added support for processing multiple discs in sequence
- **Progress Tracking**: Enhanced progress monitoring with detailed job status
- **Auto-Eject**: Automatic disc ejection after successful ripping

### 🚀 Improved
- **UI Enhancements**: New queue window with real-time job monitoring
- **Settings Management**: Persistent settings with improved configuration options
- **Error Handling**: Better error reporting and recovery mechanisms

## [1.1.0] - 2025-06-10

### 🎉 New Features
- **Hardware Acceleration**: Added VideoToolbox hardware acceleration support
- **First-Run Setup**: Intelligent first-run configuration with hardware detection
- **Drive Detection**: Automatic optical drive detection and selection
- **Settings Persistence**: Persistent user preferences and settings

### 🔧 Fixed
- **CSS Decryption**: Improved DVD CSS decryption reliability
- **Memory Management**: Better memory handling for large disc processing
- **UI Responsiveness**: Enhanced UI responsiveness during ripping operations

## [1.0.0] - 2025-06-01

### 🎉 Initial Release
- **Native DVD Ripping**: Complete DVD ripping functionality with native CSS decryption
- **Blu-ray Support**: Basic Blu-ray disc support with AACS framework
- **FFmpeg Integration**: Bundled FFmpeg for video conversion
- **macOS Native UI**: Built with Swift and AppKit for native macOS experience
- **Multiple Codecs**: Support for H.264, H.265, AV1, AAC, AC3, DTS, FLAC
- **Chapter Preservation**: Automatic chapter and metadata preservation
- **Real-time Logging**: Live progress monitoring and logging
- **No Dependencies**: Self-contained application with no external requirements

### 🤖 AI Development
- **100% AI-Generated**: Entire codebase (13,715 lines) generated using Warp 2.0 AI
- **Zero Swift Experience**: Created by developer with Art degree and no Swift background
- **Comprehensive Testing**: 277 tests with 100% pass rate
- **Full Documentation**: Complete user guides and technical documentation

---

## Legend
- 🎉 **New Features**: Major new functionality
- 🚀 **Improved**: Enhancements to existing features
- 🔧 **Fixed**: Bug fixes and issue resolutions
- 🧪 **Testing**: Testing and quality improvements
- 🤖 **AI Development**: AI-related development notes

## Links
- [GitHub Releases](https://github.com/gmoyle/AutoRip2MKV-Mac/releases)
- [Installation Guide](INSTALLATION.md)
- [User Guide](WIKI_USER_GUIDE.md)
- [Roadmap](ROADMAP.md)
