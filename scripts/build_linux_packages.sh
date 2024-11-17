#!/bin/bash

# Exit on error
set -e

# Configuration
APP_NAME="xenia-launcher"
VERSION="1.0.0"
FLUTTER_APP_DIR="$(pwd)"
BUILD_DIR="$FLUTTER_APP_DIR/build"
PACKAGE_DIR="$BUILD_DIR/packages"
LINUX_BUILD_DIR="$BUILD_DIR/linux/x64/release/bundle"

# Clean previous builds
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Build Flutter app in release mode
flutter build linux --release

# Function to create DEB package
create_deb() {
    local DEB_DIR="$PACKAGE_DIR/deb"
    local INSTALL_DIR="$DEB_DIR/usr/local/bin/$APP_NAME"
    local DESKTOP_DIR="$DEB_DIR/usr/share/applications"
    local ICON_DIR="$DEB_DIR/usr/share/icons/hicolor/256x256/apps"
    
    # Create directory structure
    mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR" "$ICON_DIR" "$DEB_DIR/DEBIAN"
    
    # Copy application files
    cp -r "$LINUX_BUILD_DIR"/* "$INSTALL_DIR/"
    
    # Copy tools
    mkdir -p "$INSTALL_DIR/tools"
    cp -r "$FLUTTER_APP_DIR/tools"/* "$INSTALL_DIR/tools/"
    chmod +x "$INSTALL_DIR/tools/extract-xiso"
    
    # Ensure assets directory exists in the bundle
    mkdir -p "$INSTALL_DIR/data/flutter_assets/assets"
    cp -r "$FLUTTER_APP_DIR/assets"/* "$INSTALL_DIR/data/flutter_assets/assets/"
    
    # Create desktop entry
    cat > "$DESKTOP_DIR/$APP_NAME.desktop" << EOF
[Desktop Entry]
Name=Xenia Launcher
Comment=Xbox 360 Game Launcher for Xenia
Exec=/usr/local/bin/$APP_NAME/xenia_launcher
Icon=$APP_NAME
Type=Application
Categories=Game;Emulator;
EOF
    
    # Create control file
    cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: $APP_NAME
Version: $VERSION
Section: games
Priority: optional
Architecture: amd64
Maintainer: Your Name <your.email@example.com>
Description: Xbox 360 Game Launcher for Xenia
 A launcher application for the Xenia Xbox 360 emulator.
EOF
    
    # Build DEB package
    dpkg-deb --build "$DEB_DIR" "$PACKAGE_DIR/${APP_NAME}_${VERSION}_amd64.deb"
}

# Function to create RPM package
create_rpm() {
    local RPM_DIR="$PACKAGE_DIR/rpm"
    local SPEC_FILE="$RPM_DIR/$APP_NAME.spec"
    
    # Create RPM build structure
    mkdir -p "$RPM_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    
    # Create spec file
    cat > "$SPEC_FILE" << EOF
Name:           $APP_NAME
Version:        $VERSION
Release:        1%{?dist}
Summary:        Xbox 360 Game Launcher for Xenia
License:        MIT
URL:            https://github.com/yourusername/$APP_NAME
BuildArch:      x86_64

%description
A launcher application for the Xenia Xbox 360 emulator.

%install
mkdir -p %{buildroot}/usr/local/bin/$APP_NAME
mkdir -p %{buildroot}/usr/share/applications
mkdir -p %{buildroot}/usr/share/icons/hicolor/scalable/apps

# Copy application files
cp -r $LINUX_BUILD_DIR/* %{buildroot}/usr/local/bin/$APP_NAME/

# Copy tools
mkdir -p %{buildroot}/usr/local/bin/$APP_NAME/tools
cp -r $FLUTTER_APP_DIR/tools/* %{buildroot}/usr/local/bin/$APP_NAME/tools/
chmod +x %{buildroot}/usr/local/bin/$APP_NAME/tools/extract-xiso

# Ensure assets directory exists
mkdir -p %{buildroot}/usr/local/bin/$APP_NAME/data/flutter_assets/assets
cp -r $FLUTTER_APP_DIR/assets/* %{buildroot}/usr/local/bin/$APP_NAME/data/flutter_assets/assets/

# Copy icon
cp $FLUTTER_APP_DIR/assets/icon.svg %{buildroot}/usr/share/icons/hicolor/scalable/apps/$APP_NAME.svg

# Create desktop entry
cat > %{buildroot}/usr/share/applications/$APP_NAME.desktop << EOL
[Desktop Entry]
Name=Xenia Launcher
Comment=Xbox 360 Game Launcher for Xenia
Exec=/usr/local/bin/$APP_NAME/xenia_launcher
Icon=$APP_NAME
Type=Application
Categories=Game;Emulator;
EOL

%files
/usr/local/bin/$APP_NAME
/usr/share/applications/$APP_NAME.desktop
/usr/share/icons/hicolor/scalable/apps/$APP_NAME.svg
EOF
    
    # Build RPM package
    rpmbuild --define "_topdir $RPM_DIR" -bb "$SPEC_FILE"
}

# Create packages
echo "Creating DEB package..."
create_deb

echo "Creating RPM package..."
if command -v rpmbuild >/dev/null 2>&1; then
    create_rpm
else
    echo "rpmbuild not found. Skipping RPM package creation."
fi

echo "Packages created in $PACKAGE_DIR"
