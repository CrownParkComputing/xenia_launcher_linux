Name:           xenia-launcher
Version:        1.0.0
Release:        1%{?dist}
Summary:        A Xenia Emulator Launcher
License:        MIT
URL:            https://github.com/xenia-project/xenia-launcher
BuildArch:      x86_64

Requires:       gtk3
Requires:       libglvnd-glx
Requires:       mesa-libGL

%description
A launcher application for the Xenia Xbox 360 emulator.

%install
mkdir -p %{buildroot}/opt/xenia-launcher
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications

# Copy the entire bundle directory
cp -r %{_sourcedir}/build/linux/x64/release/bundle/* %{buildroot}/opt/xenia-launcher/

# Create launcher script
cat > %{buildroot}/usr/bin/xenia-launcher << 'EOF'
#!/bin/sh
cd /opt/xenia-launcher
exec ./xenia_launcher "$@"
EOF
chmod 755 %{buildroot}/usr/bin/xenia-launcher

# Install desktop file
cat > %{buildroot}/usr/share/applications/xenia-launcher.desktop << 'EOF'
[Desktop Entry]
Name=Xenia Launcher
Comment=A Xenia Emulator Launcher
Exec=/usr/bin/xenia-launcher
Icon=/opt/xenia-launcher/xenia-launcher
Type=Application
Categories=Game;Emulator;
Terminal=false
EOF

%files
%attr(755, root, root) /usr/bin/xenia-launcher
%attr(644, root, root) /usr/share/applications/xenia-launcher.desktop
/opt/xenia-launcher

%post
/sbin/ldconfig

%postun
/sbin/ldconfig

%changelog
* Wed Apr 24 2024 Builder <builder@example.com> - 1.0.0-1
- Initial RPM release
