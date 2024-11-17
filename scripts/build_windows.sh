#!/bin/bash

# Exit on error
set -e

# Configuration
APP_NAME="xenia-launcher"
FLUTTER_APP_DIR="$(pwd)"
BUILD_DIR="$FLUTTER_APP_DIR/build"
WINDOWS_BUILD_DIR="$BUILD_DIR/windows"

# Ensure we have the Windows build requirements
command -v wine >/dev/null 2>&1 || { echo "wine is required but not installed. Aborting." >&2; exit 1; }

# Clean previous builds
rm -rf "$WINDOWS_BUILD_DIR"
mkdir -p "$WINDOWS_BUILD_DIR"

# Build Flutter app in release mode for Windows
flutter config --enable-windows-desktop
flutter build windows --release

# Create a ZIP archive of the Windows build
cd "$BUILD_DIR/windows/x64/Release"
zip -r "$WINDOWS_BUILD_DIR/$APP_NAME-windows.zip" *

echo "Windows build created at $WINDOWS_BUILD_DIR/$APP_NAME-windows.zip"
