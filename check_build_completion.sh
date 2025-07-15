#!/bin/zsh

# Function to check if the build process is running
function check_build_process {
    ps aux | grep "[s]wift build"
}

# Function to notify when build is complete
function notify_build_complete {
    osascript -e 'display notification "Build complete!" with title "Swift Build"'
}

# Check periodically if the build is still running
while true; do
    if check_build_process; then
        sleep 60  # Check every minute
    else
        notify_build_complete
        break
    fi
done

