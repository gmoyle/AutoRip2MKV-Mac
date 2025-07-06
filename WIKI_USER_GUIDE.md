# AutoRip2MKV-Mac User Guide

Welcome to the comprehensive user guide for AutoRip2MKV-Mac! This guide covers all features, settings, and advanced functionality to help you get the most out of your DVD and Blu-ray ripping experience.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Main Interface](#main-interface)
3. [Expanded Settings Overview](#expanded-settings-overview)
4. [File Organization Options](#file-organization-options)
5. [Advanced Encoding Settings](#advanced-encoding-settings)
6. [Output Directory Preferences](#output-directory-preferences)
7. [Quality Presets System](#quality-presets-system)
8. [File Storage & Organization](#file-storage--organization)
9. [Bonus Content Management](#bonus-content-management)
10. [File Naming Templates](#file-naming-templates)
11. [Quality & Codec Settings](#quality--codec-settings)
12. [Advanced Options](#advanced-options)
13. [Template Variables Reference](#template-variables-reference)
14. [Best Practices](#best-practices)
15. [Troubleshooting](#troubleshooting)

---

## Getting Started

AutoRip2MKV-Mac is a powerful DVD and Blu-ray ripping application that converts your physical media to high-quality MKV files. The application provides professional-grade control over encoding, organization, and output quality.

### System Requirements
- macOS 13.0 or later
- FFmpeg (bundled with application - v7.1.1-tessus)
- DVD/Blu-ray drive or disc image files
- Sufficient storage space for output files

### First Launch
1. Launch AutoRip2MKV-Mac
2. Insert a DVD or Blu-ray disc (or select a disc image)
3. Choose your output directory
4. Click **Settings...** to configure your preferences
5. Click **Start Ripping** to begin

---

## Main Interface

The main interface provides quick access to essential ripping functions:

### Source Selection
- **Drive Dropdown**: Automatically detects optical drives
- **Refresh Button**: Re-scan for available drives
- **Browse Button**: Select disc image files from your computer

### Output Configuration
- **Output Directory**: Where your ripped files will be saved
- **Browse Button**: Select or create output folders

### Automation Options
- **Auto-rip inserted discs**: Automatically start ripping when a disc is detected
- **Auto-eject after ripping**: Eject the disc when ripping completes

### Settings Access
- **Settings... Button**: Opens the comprehensive settings window

---

## Expanded Settings Overview

The expanded settings window (introduced in v1.2.0) provides professional-level control over every aspect of the ripping process. Settings are organized into logical sections for easy navigation.

### Settings Categories
1. **File Organization Options** - How files are named and organized
2. **Advanced Encoding Settings** - Professional encoding controls
3. **Output Directory Preferences** - Default paths and organization
4. **Quality Presets** - Pre-configured and custom settings
5. **File Storage & Organization** - Directory structure options
6. **Bonus Content** - Special features handling
7. **File Naming** - Custom naming patterns
8. **Quality & Codecs** - Video and audio settings
9. **Advanced Options** - Expert-level configurations

---

## File Organization Options

Control how your ripped files are organized and managed.

### Auto-Rename Files
**Purpose**: Automatically rename files for better organization and compatibility
**Options**: 
- ✅ Enabled: Files are renamed using smart algorithms
- ❌ Disabled: Original disc names are preserved

**Example**: 
- Original: `VTS_01_1.mkv`
- Renamed: `The Matrix (1999).mkv`

### Directory Creation
**Create Year-Based Subdirectories**
- Organizes content by release year when metadata is available
- Structure: `Movies/1999/The Matrix (1999).mkv`

**Create Genre-Based Subdirectories**
- Groups content by genre (Action, Comedy, Drama, etc.)
- Structure: `Movies/Action/The Matrix (1999).mkv`

### Duplicate File Handling
Choose how to handle files that already exist:

1. **Skip duplicate files**: Fastest option, skips existing files
2. **Overwrite existing files**: Replaces existing files (use with caution)
3. **Rename with suffix**: Adds `_2`, `_3`, etc. to filename
4. **Ask user for each duplicate**: Prompts for each conflict

### Minimum File Size Filter
**Purpose**: Exclude small files (previews, menus) from ripping
**Default**: 100 MB
**Recommended**: 50-200 MB depending on content type

---

## Advanced Encoding Settings

Professional-grade encoding controls for optimal quality and performance.

### Encoding Speed Presets
Balances encoding speed vs. quality:

- **Ultra Fast**: Fastest encoding, lowest quality
- **Very Fast**: Good for quick previews
- **Fast**: Balanced for most users
- **Medium**: Recommended default setting
- **Slow**: Better quality, longer encoding time
- **Very Slow**: Highest quality, significantly longer encoding

### Bitrate Control Methods

**Constant Quality (CRF)** - *Recommended*
- Maintains consistent visual quality
- File size varies based on content complexity
- Best for archival purposes

**Target Bitrate (CBR)**
- Fixed bitrate throughout the file
- Predictable file sizes
- Good for streaming or bandwidth constraints

**Variable Bitrate (VBR)**
- Quality-based bitrate allocation
- Efficient for mixed content

**Constrained VBR**
- VBR with maximum bitrate limits
- Prevents excessive file sizes

### Target Bitrate Configuration
**Purpose**: Set desired output bitrate in Mbps
**Typical Values**:
- SD Content: 1-3 Mbps
- HD Content: 3-8 Mbps
- Full HD: 5-15 Mbps
- 4K Content: 15-50 Mbps

### Advanced Options

**Two-Pass Encoding**
- First pass analyzes content
- Second pass optimizes encoding
- Results in better quality at same bitrate
- Approximately doubles encoding time

**Hardware Acceleration**
- Leverages GPU for faster encoding
- Significantly reduces encoding time
- May have slight quality trade-offs
- Automatically detected and enabled when available

**Custom FFmpeg Arguments**
For advanced users who want to add specific FFmpeg parameters:
```
-tune film -preset slow -profile:v high
```

---

## Output Directory Preferences

Configure default output locations and organization patterns.

### Default Output Directory
**Purpose**: Set a persistent output location
**Setup**:
1. Click **Browse...** button
2. Select or create your preferred output folder
3. Path is saved for future sessions

**Recommended Locations**:
- `~/Movies/Ripped` - User Movies folder
- `/Volumes/External/Media` - External drive
- `~/Desktop/AutoRip` - Desktop folder

### Date-Based Subdirectories
**Purpose**: Organize rips by date of creation
**Format**: YYYY-MM-DD
**Example Structure**:
```
~/Movies/Ripped/
├── 2024-07-05/
│   ├── The Matrix (1999).mkv
│   └── Inception (2010).mkv
└── 2024-07-06/
    └── Interstellar (2014).mkv
```

### Output Path Templates
**Purpose**: Create custom directory structures using variables

**Template Variables**:
- `{output_dir}` - Base output directory
- `{media_type}` - Movies, TV Shows, etc.
- `{title}` - Content title
- `{year}` - Release year
- `{genre}` - Content genre
- `{date}` - Current date (YYYY-MM-DD)

**Example Templates**:
```
{output_dir}/{media_type}/{title}
Result: ~/Movies/Ripped/Movies/The Matrix (1999)

{output_dir}/{year}/{genre}/{title}
Result: ~/Movies/Ripped/1999/Action/The Matrix (1999)

{output_dir}/{date}/{media_type}/{title}
Result: ~/Movies/Ripped/2024-07-05/Movies/The Matrix (1999)
```

---

## Quality Presets System

Streamline your workflow with predefined and custom quality configurations.

### Predefined Presets

**Default (High Quality)**
- H.264 encoding
- High quality settings
- Good balance of quality and file size
- Recommended for most users

**Archive (Lossless)**
- Highest possible quality
- Larger file sizes
- Perfect for long-term storage
- Preserves original quality

**Mobile (Small Size)**
- Optimized for phones and tablets
- Smaller file sizes
- Lower resolution and bitrate
- Good for portable devices

**Streaming (Balanced)**
- Optimized for streaming services
- Balanced quality and bandwidth
- Fast loading times
- Good for network playback

**4K/UHD Optimized**
- High bitrate settings
- Optimized for 4K content
- Large file sizes
- Best for high-resolution displays

### Custom Preset Management

**Creating Custom Presets**:
1. Configure all settings to your preference
2. Enter a name in "Custom Preset Name" field
3. Click "Save Current as Preset"
4. Preset appears in dropdown for future use

**Using Custom Presets**:
1. Select preset from "Quality Preset" dropdown
2. All settings automatically apply
3. Make additional adjustments if needed

**Deleting Custom Presets**:
1. Select the custom preset in dropdown
2. Click "Delete Selected Preset"
3. Confirm deletion in dialog

**Preset Storage**: Custom presets are saved to your system preferences and persist between app launches.

---

## File Storage & Organization

Configure how your media library is structured and organized.

### Directory Structure Options

**Flat - All files in output directory**
- Single directory with all files
- Simple but can become cluttered
- Good for small collections

**By Media Type - Movies/TV Shows separated**
- Separate folders for different content types
- Clean organization
- Recommended for mixed collections

**By Year - Organized by release year**
- Chronological organization
- Easy to find content by era
- Good for large movie collections

**By Genre - Organized by genre**
- Groups similar content together
- Requires metadata detection
- Great for browsing by mood

**Custom - Use format strings**
- Full control using template variables
- Most flexible option
- Requires understanding of templates

### Directory Creation Options

**Create separate directories for TV series**
- Each TV show gets its own folder
- Episodes organized within show folders
- Essential for TV content management

**Create season subdirectories for TV shows**
- Further organization by season
- Structure: `TV Shows/Show Name/Season 1/`
- Recommended for long-running series

### Custom Format Strings

**Movie Directory Format**
Default: `Movies/{title} ({year})`
Examples:
```
Movies/{title} ({year})
→ Movies/The Matrix (1999)

{genre}/{title} ({year})
→ Action/The Matrix (1999)

{year}/{title}
→ 1999/The Matrix
```

**TV Show Directory Format**
Default: `TV Shows/{series}/Season {season}`
Examples:
```
TV Shows/{series}/Season {season}
→ TV Shows/Breaking Bad/Season 1

{series}/{season:02d}
→ Breaking Bad/01

Shows/{series} ({year})/S{season:02d}
→ Shows/Breaking Bad (2008)/S01
```

---

## Bonus Content Management

Control how special features and bonus content are handled.

### Bonus Content Types

**Bonus Features/Special Features**
- Behind-the-scenes content
- Deleted scenes collections
- Photo galleries

**Audio Commentaries**
- Director and cast commentaries
- Multiple audio tracks with discussion

**Deleted Scenes**
- Individual deleted scene files
- Extended or alternate versions

**Making-of Documentaries**
- Production documentaries
- Cast and crew interviews

**Trailers and Previews**
- Movie trailers
- Upcoming releases
- TV spots

### Organization Options

**Same directory as main content**
- All files in one location
- Simple but can be cluttered
- Good for minimal bonus content

**Separate 'Bonus' subdirectory**
- Creates `Bonus/` folder within movie directory
- Clean separation of main and bonus content
- Recommended default

**Separate 'Extras' subdirectory**
- Creates `Extras/` folder
- Alternative naming convention
- Good for compatibility with media servers

**Custom subdirectory name**
- Use custom folder name
- Enter name in "Custom Bonus Directory Name" field
- Full control over organization

---

## File Naming Templates

Create consistent, informative filenames using powerful template systems.

### Movie File Naming

**Default Template**: `{title} ({year}).mkv`

**Template Variables**:
- `{title}` - Movie title
- `{year}` - Release year
- `{resolution}` - Video resolution (1080p, 720p, etc.)
- `{codec}` - Video codec (H264, H265, etc.)

**Example Templates**:
```
{title} ({year}).mkv
→ The Matrix (1999).mkv

{title} ({year}) [{resolution}].mkv
→ The Matrix (1999) [1080p].mkv

{year} - {title} - {codec}.mkv
→ 1999 - The Matrix - H264.mkv
```

### TV Show File Naming

**Default Template**: `{series} - S{season:02d}E{episode:02d} - {title}.mkv`

**Template Variables**:
- `{series}` - TV series name
- `{season}` - Season number
- `{season:02d}` - Season number with leading zero
- `{episode}` - Episode number
- `{episode:02d}` - Episode number with leading zero
- `{title}` - Episode title

**Example Templates**:
```
{series} - S{season:02d}E{episode:02d} - {title}.mkv
→ Breaking Bad - S01E01 - Pilot.mkv

{series} {season}x{episode:02d} {title}.mkv
→ Breaking Bad 1x01 Pilot.mkv

{series} - Season {season} Episode {episode} - {title}.mkv
→ Breaking Bad - Season 1 Episode 1 - Pilot.mkv
```

### Season/Episode Format

**Default**: `S{season:02d}E{episode:02d}`

**Format Options**:
```
S{season:02d}E{episode:02d}    → S01E01
{season}x{episode:02d}         → 1x01
Season{season}Episode{episode} → Season1Episode1
```

### Filename Enhancement Options

**Include year in filename**
- Adds release year to all filenames
- Helps distinguish remakes and reboots
- Recommended for large collections

**Include resolution in filename**
- Adds video resolution (1080p, 720p, etc.)
- Useful when storing multiple qualities
- Good for quality comparisons

**Include codec info in filename**
- Adds video codec information
- Helps identify encoding method
- Useful for technical organization

---

## Quality & Codec Settings

Fine-tune video and audio encoding for optimal results.

### Video Codec Options

**H.264 (x264)**
- Most compatible codec
- Good quality-to-size ratio
- Widely supported
- Recommended for compatibility

**H.265 (x265/HEVC)**
- Better compression than H.264
- Smaller file sizes at same quality
- Less compatible with older devices
- Good for modern systems

**VP9**
- Open-source codec
- Good compression efficiency
- Free of licensing fees
- Limited device support

**AV1**
- Next-generation codec
- Excellent compression
- Future-proof technology
- Limited current support

### Audio Codec Options

**AAC**
- High-quality lossy codec
- Excellent compatibility
- Good for most content
- Recommended default

**AC3 (Dolby Digital)**
- Common on DVDs/Blu-rays
- Good surround sound support
- Widely compatible
- Larger file sizes than AAC

**DTS**
- High-quality audio codec
- Excellent for surround content
- Less compatible than AC3
- Good for audio enthusiasts

**FLAC**
- Lossless audio compression
- Perfect audio quality
- Large file sizes
- Good for archival

### Quality Settings

**Low (Fast)**
- Fastest encoding
- Acceptable quality for previews
- Smallest file sizes
- Good for quick tests

**Medium (Balanced)**
- Good balance of speed and quality
- Recommended for most users
- Reasonable encoding time
- Good quality results

**High (Best Quality)**
- Highest quality output
- Longer encoding times
- Larger file sizes
- Recommended for archival

**Lossless**
- Perfect quality preservation
- Very large file sizes
- Longest encoding times
- Only for critical archival

### Audio and Content Options

**Include subtitles**
- Preserves subtitle tracks
- Multiple language support
- No quality impact
- Recommended for international content

**Include chapter markers**
- Preserves DVD/Blu-ray chapters
- Easy navigation in players
- No file size impact
- Recommended for all content

### Language Preferences

**Preferred Language**
- Primary audio track language
- Automatic track selection
- Falls back to available languages
- Options: English, Spanish, French, German, Japanese, Auto-detect, All Languages

---

## Advanced Options

Expert-level settings for specialized use cases.

### File and Backup Management

**Preserve original file timestamps**
- Maintains original creation dates
- Good for archival purposes
- Preserves metadata chronology

**Create backup of original disc structure**
- Copies raw disc files before processing
- Safety net for re-processing
- Requires significant storage space

### Error Handling and Retry

**Auto-retry on failure**
- Automatically retries failed operations
- Handles temporary errors
- Improves success rate

**Max Retry Attempts**
- Number of retry attempts (default: 3)
- Prevents infinite retry loops
- Adjustable from 1-10 attempts

### Post-Processing

**Post-processing Script**
- Run custom scripts after ripping
- Automate additional tasks
- Supports shell scripts, Python, Ruby, Perl, JavaScript

**Script Examples**:
```bash
#!/bin/bash
# Move completed files to network storage
mv "$1" "/Volumes/NetworkDrive/Movies/"

# Send notification
osascript -e 'display notification "Rip completed" with title "AutoRip2MKV"'
```

**Script Variables**:
- `$1` - Output file path
- `$2` - Original disc title
- `$3` - File size in bytes

---

## Template Variables Reference

Complete reference for all available template variables.

### Universal Variables
- `{title}` - Content title
- `{year}` - Release year
- `{date}` - Current date (YYYY-MM-DD)
- `{time}` - Current time (HH-MM-SS)

### Directory Templates
- `{output_dir}` - Base output directory
- `{media_type}` - Movies, TV Shows, Music, etc.
- `{genre}` - Content genre
- `{studio}` - Production studio
- `{country}` - Country of origin

### Movie-Specific Variables
- `{title}` - Movie title
- `{year}` - Release year
- `{director}` - Director name
- `{rating}` - Content rating (PG, R, etc.)
- `{runtime}` - Duration in minutes

### TV Show Variables
- `{series}` - TV series name
- `{season}` - Season number
- `{season:02d}` - Season with leading zero
- `{episode}` - Episode number
- `{episode:02d}` - Episode with leading zero
- `{episode_title}` - Episode title
- `{air_date}` - Original air date

### Technical Variables
- `{resolution}` - Video resolution (1080p, 720p, etc.)
- `{codec}` - Video codec name
- `{audio_codec}` - Audio codec name
- `{bitrate}` - Video bitrate
- `{fps}` - Frames per second
- `{aspect_ratio}` - Video aspect ratio

### Formatting Options

**Number Formatting**:
```
{season:02d}     → 01, 02, 03 (two digits with leading zero)
{episode:03d}    → 001, 002, 003 (three digits)
{year:04d}       → 1999, 2024 (four digits)
```

**Text Formatting**:
```
{title:upper}    → THE MATRIX
{title:lower}    → the matrix
{title:title}    → The Matrix
```

**Conditional Formatting**:
```
{year:?({year})}           → (1999) if year exists, empty if not
{resolution:?[{resolution}]} → [1080p] if resolution exists
```

---

## Best Practices

### Storage Organization
1. **Use consistent naming**: Stick to one template style
2. **Plan your structure**: Design folder hierarchy before starting
3. **Consider media servers**: Use Plex/Jellyfin-compatible naming
4. **Backup important settings**: Export custom presets

### Quality Settings
1. **Start with defaults**: Use "High Quality" preset initially
2. **Test encoding speeds**: Find your speed/quality balance
3. **Consider storage space**: Higher quality = larger files
4. **Use hardware acceleration**: Enable for faster processing

### Workflow Optimization
1. **Set up automation**: Enable auto-rip for batch processing
2. **Use consistent output directories**: Simplifies organization
3. **Process similar content together**: Use same settings for series
4. **Monitor disk space**: Ensure adequate storage before starting

### Troubleshooting Prevention
1. **Test settings with one disc first**: Verify before batch processing
2. **Keep original discs**: Don't discard until verified
3. **Use post-processing scripts carefully**: Test thoroughly
4. **Regular backups**: Protect your ripped content

---

## Troubleshooting

### Common Issues

**Settings window appears black/empty**
- Solution: Restart application
- Check: macOS compatibility and permissions

**Encoding fails or crashes**
- Check: Available disk space
- Verify: FFmpeg installation
- Try: Lower quality settings or hardware acceleration disabled

**Files not organizing correctly**
- Verify: Template syntax in settings
- Check: Directory permissions
- Ensure: Metadata is available for content

**Custom presets not saving**
- Check: Application permissions
- Verify: Preset name is unique
- Try: Restarting application

### Performance Issues

**Slow encoding**
- Enable hardware acceleration
- Lower quality settings
- Close other applications
- Use faster encoding presets

**High CPU usage**
- Disable two-pass encoding
- Use hardware acceleration
- Lower encoding speed preset
- Process one disc at a time

### File Issues

**Large file sizes**
- Lower bitrate settings
- Use more efficient codecs (H.265)
- Reduce quality preset
- Enable file size filtering

**Poor quality output**
- Increase quality preset
- Use higher bitrate
- Enable two-pass encoding
- Check source disc condition

### Getting Help

1. **Check application logs**: Look for error messages
2. **Verify system requirements**: Ensure compatibility
3. **Test with different content**: Isolate disc-specific issues
4. **GitHub Issues**: Report bugs with detailed information
5. **Community forums**: Share experiences and solutions

---

## Support and Contributing

### Getting Support
- **GitHub Issues**: https://github.com/gmoyle/AutoRip2MKV-Mac/issues
- **Wiki**: https://github.com/gmoyle/AutoRip2MKV-Mac/wiki
- **Discussions**: Community support and feature requests
- **Roadmap**: See [ROADMAP.md](ROADMAP.md) for planned features and project direction

### Contributing
- **Bug Reports**: Detailed issue descriptions help improve the app
- **Feature Requests**: Suggest new functionality (check [roadmap](ROADMAP.md) first)
- **Documentation**: Help improve user guides
- **Code Contributions**: Submit pull requests for improvements

### Version Information
- **Current Version**: v1.2.0
- **Release Date**: July 2024
- **Compatibility**: macOS 10.15+
- **License**: Open source

---

*This guide covers AutoRip2MKV-Mac v1.2.0. Features and settings may vary in different versions.*
