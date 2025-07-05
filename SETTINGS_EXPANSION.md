# Settings Window Expansion

## Overview
The AutoRip2MKV-Mac settings window has been significantly expanded with new sections following the established pattern, providing users with comprehensive control over the ripping and encoding process.

## New Settings Sections Added

### 1. File Organization Options
- **Auto-rename files**: Automatically rename files for better organization
- **Create year directories**: Organize content by release year
- **Create genre directories**: Organize content by genre (when metadata available)
- **Duplicate handling**: Choose how to handle duplicate files (skip, overwrite, rename with suffix, ask user)
- **Minimum file size filter**: Set minimum file size in MB to include in ripping process

### 2. Advanced Encoding Settings
- **Encoding speed**: Control encoding speed vs quality tradeoff (Ultra Fast to Very Slow)
- **Bitrate control**: Choose between CRF, CBR, VBR, or Constrained VBR
- **Target bitrate**: Set target bitrate for CBR/VBR modes
- **Two-pass encoding**: Enable for better quality at cost of speed
- **Hardware acceleration**: Leverage GPU encoding when available
- **Custom FFmpeg arguments**: Add custom command line arguments for advanced users

### 3. Output Directory Preferences
- **Default output directory**: Set a default output location with browse button
- **Create date directories**: Automatically create date-based subdirectories (YYYY-MM-DD)
- **Output path template**: Customize the directory structure using template variables

### 4. Additional Quality Presets
- **Preset selection**: Choose from predefined quality presets:
  - Default (High Quality)
  - Archive (Lossless)
  - Mobile (Small Size)
  - Streaming (Balanced)
  - 4K/UHD Optimized
  - Custom user-defined presets
- **Custom preset management**: Save current settings as named presets and delete custom presets
- **Preset name field**: Name custom presets for easy identification

## Implementation Details

### Technical Architecture
- **Consistent UI Pattern**: All new sections follow the same NSBox + NSStackView pattern as existing sections
- **Scrollable Interface**: Added scroll view to accommodate the expanded content
- **Persistent Settings**: All settings are saved to UserDefaults with proper keys
- **Default Values**: Sensible defaults are provided for all new settings
- **Validation**: Input validation for custom preset names and numeric fields

### Window Layout
- **Increased Size**: Window resized to 700x900 pixels with minimum size constraints
- **Scrollable Content**: Main content area is scrollable to accommodate all sections
- **Section Organization**: Logical grouping of related settings into labeled sections
- **Responsive Design**: Sections automatically resize with window width

### Settings Persistence
All new settings are automatically saved and loaded using the established pattern:
- File organization preferences
- Advanced encoding parameters
- Output directory configurations
- Custom quality presets

### User Experience
- **Intuitive Interface**: Clear labels and organized sections
- **Browse Buttons**: File/directory browsers for path selection
- **Preset Management**: Easy saving and loading of custom configurations
- **Default Restoration**: One-click restore to sensible defaults
- **Real-time Validation**: Immediate feedback for invalid inputs

## Usage
1. Open the settings window from the main interface
2. Navigate through the expanded sections to configure preferences
3. Use preset management to save frequently used configurations
4. Apply settings to persist changes
5. Settings are automatically loaded on next application launch

## Future Extensibility
The established pattern makes it easy to add more settings sections:
1. Add UI property declarations
2. Create setup method following the pattern
3. Add to main stack view in setupUI()
4. Update save/load methods
5. Update restore defaults

This modular approach ensures consistent UI and behavior across all settings sections.
