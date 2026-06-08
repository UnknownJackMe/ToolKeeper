#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Kill existing instance if running
pkill -x ToolKeeper 2>/dev/null || true
sleep 0.5

# Generate project if needed
if [ ! -d "ToolKeeper.xcworkspace" ]; then
    echo "Generating Xcode project..."
    tuist generate --no-open
fi

# Build
echo "Building ToolKeeper..."
TUIST_SKIP_UPDATE_CHECK=1 xcodebuild build \
    -scheme ToolKeeper \
    -configuration Debug \
    -destination 'platform=macOS' \
    -quiet

# Find and launch the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ToolKeeper-*/Build/Products/Debug -name "ToolKeeper.app" -maxdepth 1 | head -1)
if [ -n "$APP_PATH" ]; then
    echo "Launching $APP_PATH"
    open "$APP_PATH"
else
    echo "Error: Could not find built app"
    exit 1
fi
