# Xenia Launcher

[![Build AppImage](https://github.com/USER_NAME/xenia_launcher/actions/workflows/build.yml/badge.svg)](https://github.com/USER_NAME/xenia_launcher/actions/workflows/build.yml)
[![Latest Release](https://img.shields.io/github/v/release/USER_NAME/xenia_launcher)](https://github.com/USER_NAME/xenia_launcher/releases/latest)

A Flutter-based launcher for the Xenia Xbox 360 emulator.

## Features

- Game library management
- Achievement tracking
- Game stats and progress tracking
- Live game status monitoring
- IGDB integration for game metadata
- Cover art management
- DLC support
- Xenia configuration management
- Multiple Xenia variant support

## Installation

1. Download the latest `Xenia_Launcher-x86_64.AppImage` from the [releases page](https://github.com/USER_NAME/xenia_launcher/releases)
2. Make the AppImage executable:
   ```bash
   chmod +x Xenia_Launcher-x86_64.AppImage
   ```
3. Run the launcher:
   ```bash
   ./Xenia_Launcher-x86_64.AppImage
   ```

## Building from Source

### Prerequisites

- Flutter SDK (>=3.0.0)
- Linux build dependencies:
  ```bash
  sudo apt-get install cmake ninja-build libgtk-3-dev
  ```

### Build Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/USER_NAME/xenia_launcher.git
   cd xenia_launcher
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Build the Linux application:
   ```bash
   flutter build linux --release
   ```

4. Build the AppImage:
   ```bash
   ./appimagetool AppDir/
   ```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
