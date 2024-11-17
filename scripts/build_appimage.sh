#!/bin/bash

# Exit on error
set -e

# Configuration
APP_NAME="xenia-launcher"
FLUTTER_APP_DIR="$(pwd)"
BUILD_DIR="$FLUTTER_APP_DIR/build"
APPIMAGE_DIR="$BUILD_DIR/appimage"
LINUX_BUILD_DIR="$BUILD_DIR/linux/x64/release/bundle"

# Clean previous builds
rm -rf "$APPIMAGE_DIR"
mkdir -p "$APPIMAGE_DIR"

# Build Flutter app in release mode
flutter build linux --release

# Create AppDir structure
mkdir -p "$APPIMAGE_DIR/AppDir"
mkdir -p "$APPIMAGE_DIR/AppDir/usr/bin"
mkdir -p "$APPIMAGE_DIR/AppDir/usr/share/applications"
mkdir -p "$APPIMAGE_DIR/AppDir/usr/share/icons/hicolor/scalable/apps"
mkdir -p "$APPIMAGE_DIR/AppDir/usr/bin/tools"

# Copy the built application
cp -r "$LINUX_BUILD_DIR"/* "$APPIMAGE_DIR/AppDir/usr/bin/"

# Copy tools
cp -r "$FLUTTER_APP_DIR/tools"/* "$APPIMAGE_DIR/AppDir/usr/bin/tools/"
chmod +x "$APPIMAGE_DIR/AppDir/usr/bin/tools/extract-xiso"

# Ensure assets directory exists in the bundle
mkdir -p "$APPIMAGE_DIR/AppDir/usr/bin/data/flutter_assets/assets"
cp -r "$FLUTTER_APP_DIR/assets"/* "$APPIMAGE_DIR/AppDir/usr/bin/data/flutter_assets/assets/"

# Copy icon for the application
cp "$FLUTTER_APP_DIR/assets/icon.svg" "$APPIMAGE_DIR/AppDir/$APP_NAME.svg"
cp "$FLUTTER_APP_DIR/assets/icon.svg" "$APPIMAGE_DIR/AppDir/usr/share/icons/hicolor/scalable/apps/$APP_NAME.svg"

# Create desktop entry in both locations (AppDir root and usr/share/applications)
cat > "$APPIMAGE_DIR/AppDir/$APP_NAME.desktop" << EOF
[Desktop Entry]
Name=Xenia Launcher
Comment=Xbox 360 Game Launcher for Xenia
Exec=xenia_launcher
Icon=$APP_NAME
Type=Application
Categories=Game;Emulator;
EOF

# Copy desktop file to the usr/share/applications directory
cp "$APPIMAGE_DIR/AppDir/$APP_NAME.desktop" "$APPIMAGE_DIR/AppDir/usr/share/applications/"

# Create AppRun script
cat > "$APPIMAGE_DIR/AppDir/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin/:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib/:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/xenia_launcher" "$@"
EOF

chmod +x "$APPIMAGE_DIR/AppDir/AppRun"

# Download appimagetool if not present
if [ ! -f "$BUILD_DIR/appimagetool" ]; then
    wget -O "$BUILD_DIR/appimagetool" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x "$BUILD_DIR/appimagetool"
fi

# Create AppImage
cd "$APPIMAGE_DIR"
ARCH=x86_64 "$BUILD_DIR/appimagetool" AppDir "$APP_NAME.AppImage"

echo "AppImage created at $APPIMAGE_DIR/$APP_NAME.AppImage"
