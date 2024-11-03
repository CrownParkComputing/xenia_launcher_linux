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

## Xenia Requirements

### Folder Structure
```
xenia/
├── variants/              # Different Xenia variants
│   ├── canary/           # Canary builds
│   └── master/           # Master builds
├── games/                # Game ISO files
│   ├── [game-title-1]/   # Each game in its own folder
│   │   ├── game.iso
│   │   └── dlc/         # DLC content (optional)
│   └── [game-title-2]/
├── cache/                # Cache directory
└── content/              # Game content and saves
```

### File Naming Conventions
- Game folders should use lowercase with hyphens
  - Example: `halo-3`, `gears-of-war`
- ISO files should be named `game.iso` within their folder
- DLC files should be placed in a `dlc` subfolder

### Required Prefixes
- Game folders: No prefix required, use game name
- DLC files: Use the game's content ID as prefix
  - Example: `584108A6_dlc1.xcp`
- Save files: Use the game's save ID as prefix
  - Example: `FFFE07D1_save.bin`

### Supported File Types
- Game Files:
  - `.iso` - Xbox 360 game disc images
  - `.xex` - Xbox 360 executable files
  - `.xcp` - Xbox 360 content packages (DLC)
- Save Data:
  - `.bin` - Save game files
  - `.sav` - Alternative save format
- Cache Files:
  - `.cache` - Xenia shader cache
  - `.txt` - Game configuration files

## Project Structure

```
xenia_launcher/
├── lib/                    # Main source code directory
│   ├── models/            # Data models and entities
│   ├── providers/         # State management providers
│   ├── screens/           # UI screens/pages
│   ├── services/          # Business logic and external services
│   └── widgets/           # Reusable UI components
├── linux/                 # Linux-specific configuration
├── AppDir/                # AppImage configuration
└── .github/workflows/     # CI/CD configuration
```

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
