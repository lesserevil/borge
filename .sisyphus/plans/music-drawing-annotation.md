# Music Drawing Annotation Feature Plan

## 1. JavaScript Canvas Overlay in WebView
**Technical Approach:**
- Add HTML5 Canvas overlay inside WebView
- Coordinate system based on OSMD `graphicalMeasures`
- JavaScript pointer events `pointerdown`, `pointermove`, `pointerup`
- Canvas transforms scale automatically with OSMD zoom

## 2. Drawing Types
**Supported:**
- **Freehand:** Continuous strokes captured as SVG path strings
- **Structured:** Predefined symbols for finger numbers, dynamics, bowing, articulations

## 3. Persistence
**Local Storage:**
- SQLite database storing annotations with:
  - File ID (FOREIGN KEY to `MusicFolder`)
  - Measure ID
  - Type (freehand/structured)
  - Data (SVG path for freehand, JSON for structured)
  - Creation timestamp

**Export:**
- Save as `.annotation.xml` alongside `.musicxml`
- JSON format containing:
  - List of annotations
  - Reference to associated measure
  - Type-specific data

## 4. Undo/Redo
**JavaScript History Stack:**
- Maintain undo/redo stack in JS for drawing operations
- Notify Flutter on each change via `FlutterChannel`
- JS methods:
  - `undo()`
  - `redo()`
  - `pushStateergic change notification

## 5. Testing Strategy (TDD)
**Folder Structure:**
```
lib/tests.annotation/
├── unit/
│   ├── annotation_model_test.dart
│   ├── drawing_engine_test.dart
│   └── measure_tracker_test.dart
├── widget/
│   └── drawing_overlay_test.dart
└── integration/
    └── drawing_flow_test.dart
```

**Key Tests:**
1. Annotation appears on correct measure
2. Annotations scale with zoom level
3. Undo/redo stack works across page changes
4. Annotations export/import properly
5. Multi-touch drawing performance

## 6. Roadmap
**Phase 1: Core Drawing (Week 1-2)**
- Canvas overlay implementation
- Measure coordinate tracking
- Pointer event handling
- Freehand drawing capture

**Phase 2: Structured Annotations (Week 3)**
- Add symbol types
- Implementation of annotation rendering
- Data structure for structured marks

**Phase 3: Persistence (Week 4)**
- SQLite schema design
- Export/import functionality
- Local storage management

**Phase 4: Undo/Redo (Week 5)**
- JavaScript history stack implementation
- Flutter state sync
- UI for undo/redo controls

**Phase 5: Testing & Polish (Week 6)**
- Unit tests
- Integration tests
- Performance optimization
- Edge case handling

## 7. Dependencies
**Add to pubspec.yaml:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  sqlite_formatter:
  path_provider:
  shared_preferences:
  vector_math: ^2.1.4

dev_dependencies:
  flutter_test:
  pedantic: ^1.11.0
  build_runner: ^2.3.3
```