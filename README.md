# Borge - Sheet Music Viewer with Pebble Control

[![Flutter CI](https://github.com/lesserevil/borge/actions/workflows/flutter.yml/badge.svg)](https://github.com/lesserevil/borge/actions/workflows/flutter.yml)

A cross-platform Flutter application for viewing sheet music on tablets, with companion Pebble watch app for hands-free navigation.

**Flutter Version**: 3.38.5 (managed via [fvm](https://fvm.app/))

## Features

- **Flutter App**: Cross-platform sheet music viewer supporting PDF, PNG, SVG, and MusicXML files
- **On-demand Scanning**: Scan local directories for sheet music files without constant monitoring
- **Pebble Companion**: Navigate songs and pages using Pebble watch buttons (up, down, select, back)
- **BLE Communication**: Robust Bluetooth Low Energy protocol with acknowledgments and haptic feedback
- **Nested JSON API**: Structured song and page data for reliable synchronization

## Development Setup

### Prerequisites

- [fvm](https://fvm.app/) - Flutter Version Manager (recommended)
- Android Studio or VS Code with Flutter extensions
- Pebble SDK for companion app development
- Git for version control

### Flutter App Setup

```bash
# Clone the repository
git clone git@github.com:lesserevil/borge.git
cd borge/flutter

# Install fvm (if not already installed)
curl -fsSL https://fvm.app/install.sh | bash

# Install the pinned Flutter version
fvm install

# Install Flutter dependencies
fvm flutter pub get

# Run the app
fvm flutter run
```

> **Note**: You can also use `flutter` directly if you have Flutter 3.38.5 installed globally, but fvm is recommended for consistent versioning.

### Docker Development (Recommended)

No need to install Flutter, Java, or any other dependencies. Just Docker.

```bash
# Build the development container
make images

# Install dependencies
make deps

# Run tests
make test

# Build Linux desktop app
make build

# Build web app
make build-web

# Build Android APK
make build-apk

# Build Pebble firmware
make pebble

# Open interactive shell in container
make shell

# Clean up Docker resources
make clean
```

Your source code is volume-mounted — edit files with your IDE on the host,
build and test inside the container.

### Pebble App Setup

See [pebble/README.md](pebble/README.md) for detailed setup instructions.

**Quick Start (Ubuntu)**:

```bash
# Install system dependencies
sudo apt install python3-pip python3-venv python3.12-venv nodejs npm libsdl1.2debian libfdt1

# Install uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install pebble-tool and SDK
uv tool install pebble-tool --python 3.12
pebble sdk install latest

# Build and install
cd pebble
pebble build
pebble install --phone <IP>  # IP from Pebble app on phone
```

## Architecture

### Project Structure

```
borge/
├── flutter/          # Flutter app
│   ├── lib/          # Dart source code
│   ├── android/      # Android platform files
│   ├── ios/          # iOS platform files
│   ├── web/          # Web platform files
│   ├── linux/        # Linux platform files
│   ├── macos/        # macOS platform files
│   ├── windows/      # Windows platform files
│   └── test/         # Flutter tests
└── pebble/           # Pebble companion app (coming soon)
```

### Flutter App Structure

```
flutter/lib/
├── models/           # Data models (Song, Page, SheetMusicFile)
├── services/         # Business logic (FileScanner, SongRepository, ApiService)
├── screens/          # UI screens
├── widgets/          # Reusable UI components
└── main.dart         # App entry point
```

### Communication Protocol

- **BLE Characteristics**: Control commands and data exchange
- **JSON Schema**: Nested structure for songs and pages
- **Command Set**: GET_LIST, NEXT_PAGE, PREV_PAGE, SELECT_SONG
- **Feedback**: Visual updates and vibration patterns

## Testing

```bash
cd flutter

# Run all tests
fvm flutter test

# Run with coverage
fvm flutter test --coverage
```

## CI/CD

Automated builds and tests via GitHub Actions:
- Flutter APK builds
- Linting and type checking
- Unit and widget tests
- Pebble firmware builds

## Contributing

1. Create issues for new features using `bd create`
2. Follow the detailed task format in `.cursorrules`
3. Update issue status with `bd update`
4. Ensure all tests pass before submitting PRs

## License

[Add your license here]

## Tools and Dependencies

### Required Tools

- **Flutter SDK**: Cross-platform mobile development framework
- **Pebble SDK**: Companion watch app development
- **Android Studio**: IDE for Flutter development (optional)
- **Git**: Version control

### Flutter Dependencies

- `flutter_blue`: BLE communication
- `path_provider`: File system access
- `shelf`: Local HTTP server (alternative to BLE)
- `uuid`: Unique identifier generation
- `flutter_lints`: Code quality and style

### Pebble Dependencies

- Pebble SDK C libraries
- BLE APIs for communication
- Vibration APIs for haptic feedback