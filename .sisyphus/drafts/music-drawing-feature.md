# Draft: Music Drawing Annotation Feature

## Requirements (confirmed)
- User wants to add ability to draw marks on music by drawing on the screen
- Marks should scale with the measure they're attached to
- Marks should follow the measure (suggests scrolling/zooming support)
- **Drawing Types**: Both freehand doodles AND structured annotations (finger numbers, dynamics, bowing marks, articulations)
- **File Support**: MusicXML only (.musicxml, .xml, .mxl) - NOT PDF/PNG/SVG
- **Persistence**: Both local device storage AND export capability
- **Editing**: Undo/redo only (no individual mark selection/editing)
- **Drawing Approach**: JavaScript drawing (inside WebView) - best for measure tracking and zoom scaling
- **Testing Strategy**: TDD (RED-GREEN-REFACTOR)

## Technical Decisions
- **Canvas Implementation**: HTML5 Canvas overlay inside WebView (via JavaScript)
- **Gesture Handling**: JavaScript pointer events (pointerdown, pointermove, pointerup) inside WebView
- **Coordinate System**: Store coordinates relative to OSMD measure elements (not screen pixels)
- **Zoom Handling**: Canvas transforms scale automatically with OSMD zoom
- **Undo/Redo**: JavaScript history stack with Flutter state sync

## Research Findings (in progress)

**Current Architecture:**
- Music is rendered using OSMD (OpenSheetMusicDisplay) via WebView
- WebView renders MusicXML to high-quality sheet music
- Communication with JS via JavaScriptChannel ('FlutterChannel')
- Zoom is handled via JavaScript (`zoomLevel` variable and reload)
- Page navigation via JavaScript (`setPage` method)
- The renderer is in `MusicXmlWebRenderer` widget with WebView

**Key Files:**
- `flutter/lib/screens/sheet_music_viewer_screen.dart` - Main viewer with navigation
- `flutter/lib/widgets/musicxml_web_renderer.dart` - WebView-based OSMD renderer
- `flutter/lib/state/app_state.dart` - State management (zoom, pages)
- `flutter/assets/html/osmd_template.html` - OSMD JavaScript template

**Rendering Context:**
- Music displayed in WebView widget
- Overlay system exists (NavigationOverlay, PageIndicator)
- GestureDetector handles taps and swipes
- Zoom (0.5x to 3.0x) managed in AppState
- Pages have `div[id^="osmdCanvasPage"]` elements in the DOM
- OSMD exposes `osmd.GraphicSheet.musicPages[].musicSystems[].graphicalMeasures[]`

**Drawing Challenge:**
- Need to track coordinates relative to measures (not pixels)
- OSMD provides measure location info via `graphicalMeasures`
- Drawing must scale with zoom level
- JavaScript canvas overlay approach solves scaling naturally

**Flutter Drawing Patterns (from research):**
- `CustomPainter` + `GestureDetector` is standard Flutter pattern
- Undo/redo typically uses stack-based history
- JavaScript drawing inside WebView allows direct DOM manipulation

## Scope Boundaries
- INCLUDE: Freehand doodles, structured annotations (finger #, dynamics, bowing, articulations), undo/redo, local storage, export
- EXCLUDE: PDF/PNG/SVG file support, individual mark editing (no select/move/resize), music editing

## Open Questions
- None - all requirements clear
