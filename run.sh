#!/bin/bash

# Set the scheme and configuration
SCHEME="TagManager"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="build"

echo "Building $SCHEME..."

# Build the project
xcodebuild -project TagManager.xcodeproj \
           -scheme "$SCHEME" \
           -configuration "$CONFIGURATION" \
           -derivedDataPath "$DERIVED_DATA_PATH" \
           build

# Check if build succeeded
if [ $? -ne 0 ]; then
    echo "Build failed."
    exit 1
fi

echo "Build succeeded."

# Locate the app
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$SCHEME.app"

if [ -d "$APP_PATH" ]; then
    echo "Launching $APP_PATH..."
    # Open the app
    open "$APP_PATH"
else
    echo "Error: App not found at $APP_PATH"
    exit 1
fi
