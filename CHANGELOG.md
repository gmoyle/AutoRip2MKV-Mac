# Changelog

All notable changes to AutoRip2MKV-Mac will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-07-22

### ✨ Hands-free ripping straight into Plex
- **Insert-and-walk-away workflow**: auto-rip on insert, auto-eject when the disc read finishes, and skip discs already ripped — rip disc after disc without touching the app.
- **Skip already-ripped discs**: a `rip_complete.json` marker records the disc and a fingerprint of the settings used; matching discs are skipped and ejected. Change any rip setting, hold ⌥ while inserting, or click Start Ripping to force a re-rip.
- **Plex library auto-detection**: on first launch the default output directory is taken from a local Plex Media Server's movie library, falling back to `~/Movies/AutoRip2MKV`.
- **Plex-style naming**: with a disc identified via OMDb, output is `Movie (Year)/Movie (Year).mkv` for direct Plex matching. OMDb lookup strips screener/format junk from volume labels and prefers exact matches.

### 🖥️ UI
- **Queue embedded in the main window** (the separate Conversion Queue window is gone), with per-row cancel/retry/reveal/remove.
- **Live two-phase progress**: disc-read progress in GB, then encode progress as a percentage.
- **Log hidden** behind a disclosure triangle; removed the non-functional Batch Mode checkbox.

### 🎬 Output quality
- **Auto-deinterlace** interlaced (NTSC) sources with bwdif (flagged frames only); on by default.
- **All audio and subtitle tracks** are captured (not just one of each) and tagged with languages parsed from the VTS IFO, so Plex shows proper track names.

### 🐛 Fixed
- **Disc eject never worked**: called `/usr/bin/diskutil` (nonexistent; it's in `/usr/sbin`) and only unmounted. Now unmounts then physically ejects with `drutil`, and releases the libdvdcss device handle first.
- **iCloud corruption**: encoding large files directly into an iCloud-synced output folder let stale partials be restored over finished rips. Encodes now go to local staging and move into place atomically on success.
- **Duplicate queue jobs**: the disc detector re-queued the same disc repeatedly; Start Ripping now refuses duplicates and superseded failures are pruned.
- **Retry backoff**: DVD parse/decrypt retries now wait 5s instead of firing three times instantly, riding out transient device contention (e.g. macOS DVD Player grabbing the drive).

### 🔧 Technical
- Deploys sign with Developer ID so macOS remembers the removable-volume permission across rebuilds.
- Removed the orphaned `scripts/bundle-decryption-libs.sh` (the release workflow inlines dylib bundling).

## [1.4.2] - 2026-06-18

### 🔧 Technical
- Notarized DMG release workflow (build, bundle ffmpeg + decryption dylibs, sign with Developer ID, notarize).
- Build arm64-only to match the runner's Homebrew dylibs.

## [1.4.0] - 2026-06-17

### 🎉 First Real-World DVD Rip
- **Actually works on physical discs**: Inserted an encrypted DVD, clicked Start Ripping, got a decrypted MKV. First time end-to-end ripping has ever succeeded.

### 🐛 Fixed
- **DVDDecryptor was still a stub**: v1.3.0 left `import Clibdvdcss` commented out and all methods as no-ops. Replaced with proper `@_silgen_name` bindings to `dvdcss_open/seek/read/close`.
- **Wrong device path for libdvdcss**: Opening via mount point (`/Volumes/DISC`) uses software cracking which can't decrypt real discs. Fixed to resolve mount point → `/dev/rdiskN` (raw device) via `diskutil info -plist` for hardware CSS authentication.
- **IFO BCD duration decode had wrong bit shifts**: `decodeBCDTime()` shifted by 20/12/4 instead of 24/16/8. All title durations parsed as ~0 seconds, causing intelligent title filter to reject every title.
- **TT_SRPT entry field offsets wrong**: `vtsNumber` and `vtsTitleNumber` read as `UInt16` at wrong offsets; they are single bytes at offsets 6 and 7. `startSector` was at wrong offset (10 vs 8).
- **Wrong PGC selected for multi-title VTS**: Parser always used PGC 0 for every title. Fixed to use `vtsTitleNumber` to index into the correct Program Chain for each title.
- **VOB extraction bypassed libdvdcss**: Raw `FileHandle` reads of VOB files return still-encrypted data. Removed this path; all extraction now goes through `dvdcss_seek + dvdcss_read` with `DVDCSS_READ_DECRYPT`.

### 🔧 Technical
- Used `@_silgen_name` for libdvdcss C bindings (correct SPM approach; bridging headers not auto-exposed to Swift)
- `findRawDVDDevice()` uses `diskutil info -plist` for reliable raw device resolution on any macOS system
- Removed dead `extractFromVOBFiles()` method

## [1.3.0] - 2026-02-07

### 🔐 Major Changes
- **Open-Source Decryption**: Integrated libdvdcss for DVD CSS decryption
- **Blu-ray AACS Support**: Integrated libaacs for Blu-ray AACS decryption  
- **No Placeholder Code**: Replaced scaffolded decryption with working implementations
- **Library Bundling**: Added script to bundle decryption libraries with app

### 📚 Documentation
- Added DECRYPTION_LIBRARIES.md with integration details
- Updated README to clarify use of open-source libraries  
- Updated AGENTS.md with new architecture details

### 🔧 Technical
- Updated Package.swift to link libdvdcss and libaacs
- Created Swift bindings for C library functions using @_silgen_name
- Added bundle-decryption-libs.sh for standalone distribution

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

## [1.2.5] - 2026-01-31

### 🚀 Improved
- **Blu-ray & DVD Error Recovery**: Added robust error detection, retry logic, and fallback strategies to all critical ripping steps (structure parsing, decryption, conversion, file I/O). Failed playlists/titles are skipped after repeated failures, with errors logged and user notified.
- **User Notifications & Logging**: Enhanced workflow status updates, error notifications, and detailed logging for all disc types. Users receive real-time feedback and alerts for all recovery actions.

### �️ Fixed
- Improved error handling and recovery for Blu-ray and DVD workflows

### 📚 Documentation
- Updated README and user guide to reflect new error recovery and notification features

### 🤪 Testing
- All 213 tests continue to pass successfully
- CI/CD pipeline validates builds on macOS
- Memory management improvements for enhanced stability

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
