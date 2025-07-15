# Detailed Settings Guide for AutoRip2MKV-Mac

This guide explains the comprehensive settings system that allows users to customize how files are stored, organized, and how bonus content is handled.

## Overview

The detailed settings dialog provides extensive configuration options for:
- File storage and directory organization
- Bonus content inclusion and organization
- File naming conventions
- Quality and codec settings
- Advanced processing options

## Default Configuration

AutoRip2MKV-Mac comes with sensible defaults that work well for most users:

### File Storage & Organization (Default)
- **Directory Structure**: By Media Type (Movies/TV Shows separated)
- **Create Series Directories**: Enabled (TV shows get their own folders)
- **Create Season Directories**: Enabled (Season 1, Season 2, etc.)
- **Movie Directory Format**: `Movies/{title} ({year})`
- **TV Show Directory Format**: `TV Shows/{series}/Season {season}`

### Bonus Content (Default)
- **Include Bonus Features**: Disabled
- **Include Commentaries**: Disabled
- **Include Deleted Scenes**: Disabled
- **Include Making-of Documentaries**: Disabled
- **Include Trailers**: Disabled
- **Bonus Content Organization**: Separate 'Bonus' subdirectory
- **Bonus Directory Name**: "Bonus"

### File Naming (Default)
- **Movie File Format**: `{title} ({year}).mkv`
- **TV Episode Format**: `{series} - S{season:02d}E{episode:02d} - {title}.mkv`
- **Season/Episode Format**: `S{season:02d}E{episode:02d}`
- **Include Year in Filename**: Enabled
- **Include Resolution in Filename**: Disabled
- **Include Codec in Filename**: Disabled

### Quality & Codecs (Default)
- **Video Codec**: H.264 (x264)
- **Audio Codec**: AAC
- **Quality**: High (Best Quality)
- **Include Subtitles**: Enabled
- **Include Chapters**: Enabled
- **Preferred Language**: English

### Advanced Options (Default)
- **Hardware Acceleration**: Disabled (VideoToolbox on supported systems)
- **Preserve Original Timestamps**: Disabled
- **Create Backups**: Disabled
- **Auto-retry on Failure**: Enabled
- **Max Retry Attempts**: 3
- **Post-processing Script**: None

## Directory Structure Options

### 1. Flat Structure
All files are placed directly in the output directory with no subdirectories.

Example:
```
/Output/
├── Movie Title (2023).mkv
├── Another Movie (2022).mkv
└── TV Show - S01E01 - Episode Title.mkv
```

### 2. By Media Type (Default)
Separates movies and TV shows into different directories.

Example:
```
/Output/
├── Movies/
│   ├── Movie Title (2023)/
│   │   └── Movie Title (2023).mkv
│   └── Another Movie (2022)/
│       └── Another Movie (2022).mkv
└── TV Shows/
    └── TV Show Name/
        └── Season 1/
            └── TV Show - S01E01 - Episode Title.mkv
```

### 3. By Year
Organizes content by release year.

Example:
```
/Output/
├── 2023/
│   └── Movie Title/
│       └── Movie Title (2023).mkv
└── 2022/
    └── Another Movie/
        └── Another Movie (2022).mkv
```

### 4. By Genre
Organizes content by genre (when available).

Example:
```
/Output/
├── Action/
│   └── Action Movie (2023).mkv
├── Comedy/
│   └── Funny Movie (2022).mkv
└── Drama/
    └── Serious Show - S01E01 - Episode Title.mkv
```

### 5. Custom Format Strings
Use custom format strings with variables:

Available variables:
- `{title}` - Media title
- `{year}` - Release year
- `{series}` - TV series name
- `{season}` - Season number
- `{genre}` - Genre (when available)

## Bonus Content Organization

### Content Types
- **Bonus Features/Special Features**: General bonus content
- **Audio Commentaries**: Director/cast commentaries
- **Deleted Scenes**: Scenes not included in final cut
- **Making-of Documentaries**: Behind-the-scenes content
- **Trailers and Previews**: Movie trailers and previews

