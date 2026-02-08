# Learnings - Music Drawing Annotation

## 2026-02-07 Session Start: Codebase Analysis

### Project Structure
- Flutter app at `flutter/` with `fvm flutter` for commands
- OSMD (OpenSheetMusicDisplay) integrated via WebView (`webview_flutter`)
- HTML template: `flutter/assets/html/osmd_template.html`
- OSMD JS lib: `flutter/assets/js/opensheetmusicdisplay.min.js`
- FlutterChannel bridge: JS calls `window.FlutterChannel.postMessage()`, Dart listens via `addJavaScriptChannel`

### Key Files for Annotation Feature
- `flutter/lib/widgets/musicxml_web_renderer.dart` - WebView widget hosting OSMD (will need annotation bridge)
- `flutter/lib/widgets/musicxml_types.dart` - Type definitions for OSMD communication
- `flutter/lib/models/music_folder.dart` - MusicFolder model (uses JSON/shared_prefs, NOT SQLite)
- `flutter/assets/html/osmd_template.html` - OSMD HTML template (canvas overlay goes here)

### Communication Pattern (JS↔Flutter)
- **Flutter→JS**: `_sendToJs(action, payload)` → calls `handleFlutterMessage(message)` in JS
- **JS→Flutter**: `sendToFlutter(eventType, data)` → `window.FlutterChannel.postMessage(JSON.stringify({type, data}))`
- Message format: `{action: string, payload: any}` (Flutter→JS), `{type: string, data: any}` (JS→Flutter)

### Dependencies Already Present
- `webview_flutter: ^4.13.0`
- `shared_preferences: ^2.2.2`
- `path_provider: ^2.1.2`
- `xml: ^6.6.1`

### Dependencies Needed
- `sqflite` (for SQLite persistence - plan says `sqlite_formatter` but that's wrong)
- `path` (if not already transitively available)

### Existing Tests
- `flutter/test/widget_test.dart`
- `flutter/test/services/song_repository_test.dart`
- `flutter/test/models/sheet_music_file_test.dart`
- `flutter/test/models/song_test.dart`
- `flutter/test/services/file_scanner_service_test.dart`

### Build System
- `make test` (runs `fvm flutter test`, depends on build)
- `make build` (runs `fvm flutter build linux --release`)
- `make deps` (runs `fvm flutter pub get`)
