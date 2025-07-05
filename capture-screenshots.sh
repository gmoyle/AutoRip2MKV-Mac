#!/bin/bash

# AutoRip2MKV-Mac Screenshot Capture Script
# This script builds the app, launches it, and captures screenshots for documentation

set -e  # Exit on any error

echo "🎬 AutoRip2MKV-Mac Screenshot Capture Script"
echo "============================================="

# Configuration
APP_NAME="AutoRip2MKV-Mac"
SCREENSHOTS_DIR="$(pwd)/screenshots"
WIKI_DIR="../AutoRip2MKV-Mac.wiki"
BUILD_DIR=".build/debug"

# Create screenshots directory
mkdir -p "$SCREENSHOTS_DIR"

echo "📁 Screenshots will be saved to: $SCREENSHOTS_DIR"

# Function to capture screenshot with delay
capture_screenshot() {
    local filename="$1"
    local description="$2"
    local delay="${3:-2}"
    
    echo "📸 Capturing: $description"
    echo "   Waiting ${delay} seconds..."
    sleep "$delay"
    
    # Capture screenshot using screencapture
    screencapture -x -o -t png "$SCREENSHOTS_DIR/$filename"
    
    if [ -f "$SCREENSHOTS_DIR/$filename" ]; then
        echo "   ✅ Saved: $filename"
    else
        echo "   ❌ Failed to capture: $filename"
    fi
}

# Function to simulate key press
simulate_key() {
    local key="$1"
    osascript -e "tell application \"System Events\" to key code $key"
}

# Function to simulate click at coordinates
simulate_click() {
    local x="$1"
    local y="$2"
    osascript -e "tell application \"System Events\" to click at {$x, $y}"
}

# Function to open settings window
open_settings() {
    echo "🔧 Opening settings window..."
    # Use AppleScript to click the Settings button
    osascript -e 'tell application "System Events"
        tell process "AutoRip2MKV-Mac"
            click button "Settings..." of window 1
        end tell
    end tell' 2>/dev/null || echo "   Note: Manual settings opening may be needed"
}

# Function to close current window
close_window() {
    osascript -e 'tell application "System Events" to keystroke "w" using command down' 2>/dev/null
}

# Build the application
echo "🔨 Building AutoRip2MKV-Mac..."
cd /Users/gregmoyle/Documents/GitHub/AutoRip2MKV-Mac
swift build --configuration debug

if [ ! -f "$BUILD_DIR/$APP_NAME" ]; then
    echo "❌ Build failed - executable not found at $BUILD_DIR/$APP_NAME"
    exit 1
fi

echo "✅ Build successful!"

# Kill any existing instances
echo "🔄 Stopping any existing instances..."
pkill -f "$APP_NAME" 2>/dev/null || true
sleep 1

# Launch the application in background
echo "🚀 Launching AutoRip2MKV-Mac..."
"./$BUILD_DIR/$APP_NAME" &
APP_PID=$!

# Wait for app to fully load
echo "⏳ Waiting for application to load..."
sleep 3

# Bring app to front
osascript -e 'tell application "AutoRip2MKV-Mac" to activate' 2>/dev/null || true
sleep 1

echo "📸 Starting screenshot capture sequence..."

# 1. Main Interface Screenshot
capture_screenshot "01-main-interface.png" "Main application interface" 2

# 2. Settings Button Area (zoomed)
echo "🎯 Focusing on settings area..."
capture_screenshot "02-settings-button.png" "Settings button location" 1

# 3. Open Settings Window
echo "🔧 Opening settings window..."
open_settings
sleep 3

# 4. Settings Window Overview
capture_screenshot "03-settings-overview.png" "Complete settings window" 2

# 5. File Organization Section (scroll to top)
echo "📁 Capturing File Organization section..."
osascript -e 'tell application "System Events" to key code 115' # Home key
sleep 1
capture_screenshot "04-file-organization.png" "File Organization Options" 2

# 6. Advanced Encoding Section (scroll down a bit)
echo "⚙️ Capturing Advanced Encoding section..."
for i in {1..3}; do
    osascript -e 'tell application "System Events" to key code 125' # Down arrow
    sleep 0.2
done
capture_screenshot "05-advanced-encoding.png" "Advanced Encoding Settings" 2

# 7. Output Directory Section
echo "📂 Capturing Output Directory section..."
for i in {1..3}; do
    osascript -e 'tell application "System Events" to key code 125' # Down arrow
    sleep 0.2
done
capture_screenshot "06-output-directory.png" "Output Directory Preferences" 2

# 8. Quality Presets Section
echo "🎯 Capturing Quality Presets section..."
for i in {1..3}; do
    osascript -e 'tell application "System Events" to key code 125' # Down arrow
    sleep 0.2
done
capture_screenshot "07-quality-presets.png" "Quality Presets System" 2

# 9. File Storage Section
echo "💾 Capturing File Storage section..."
for i in {1..3}; do
    osascript -e 'tell application "System Events" to key code 125' # Down arrow
    sleep 0.2