### Organization Options
1. **Same Directory**: Bonus content mixed with main content
2. **Separate 'Bonus' Subdirectory**: Default bonus folder
3. **Separate 'Extras' Subdirectory**: Alternative naming
4. **Custom Subdirectory**: User-defined folder name

Example with bonus content:
```
/Output/Movies/Movie Title (2023)/
├── Movie Title (2023).mkv
└── Bonus/
    ├── Behind the Scenes.mkv
    ├── Director Commentary.mkv
    └── Deleted Scenes.mkv
```

## File Naming Format Strings

### Movie Format Variables
- `{title}` - Movie title
- `{year}` - Release year

Example: `{title} ({year}).mkv` → `Inception (2010).mkv`

### TV Show Format Variables
- `{series}` - Series name
- `{season}` - Season number
- `{season:02d}` - Zero-padded season (01, 02, etc.)
- `{episode}` - Episode number
- `{episode:02d}` - Zero-padded episode (01, 02, etc.)
- `{title}` - Episode title

Example: `{series} - S{season:02d}E{episode:02d} - {title}.mkv`
→ `Breaking Bad - S01E01 - Pilot.mkv`

### Additional Filename Options
- **Include Resolution**: Adds resolution tag like `[1080p]`
- **Include Codec**: Adds codec tag like `[x264]`

Example with options: `Movie Title (2023) [1080p] [x264].mkv`

## Advanced Features

### Hardware Acceleration

AutoRip2MKV-Mac supports hardware acceleration through Apple's VideoToolbox framework for improved encoding performance.

#### How It Works
- **VideoToolbox**: Uses your Mac's dedicated hardware encoders (when available)
- **Performance**: Significantly faster encoding, especially on newer Macs
- **Quality**: Maintains high quality while reducing processing time
- **Compatibility**: Works on Macs with hardware encoders (most modern systems)

#### First-Run Detection
On first launch, AutoRip2MKV will:
1. **Test Hardware Support**: Check if your Mac supports VideoToolbox acceleration
2. **Offer Setup**: If supported, display a dialog asking if you want to enable it
3. **Save Preference**: Your choice is remembered for future sessions

#### Manual Configuration
You can also enable/disable hardware acceleration in the detailed settings:
1. Open the Settings dialog
2. Look for the "Hardware Acceleration" checkbox in the Advanced section
3. Check to enable, uncheck to disable
4. Click "OK" to save changes

#### When to Use
- **Enable**: For faster processing on supported systems
- **Disable**: If experiencing quality issues or on older hardware
- **Default**: Disabled for maximum compatibility

#### Troubleshooting
If you experience issues with hardware acceleration:
1. Try disabling it in Settings
2. Restart the application
3. Process a test disc to verify the issue is resolved

### Post-processing Scripts
You can specify a script to run after each rip completes. The script receives:
1. Output file path
2. Media title
3. Release year

Supported script types: Shell (.sh), Python (.py), Ruby (.rb), Perl (.pl), JavaScript (.js)

### Retry Logic
- Automatically retry failed operations
- Configurable number of retry attempts
- Helpful for handling temporary disc read errors

### Backup Options
- Create backup of original disc structure
- Preserve original file timestamps
- Useful for archival purposes

## Using the Settings

### Accessing Settings
1. Launch AutoRip2MKV-Mac
2. Click the "Settings..." button in the main window
3. Configure your preferences in the detailed settings dialog
4. Click "OK" to save or "Cancel" to discard changes

### Restoring Defaults
Click "Restore Defaults" in the settings dialog to reset all options to their default values.

### Settings Storage
All settings are automatically saved to macOS user defaults and persist between application launches.

## Tips for Best Results

1. **Use Media Type organization** for most users - it provides the best balance of organization and simplicity.

2. **Enable bonus content selectively** - Only include the types you actually want to preserve storage space.

3. **Use consistent naming formats** - Stick to one format for better media library compatibility.

4. **Test with sample discs** before processing large collections.

5. **Consider your media player** - Some players work better with specific directory structures and naming conventions.

## Compatibility

The default settings are designed to work well with popular media management software including:
- Plex Media Server
- Jellyfin
- Emby
- Kodi/XBMC
- Infuse

The format strings and directory structures follow common naming conventions used by these applications for automatic metadata detection.
