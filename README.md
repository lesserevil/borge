# Borge - Sheet Music Viewer with Pebble Control

A cross-platform Flutter application for viewing sheet music on tablets, with companion Pebble watch app for hands-free navigation.

## Features

- **Flutter App**: Cross-platform sheet music viewer supporting PDF, PNG, SVG, and MusicXML files
- **On-demand Scanning**: Scan local directories for sheet music files without constant monitoring
- **Pebble Companion**: Navigate songs and pages using Pebble watch buttons (up, down, select, back)
- **BLE Communication**: Robust Bluetooth Low Energy protocol with acknowledgments and haptic feedback
- **Nested JSON API**: Structured song and page data for reliable synchronization

## Development Setup

### Prerequisites

- Flutter SDK (see version in `pubspec.yaml`)
- Android Studio or VS Code with Flutter extensions
- Pebble SDK for companion app development
- Git for version control

### Flutter App Setup

```bash
# Clone the repository
git clone <repository-url>
cd borge

# Install Flutter dependencies
flutter pub get

# Run the app
flutter run
```

### Pebble App Setup

1. Install the Pebble SDK from [developer.getpebble.com](https://developer.getpebble.com/)
2. Navigate to the `pebble/` directory
3. Build and install the companion app:
   ```bash
   pebble build
   pebble install --phone <device-id>
   ```

## Architecture

### Flutter App Structure

```
lib/
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
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
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