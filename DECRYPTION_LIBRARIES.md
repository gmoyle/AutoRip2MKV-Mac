# Decryption Library Integration

AutoRip2MKV-Mac uses open-source decryption libraries to handle CSS (DVD) and AACS (Blu-ray) protection.

## Libraries Used

### libdvdcss (DVD Decryption)
- **Purpose**: Content Scramble System (CSS) decryption for DVDs
- **License**: GPL-2.0
- **Source**: https://www.videolan.org/developers/libdvdcss.html
- **Installation**: `brew install libdvdcss`

### libaacs (Blu-ray Decryption)
- **Purpose**: Advanced Access Content System (AACS) decryption for Blu-rays
- **License**: LGPL-2.1
- **Source**: https://www.videolan.org/developers/libaacs.html
- **Installation**: `brew install libaacs`

## Why Open-Source Libraries?

Instead of implementing CSS/AACS decryption from scratch, we use battle-tested open-source libraries:

1. **Legal Compliance**: These libraries are widely used and legally distributed
2. **Reliability**: Maintained by VideoLAN (VLC) team with years of development
3. **No Third-Party Apps**: Direct library integration means no need for MakeMKV or other tools
4. **Performance**: Optimized C implementations for fast decryption

## Building from Source

### Prerequisites

Install the required libraries via Homebrew:

```bash
brew install libdvdcss libaacs
```

### Build Configuration

Package.swift automatically detects the library locations:

```swift
// Detects libdvdcss and libaacs from Homebrew
let libdvdcssPath = getLibraryPath(name: "libdvdcss")
let libaacspath = getLibraryPath(name: "libaacs")
```

Standard Homebrew paths checked:
- `/opt/homebrew/opt/` (Apple Silicon)
- `/usr/local/opt/` (Intel)

### Build the Project

```bash
swift build
```

The build system will:
1. Locate libdvdcss and libaacs from Homebrew
2. Link against the dynamic libraries
3. Set up runtime library paths (rpath)

## Distribution

For release builds that bundle the libraries:

```bash
./scripts/bundle-decryption-libs.sh
```

This script:
1. Copies libdvdcss and libaacs dylibs into the .app bundle
2. Updates library install names for bundled paths
3. Ensures the app runs standalone without Homebrew dependencies

## Implementation Details

### DVDDecryptor.swift

Uses libdvdcss C API via Swift's `@_silgen_name`:

```swift
@_silgen_name("dvdcss_open")
private func dvdcss_open(_ psz_target: UnsafePointer<CChar>?) -> OpaquePointer?

@_silgen_name("dvdcss_read")
private func dvdcss_read(_ dvdcss: OpaquePointer?, _ p_buffer: UnsafeMutableRawPointer?, _ i_blocks: Int32, _ i_flags: Int32) -> Int32
```

### BluRayDecryptor.swift

Uses libaacs C API for AACS decryption:

```swift
@_silgen_name("aacs_open")
private func aacs_open(_ path: UnsafePointer<CChar>?, _ keyfile_path: UnsafePointer<CChar>?) -> OpaquePointer?

@_silgen_name("aacs_decrypt_unit")
private func aacs_decrypt_unit(_ aacs: OpaquePointer?, _ buf: UnsafeMutablePointer<UInt8>?) -> Int32
```

## AACS Key Database

For AACS decryption to work, users need an AACS key database file:

```bash
# Keys are typically stored at:
~/.config/aacs/KEYDB.cfg
```

Key database files can be obtained from:
- https://github.com/mjohnson9/ aacs-keys (community-maintained)
- Generated from owned Blu-ray discs

## Legal Considerations

- **libdvdcss**: Used for decrypting legally owned DVDs
- **libaacs**: Requires valid AACS keys from owned Blu-ray discs
- **Fair Use**: Intended for personal backup of owned media only

Users are responsible for complying with local laws regarding copy protection circumvention.

## Troubleshooting

### Library Not Found

```
error: could not find library 'dvdcss'
```

**Solution**: Install libraries via Homebrew:
```bash
brew install libdvdcss libaacs
```

### AACS Decryption Fails

```
Blu-ray device not found or libaacs failed to open device
```

**Solutions**:
1. Ensure `~/.config/aacs/KEYDB.cfg` exists with valid keys
2. Check disc is actually AACS-protected
3. Try updating AACS key database

### Runtime Library Error

```
dyld: Library not loaded: @rpath/libdvdcss.2.dylib
```

**Solution**: Run the bundling script before distributing:
```bash
./scripts/bundle-decryption-libs.sh
```

## References

- [libdvdcss Documentation](https://www.videolan.org/developers/libdvdcss.html)
- [libaacs Documentation](https://www.videolan.org/developers/libaacs.html)
- [VideoLAN Legal FAQ](https://www.videolan.org/legal.html)
