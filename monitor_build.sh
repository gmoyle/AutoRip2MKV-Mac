#!/bin/bash

echo "Swift Build Progress Monitor"
echo "Checking every 30 seconds..."
echo "Press Ctrl+C to stop"
echo "========================="

# Count total Swift files to estimate progress
TOTAL_FILES=$(find Sources -name "*.swift" | wc -l | tr -d ' ')
echo "Total Swift files: $TOTAL_FILES"
echo ""

START_TIME=$(date +%s)

while true; do
    # Check for swift processes
    SWIFT_PROCESSES=$(ps aux | grep -E "(swift-frontend|swiftc|swift-build)" | grep -v grep)
    
    if [ -z "$SWIFT_PROCESSES" ]; then
        echo "\n✅ BUILD COMPLETE - No Swift processes running"
        break
    fi
    
    # Get current time and calculate elapsed
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))
    ELAPSED_SEC=$((ELAPSED % 60))
    
    # Check how many .o files have been created (compiled files)
    COMPILED_FILES=$(find .build -name "*.o" 2>/dev/null | wc -l | tr -d ' ')
    
    # Calculate rough progress percentage
    if [ $TOTAL_FILES -gt 0 ]; then
        PROGRESS=$((COMPILED_FILES * 100 / TOTAL_FILES))
        if [ $PROGRESS -gt 100 ]; then
            PROGRESS=100
        fi
    else
        PROGRESS=0
    fi
    
    # Get CPU usage of main compiler process
    CPU_USAGE=$(ps aux | grep swift-frontend | grep -v grep | awk '{print $3}' | head -1)
    
    # Clear line and show progress
    printf "\r⏳ Progress: %d%% | Compiled: %d/%d files | Time: %02d:%02d | CPU: %s%%" \
           $PROGRESS $COMPILED_FILES $TOTAL_FILES $ELAPSED_MIN $ELAPSED_SEC "${CPU_USAGE:-0}"
    
    sleep 30
done

echo "\nBuild monitoring stopped."