done
capture_screenshot "08-file-storage.png" "File Storage & Organization" 2

# 10. Bonus Content Section
echo "🎬 Capturing Bonus Content section..."
for i in {1..3}; do
    osascript -e 'tell application "System Events" to key code 125' # Down arrow
    sleep 0.2
done
capture_screenshot "09-bonus-content.png" "Bonus Content Management" 2

# 11. File Naming Section
echo "🏷️ Capturing File Naming section..."
for i in {1..3}; do
    osascript -e 'tell application "System Events" to key code 125' # Down arrow
    sleep 0.2
done
capture_screenshot "10-file-naming.png" "File Naming Templates" 2

# 12. Quality & Codecs Section
echo "🎨 Capturing Quality & Codecs section..."
for i in {1..3}; do
    osascript -e 'tell application "System Events" to key code 125' # Down arrow
    sleep 0.2
done
capture_screenshot "11-quality-codecs.png" "Quality & Codec Settings" 2

# 13. Advanced Options Section
echo "🔬 Capturing Advanced Options section..."
for i in {1..3}; do
    osascript -e 'tell application "System Events" to key code 125' # Down arrow
    sleep 0.2
done
capture_screenshot "12-advanced-options.png" "Advanced Options" 2

# 14. Dialog Buttons (scroll to bottom)
echo "🔘 Capturing dialog buttons..."
osascript -e 'tell application "System Events" to key code 119' # End key
sleep 1
capture_screenshot "13-dialog-buttons.png" "Settings dialog buttons" 1

# 15. Template Example (focus on a text field)
echo "📝 Capturing template example..."
osascript -e 'tell application "System Events" to key code 115' # Home key to go back to top
sleep 1
# Try to click on a template field
osascript -e 'tell application "System Events"
    tell process "AutoRip2MKV-Mac"
        try
            set frontWindow to window 1
            click text field 1 of frontWindow
        end try
    end tell
end tell' 2>/dev/null
sleep 1
capture_screenshot "14-template-example.png" "Template field example" 1

# 16. Cancel/Close settings
echo "❌ Closing settings window..."
close_window
sleep 2
capture_screenshot "15-back-to-main.png" "Return to main interface" 1

# Clean up - stop the application
echo "🛑 Stopping application..."
kill $APP_PID 2>/dev/null || true
sleep 1

# Create a summary report
echo "📊 Creating screenshot summary..."
cat > "$SCREENSHOTS_DIR/README.md" << EOF
# AutoRip2MKV-Mac Screenshots

Generated on: $(date)

## Screenshots Captured

1. **01-main-interface.png** - Main application interface
2. **02-settings-button.png** - Settings button location
3. **03-settings-overview.png** - Complete settings window
4. **04-file-organization.png** - File Organization Options
5. **05-advanced-encoding.png** - Advanced Encoding Settings
6. **06-output-directory.png** - Output Directory Preferences
7. **07-quality-presets.png** - Quality Presets System
8. **08-file-storage.png** - File Storage & Organization
9. **09-bonus-content.png** - Bonus Content Management
10. **10-file-naming.png** - File Naming Templates
11. **11-quality-codecs.png** - Quality & Codec Settings
12. **12-advanced-options.png** - Advanced Options
13. **13-dialog-buttons.png** - Settings dialog buttons
14. **14-template-example.png** - Template field example
15. **15-back-to-main.png** - Return to main interface

## Usage in Documentation

Copy these screenshots to your wiki's images folder and reference them in markdown:

\`\`\`markdown
![Main Interface](images/01-main-interface.png)
\`\`\`

## Optimization

Screenshots are saved as PNG files. Consider optimizing them:

\`\`\`bash
# Optimize with ImageOptim or similar tools
# Or use built-in compression:
for img in *.png; do
    sips -s formatOptions 70 "\$img"
done
\`\`\`
EOF

# Count successful screenshots
screenshot_count=$(ls -1 "$SCREENSHOTS_DIR"/*.png 2>/dev/null | wc -l)
total_screenshots=15

echo ""
echo "🎉 Screenshot capture complete!"
echo "📊 Captured: $screenshot_count/$total_screenshots screenshots"
echo "📁 Location: $SCREENSHOTS_DIR"
echo ""

if [ "$screenshot_count" -eq "$total_screenshots" ]; then
    echo "✅ All screenshots captured successfully!"
else
    echo "⚠️  Some screenshots may have failed. Check the screenshots directory."
fi

echo ""
echo "🔄 Next steps:"
echo "1. Review screenshots in: $SCREENSHOTS_DIR"
echo "2. Copy images to wiki: cp screenshots/*.png $WIKI_DIR/images/"
echo "3. Update documentation with image references"
echo "4. Commit and push wiki changes"
echo ""

# Optional: Open screenshots folder
if command -v open >/dev/null 2>&1; then
    echo "📂 Opening screenshots folder..."
    open "$SCREENSHOTS_DIR"
fi

echo "🎬 Screenshot capture script completed!"
