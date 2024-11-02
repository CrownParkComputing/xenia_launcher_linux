Name:           xenia-launcher
Version:        1.0.0
Release:        1%{?dist}
Summary:        A Xenia Emulator Launcher
License:        MIT
URL:            https://github.com/xenia-project/xenia-launcher
BuildArch:      x86_64

Requires:       gtk3

%description
A launcher application for the Xenia Xbox 360 emulator.

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/lib
mkdir -p %{buildroot}/usr/share/applications

# Copy the executable
install -D -m 755 %{_sourcedir}/xenia_launcher %{buildroot}/usr/bin/xenia_launcher

# Copy libraries
cp -r %{_sourcedir}/lib/* %{buildroot}/usr/lib/

# Copy desktop file
install -D -m 644 %{_sourcedir}/xenia-launcher.desktop %{buildroot}/usr/share/applications/xenia-launcher.desktop

%files
%attr(755, root, root) /usr/bin/xenia_launcher
/usr/lib/*
%attr(644, root, root) /usr/share/applications/xenia-launcher.desktop

%changelog
* Wed Apr 24 2024 Builder <builder@example.com> - 1.0.0-1
- Initial RPM release
