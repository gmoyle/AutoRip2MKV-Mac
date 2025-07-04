# AutoRip2MKV-Mac Assets

This directory contains all the visual assets for the AutoRip2MKV-Mac project, including icons, logos, and branding materials.

## Files Overview

### Icons
- **`icon.svg`** - Main application icon (512x512) with full detail and macOS-style design
- **`icon-simple.svg`** - Simplified icon version (128x128) for smaller sizes and favicons
- **`icon.icns`** - macOS application bundle icon (generated from SVG)
- **`icon.png`** - PNG version of the main icon for broader compatibility

### Logos
- **`logo.svg`** - Horizontal logo with text and icon elements (400x120)
- **`logo-animated.svg`** - Animated version with rotating disc and pulsing effects
- **`logo-banner.svg`** - Wide banner format for headers and documentation

### Design Elements

#### Color Palette
- **DVD/Disc Gray**: `#e8e8e8` to `#a0a0a0` (gradient)
- **Apple Blue**: `#007AFF` to `#0051D5` (conversion arrow)
- **Success Green**: `#34C759` to `#248A3D` (MKV file)
- **Text Dark**: `#1d1d1f` to `#515154` (primary text)
- **Secondary Gray**: `#666666` (secondary text)

#### Typography
- **Primary Font**: SF Pro Display (Apple system font)
- **Monospace**: SF Mono (for code/technical elements)
- **Fallbacks**: -apple-system, BlinkMacSystemFont, sans-serif

#### Design Concepts
1. **DVD/Blu-ray Disc**: Represents source media with realistic concentric data tracks
2. **Conversion Arrow**: Shows the transformation process in Apple blue
3. **MKV File**: Green file icon representing the output format
4. **macOS Native**: Follows Apple's design guidelines and aesthetic

## Usage Guidelines

### Application Icon
Use `icon.svg` or `icon.icns` for:
- macOS application bundle
- App Store submissions
- Dock icons
- Large promotional materials

### Simple Icon
Use `icon-simple.svg` for:
- Favicons (16x16, 32x32)
- Small UI elements
- Menu bar icons
- Toolbar buttons

### Logos
- **Static Logo**: Use `logo.svg` for documentation, websites, business cards
- **Animated Logo**: Use `logo-animated.svg` for web headers, splash screens
- **Banner**: Use `logo-banner.svg` for wide format displays

### Color Variations
The assets are designed to work well on:
- Light backgrounds (primary use case)
- Dark backgrounds (ensure sufficient contrast)
- Monochrome applications (maintain hierarchy)

## Technical Specifications

### SVG Features
- Vector-based for infinite scalability
- Embedded gradients and effects
- Web-safe color palette
- Optimized for small file sizes

### Animations (logo-animated.svg)
- **Disc Rotation**: 4-second continuous rotation
- **Arrow Pulse**: 2-second scale animation
- **Progress Bar**: 6-second fill animation
- **Text Fade**: 4-second opacity animation

### Export Guidelines
When converting to other formats:
- **PNG**: Export at 2x resolution for retina displays
- **ICO**: Include multiple sizes (16, 32, 48, 64, 128, 256px)
- **ICNS**: Use Apple's iconutil for proper macOS integration

## File Generation

### Creating ICNS for macOS
```bash
# Create iconset directory
mkdir icon.iconset

# Generate required sizes
sips -z 16 16 icon.png --out icon.iconset/icon_16x16.png
sips -z 32 32 icon.png --out icon.iconset/icon_16x16@2x.png
sips -z 32 32 icon.png --out icon.iconset/icon_32x32.png
sips -z 64 64 icon.png --out icon.iconset/icon_32x32@2x.png
sips -z 128 128 icon.png --out icon.iconset/icon_128x128.png
sips -z 256 256 icon.png --out icon.iconset/icon_128x128@2x.png
sips -z 256 256 icon.png --out icon.iconset/icon_256x256.png
sips -z 512 512 icon.png --out icon.iconset/icon_256x256@2x.png
sips -z 512 512 icon.png --out icon.iconset/icon_512x512.png
sips -z 1024 1024 icon.png --out icon.iconset/icon_512x512@2x.png

# Create ICNS file
iconutil -c icns icon.iconset
```

### Browser Favicon
```html
<link rel="icon" type="image/svg+xml" href="/assets/icon-simple.svg">
<link rel="icon" type="image/png" href="/assets/icon-simple.png">
```

## Brand Guidelines

### Do's
✅ Use the provided color palette consistently  
✅ Maintain proper spacing around logos  
✅ Scale proportionally without distortion  
✅ Use on appropriate background colors  
✅ Follow macOS design principles  

### Don'ts
❌ Modify colors or gradients  
❌ Stretch or skew the logo  
❌ Use low-resolution versions for large displays  
❌ Place on backgrounds with poor contrast  
❌ Add effects or filters not in the original design  

## Build Integration

### Automated Icon Generation
The project includes scripts to automatically generate all required icon formats:

```bash
# Generate PNG versions for web/docs
./scripts/generate-png.sh

# Generate .icns for macOS app bundle
./scripts/generate-icns.sh

# Build app with integrated icons
./scripts/build-with-icons.sh
```

### Application Bundle
When building the application, icons are automatically integrated:
- `AppIcon.icns` → Application bundle icon
- `Info.plist` → Configured with proper icon references
- Assets directory → Included in app resources

### Requirements
- **librsvg** for SVG to PNG conversion: `brew install librsvg`
- **iconutil** (included with macOS) for .icns creation
- **hdiutil** (included with macOS) for DMG creation

## License

These assets are part of the AutoRip2MKV-Mac project and are licensed under the MIT License. See the main project LICENSE file for details.
