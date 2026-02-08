# Web Drawing Mode Support

## TL;DR

> **Quick Summary**: Add annotation/drawing mode support to the Flutter web app by porting the annotation JS code to `osmd_frame.html`, adding annotation methods to `MusicXmlWebRendererHtml`, and creating a platform-agnostic `MusicRendererController` so the UI can control annotations on both native and web without platform-specific imports.
> 
> **Deliverables**:
> - `MusicRendererController` — platform-agnostic annotation control class
> - `osmd_frame.html` — annotation JS code (canvas overlay, drawing, undo/redo)
> - `MusicXmlWebRendererHtml` — annotation methods + callback handling
> - `sheet_music_viewer_screen.dart` — remove `kIsWeb` guard, use controller
> 
> **Estimated Effort**: Medium (3-4 hours)
> **Parallel Execution**: NO - sequential (each step depends on the previous)
> **Critical Path**: Controller → JS → Dart bridge → Platform wiring → UI

---

## Context

### Current State
The annotation/drawing feature is fully implemented for **native platforms** (Linux, Android, iOS) but completely missing from the **web platform**. The web platform uses a different renderer architecture:

- **Native**: `osmd_template.html` loaded via `webview_flutter` with `FlutterChannel` communication
- **Web**: `osmd_frame.html` loaded in an iframe with `postMessage` communication

The annotation JS code (canvas overlay, pointer events, freehand drawing, structured symbols, undo/redo) exists in `osmd_template.html` but NOT in `osmd_frame.html`.

Additionally, the viewer screen uses `GlobalKey<MusicXmlWebRendererState>` for annotation control, which only works on native. On web, the widget is `MusicXmlWebRendererHtml` with `MusicXmlWebRendererHtmlState` — a different type. And we can't import the web renderer on native due to `dart:js_interop` dependency.

### Architecture Problem
The sheet music viewer screen needs to call `setAnnotationMode()`, `undo()`, `redo()` on the active renderer. Currently it uses a `GlobalKey<MusicXmlWebRendererState>` which:
1. Only works for the native renderer
2. Can't be changed to `GlobalKey<MusicXmlWebRendererHtmlState>` because that type can't be imported on native

**Solution**: A `MusicRendererController` class with no platform dependencies. Both renderers attach their send function to it. The UI calls methods on the controller.

### Key Files
- `flutter/lib/widgets/music_renderer_controller.dart` — NEW: controller class
- `flutter/web/osmd_frame.html` — MODIFY: add annotation JS code
- `flutter/lib/widgets/musicxml_web_renderer_html.dart` — MODIFY: add annotation methods + callbacks
- `flutter/lib/widgets/musicxml_web_renderer.dart` — MODIFY: attach to controller
- `flutter/lib/widgets/musicxml_platform_renderer.dart` — MODIFY: export controller
- `flutter/lib/widgets/musicxml_platform_renderer_native.dart` — MODIFY: accept controller
- `flutter/lib/widgets/musicxml_platform_renderer_web.dart` — MODIFY: accept controller + pass callbacks
- `flutter/lib/screens/sheet_music_viewer_screen.dart` — MODIFY: use controller instead of GlobalKey

---

## Work Objectives

### Core Objective
Make annotation drawing mode work identically on both native and web Flutter platforms.

### Concrete Deliverables
- Drawing mode toggle works on web
- Freehand drawing works on web
- Undo/redo works on web
- Structured annotations work on web
- History state (canUndo/canRedo) updates UI on web

### Must Have
- Canvas overlay on OSMD pages in web iframe
- Pointer event handling for freehand drawing
- SVG path generation
- Undo/redo history stack
- Flutter↔JS communication for all annotation events
- Platform-agnostic controller pattern

### Must NOT Have (Guardrails)
- Do NOT change the native renderer behavior
- Do NOT break existing tests
- Do NOT add new dependencies
- Do NOT modify the annotation data model
- Do NOT duplicate code — reuse patterns from osmd_template.html

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES
- **Automated tests**: Tests-after (existing annotation tests still pass)
- **Framework**: fvm flutter test

### Agent-Executed QA Scenarios

```
Scenario: Flutter analyze passes with no new errors
  Tool: Bash
  Steps:
    1. cd flutter && fvm flutter analyze 2>&1 | grep -c "error"
  Expected Result: 0 new errors (only pre-existing warnings)

Scenario: All existing tests pass
  Tool: Bash
  Steps:
    1. cd flutter && fvm flutter test test/models/annotation_test.dart test/services/annotation_exporter_test.dart
  Expected Result: All 24 tests pass

Scenario: No regressions in full test suite
  Tool: Bash
  Steps:
    1. cd flutter && fvm flutter test 2>&1 | tail -1
  Expected Result: Same pass/fail count as before (~59 pass, ~18 pre-existing fail)
```

---

## TODOs

- [ ] 1. Create MusicRendererController

  **What to do**:
  - Create NEW file `flutter/lib/widgets/music_renderer_controller.dart`
  - Simple Dart class with NO platform-specific imports (no dart:io, no dart:js_interop, no dart:html)
  - Fields:
    - `void Function(String action, [dynamic payload])? _sendAction` — attached by renderer
    - `bool get isAttached => _sendAction != null`
  - Methods:
    - `void attach(void Function(String action, [dynamic payload]) sendFn)` — called by renderer on init
    - `void detach()` — called by renderer on dispose
    - `void setAnnotationMode(bool enabled)` — sends `setAnnotationMode` action
    - `void setAnnotationStyle({String? color, double? width})` — sends `setAnnotationStyle`
    - `void undo()` — sends `undo`
    - `void redo()` — sends `redo`
    - `void loadAnnotations(List<Map<String, dynamic>> annotations)` — sends `loadAnnotations`
    - `void clearAnnotations({int? pageIndex})` — sends `clearAnnotations`
    - `void removeLastAnnotation(int pageIndex)` — sends `removeLastAnnotation`
    - `void addStructuredAnnotation(...)` — sends `addStructuredAnnotation`
  - Export from `flutter/lib/widgets/musicxml_platform_renderer.dart` by adding: `export 'music_renderer_controller.dart';`

  **Must NOT do**:
  - Do NOT import any platform-specific packages
  - Do NOT add Flutter framework imports (keep it pure Dart)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Blocks**: Tasks 3, 4, 5
  - **Blocked By**: None

  **References**:
  - `flutter/lib/widgets/musicxml_web_renderer.dart:260-330` — The annotation methods on native renderer that the controller must mirror
  - `flutter/lib/widgets/musicxml_types.dart` — Callback typedefs used by both renderers

  **Acceptance Criteria**:
  - [ ] File created: `flutter/lib/widgets/music_renderer_controller.dart`
  - [ ] File modified: `flutter/lib/widgets/musicxml_platform_renderer.dart` — added `export 'music_renderer_controller.dart';`
  - [ ] No platform-specific imports in the controller file
  - [ ] `fvm flutter analyze` shows no new errors in the controller file

  **Commit**: YES
  - Message: `Add MusicRendererController for platform-agnostic annotation control`
  - Files: `flutter/lib/widgets/music_renderer_controller.dart`, `flutter/lib/widgets/musicxml_platform_renderer.dart`

---

- [ ] 2. Add annotation JS code to osmd_frame.html

  **What to do**:
  - Modify `flutter/web/osmd_frame.html` to add the FULL annotation system
  - Port ALL annotation JavaScript from `flutter/assets/html/osmd_template.html` into `osmd_frame.html`
  
  **CSS to add** (inside `<style>` block, after the `div[id^="osmdCanvasPage"]` rule):
  ```css
  /* Add position: relative to page divs */
  div[id^="osmdCanvasPage"] {
      position: relative !important;
      /* keep existing styles */
  }

  .annotation-canvas {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 10;
      touch-action: none;
  }

  .annotation-canvas.drawing-mode {
      pointer-events: auto;
      cursor: crosshair;
  }
  ```

  **JavaScript to add** (inside `<script>` block, after the existing state variables):
  - Copy ALL annotation-related code from `osmd_template.html`:
    - Annotation state variables (`annotationEnabled`, `isDrawing`, `currentStrokePoints`, `annotationCanvases`, `storedAnnotations`, `strokeColor`, `strokeWidth`)
    - Undo/redo state variables (`undoStack`, `redoStack`, `MAX_HISTORY`)
    - `getOrCreateAnnotationCanvas(pageDiv, pageIndex)`
    - `setupAnnotationCanvases()`
    - `setAnnotationMode(enabled)`
    - `setAnnotationStyle(color, width)`
    - `onPointerDown(e, pageIndex)`
    - `onPointerMove(e, pageIndex)`
    - `onPointerUp(e, pageIndex)`
    - `pointsToSvgPath(points)`
    - `svgPathToPoints(svgPath)`
    - `findMeasureAtPoint(px, py, pageIndex)`
    - `redrawAnnotations(pageIndex)` — the version that handles BOTH freehand and structured
    - `drawSvgPath(ctx, svgPath, color, width)`
    - `loadAnnotations(annotations)`
    - `clearAnnotations(pageIndex)`
    - `removeLastAnnotation(pageIndex)`
    - `STRUCTURED_SYMBOLS` object with all renderers (fingerNumber, dynamicMark, bowing, articulation)
    - `addStructuredAnnotation(...)`
    - `pushToUndoStack(pageIndex, annotation)`
    - `undo()`
    - `redo()`
    - `notifyHistoryState()`

  **CRITICAL DIFFERENCE**: The `sendToFlutter` function in `osmd_frame.html` already uses `window.parent.postMessage` (not `FlutterChannel`). The annotation code from `osmd_template.html` uses `sendToFlutter(type, data)` — this will work as-is because `osmd_frame.html` already defines `sendToFlutter` with the correct web implementation.

  **CRITICAL DIFFERENCE**: `osmd_frame.html` renders pages one at a time via `setPage()` which re-loads OSMD with split XML. After each `setPage`, the annotation canvases need to be re-created. Add `setupAnnotationCanvases()` call:
  - In `setOptions()` after `osmd.render()` — add `setupAnnotationCanvases();`
  - In `setPage()` after the render completes — add `setupAnnotationCanvases();`
  - In the resize handler after `osmd.render()` — add `setupAnnotationCanvases();`

  **Message handlers to add** (in the `handleMessage` switch):
  ```javascript
  case 'setAnnotationMode':
      setAnnotationMode(payload.enabled);
      break;
  case 'setAnnotationStyle':
      setAnnotationStyle(payload.color, payload.width);
      break;
  case 'loadAnnotations':
      loadAnnotations(payload.annotations || []);
      break;
  case 'clearAnnotations':
      clearAnnotations(payload.pageIndex);
      break;
  case 'removeLastAnnotation':
      removeLastAnnotation(payload.pageIndex);
      break;
  case 'addStructuredAnnotation':
      addStructuredAnnotation(payload.pageIndex, payload.kind, payload.measureNumber, payload.x, payload.y, payload.data);
      break;
  case 'undo':
      undo();
      break;
  case 'redo':
      redo();
      break;
  ```

  **Must NOT do**:
  - Do NOT modify `osmd_template.html` (native version)
  - Do NOT change the existing `sendToFlutter`, `handleMessage`, or OSMD initialization code
  - Do NOT change the pagination logic

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES — parallel with Task 3
  - **Blocks**: Task 5
  - **Blocked By**: None

  **References**:
  - `flutter/assets/html/osmd_template.html` — Source of ALL annotation JS code to port. Copy from the annotation sections (lines ~35-350 approximately). Look for the sections marked with `// ── Annotation` comments.
  - `flutter/web/osmd_frame.html` — Target file. Note the different page rendering approach (single page via setPage/splitMusicXml).
  - `flutter/web/osmd_frame.html:47-54` — Page div CSS that needs `position: relative !important;` added

  **Acceptance Criteria**:
  - [ ] `osmd_frame.html` contains all annotation CSS
  - [ ] `osmd_frame.html` contains all annotation JS functions
  - [ ] `osmd_frame.html` contains all annotation message handlers
  - [ ] `setupAnnotationCanvases()` called after render in `setOptions()`, `setPage()`, and resize handler
  - [ ] No JavaScript syntax errors (browser console clean on load)

  **Commit**: YES (groups with Task 3)
  - Message: `Add annotation drawing support to web renderer`
  - Files: `flutter/web/osmd_frame.html`, `flutter/lib/widgets/musicxml_web_renderer_html.dart`

---

- [ ] 3. Add annotation methods and callbacks to MusicXmlWebRendererHtml

  **What to do**:
  - Modify `flutter/lib/widgets/musicxml_web_renderer_html.dart`

  **Add annotation callback props to `MusicXmlWebRendererHtml` widget** (matching native renderer):
  ```dart
  final OnAnnotationAdded? onAnnotationAdded;
  final OnAnnotationRemoved? onAnnotationRemoved;
  final OnAnnotationsCleared? onAnnotationsCleared;
  final OnAnnotationModeChanged? onAnnotationModeChanged;
  final OnHistoryChanged? onHistoryChanged;
  final MusicRendererController? controller;
  ```
  - Add these to the constructor (named optional parameters)
  - Import `music_renderer_controller.dart`

  **In `MusicXmlWebRendererHtmlState.initState()`**, attach to controller:
  ```dart
  widget.controller?.attach(_sendToIframe);
  ```

  **In `MusicXmlWebRendererHtmlState.dispose()`**, detach from controller:
  ```dart
  widget.controller?.detach();
  ```

  **Add annotation message handling in `_handleMessage` switch**:
  ```dart
  case 'annotationAdded':
    if (payload != null) {
      widget.onAnnotationAdded?.call(AnnotationEvent.fromJson(payload));
    }
    break;
  case 'annotationRemoved':
    if (payload != null) {
      widget.onAnnotationRemoved?.call(
        payload['pageIndex'] as int? ?? 0,
        payload['measureNumber'] as int? ?? 1,
        payload['remaining'] as int? ?? 0,
      );
    }
    break;
  case 'annotationsCleared':
    if (payload != null) {
      widget.onAnnotationsCleared?.call(payload['pageIndex'] as int? ?? -1);
    }
    break;
  case 'annotationModeChanged':
    if (payload != null) {
      widget.onAnnotationModeChanged?.call(payload['enabled'] as bool? ?? false);
    }
    break;
  case 'historyChanged':
    if (payload != null) {
      widget.onHistoryChanged?.call(
        payload['canUndo'] as bool? ?? false,
        payload['canRedo'] as bool? ?? false,
      );
    }
    break;
  ```

  **Must NOT do**:
  - Do NOT change `MusicXmlWebRenderer` (native renderer)
  - Do NOT break existing web functionality (load, render, pagination)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES — parallel with Task 2
  - **Blocks**: Task 4
  - **Blocked By**: Task 1

  **References**:
  - `flutter/lib/widgets/musicxml_web_renderer_html.dart` — Target file. See existing `_handleMessage` switch at line 137
  - `flutter/lib/widgets/musicxml_web_renderer.dart:54-82` — Native renderer callback props (pattern to follow)
  - `flutter/lib/widgets/musicxml_web_renderer.dart:180-220` — Native renderer message handling (pattern to follow)
  - `flutter/lib/widgets/musicxml_types.dart` — All callback typedefs (`OnAnnotationAdded`, `OnHistoryChanged`, etc.)

  **Acceptance Criteria**:
  - [ ] `MusicXmlWebRendererHtml` accepts all annotation callbacks + controller
  - [ ] State attaches/detaches controller in initState/dispose
  - [ ] `_handleMessage` handles all 5 annotation event types
  - [ ] `fvm flutter analyze` shows no new errors

  **Commit**: YES (groups with Task 2)
  - Message: `Add annotation drawing support to web renderer`
  - Files: `flutter/web/osmd_frame.html`, `flutter/lib/widgets/musicxml_web_renderer_html.dart`

---

- [ ] 4. Wire controller through native renderer and platform adapter

  **What to do**:

  **A. Modify `flutter/lib/widgets/musicxml_web_renderer.dart`** (native renderer):
  - Add `final MusicRendererController? controller;` to widget props
  - Add to constructor
  - In `MusicXmlWebRendererState.initState()`, after `_loadHtmlTemplate()`:
    ```dart
    widget.controller?.attach(_sendToJs);
    ```
  - In `MusicXmlWebRendererState.dispose()`:
    ```dart
    widget.controller?.detach();
    ```
  - Import `music_renderer_controller.dart`

  **B. Modify `flutter/lib/widgets/musicxml_platform_renderer_native.dart`**:
  - Add `MusicRendererController? controller` parameter to `buildMusicXmlRenderer`
  - Pass through to `MusicXmlWebRenderer` constructor

  **C. Modify `flutter/lib/widgets/musicxml_platform_renderer_web.dart`**:
  - Add `MusicRendererController? controller` parameter to `buildMusicXmlRenderer`
  - Pass `controller` AND all annotation callbacks through to `MusicXmlWebRendererHtml`:
    ```dart
    return MusicXmlWebRendererHtml(
      // ...existing params...
      onAnnotationAdded: onAnnotationAdded,
      onAnnotationRemoved: onAnnotationRemoved,
      onAnnotationsCleared: onAnnotationsCleared,
      onAnnotationModeChanged: onAnnotationModeChanged,
      onHistoryChanged: onHistoryChanged,
      controller: controller,
    );
    ```

  **Must NOT do**:
  - Do NOT change any annotation behavior on native
  - Do NOT break existing renderer functionality

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Blocks**: Task 5
  - **Blocked By**: Tasks 1, 3

  **References**:
  - `flutter/lib/widgets/musicxml_web_renderer.dart` — Native renderer. Add controller prop + attach/detach
  - `flutter/lib/widgets/musicxml_platform_renderer_native.dart` — Native adapter. Add controller param, pass through
  - `flutter/lib/widgets/musicxml_platform_renderer_web.dart` — Web adapter. Add controller param + ALL annotation callbacks

  **Acceptance Criteria**:
  - [ ] Native renderer accepts and attaches/detaches controller
  - [ ] Both platform adapters accept controller parameter
  - [ ] Web adapter passes ALL annotation callbacks to `MusicXmlWebRendererHtml`
  - [ ] `fvm flutter analyze` shows no new errors

  **Commit**: YES
  - Message: `Wire MusicRendererController through native and web platform adapters`
  - Files: `flutter/lib/widgets/musicxml_web_renderer.dart`, `flutter/lib/widgets/musicxml_platform_renderer_native.dart`, `flutter/lib/widgets/musicxml_platform_renderer_web.dart`

---

- [ ] 5. Update sheet music viewer to use controller, remove kIsWeb guard

  **What to do**:
  - Modify `flutter/lib/screens/sheet_music_viewer_screen.dart`

  **Remove the `GlobalKey<MusicXmlWebRendererState>` and replace with controller**:
  ```dart
  // REMOVE these:
  final GlobalKey<MusicXmlWebRendererState> _rendererKey = GlobalKey<MusicXmlWebRendererState>();
  
  // ADD this:
  final MusicRendererController _rendererController = MusicRendererController();
  ```

  **Remove the import** of `musicxml_web_renderer.dart` (no longer needed since we use the controller):
  ```dart
  // REMOVE:
  import '../widgets/musicxml_web_renderer.dart';
  ```

  **Remove the `!kIsWeb` guard** around annotation controls. Change from:
  ```dart
  if (!kIsWeb) ...[
    if (_annotationMode) ...[
      // undo/redo buttons
    ],
    // draw toggle button
  ],
  ```
  To:
  ```dart
  if (_annotationMode) ...[
    // undo/redo buttons using _rendererController
  ],
  // draw toggle button using _rendererController
  ```

  **Replace all `_rendererKey.currentState?.xxx()` calls with `_rendererController.xxx()`**:
  - `_rendererKey.currentState?.undo()` → `_rendererController.undo()`
  - `_rendererKey.currentState?.redo()` → `_rendererController.redo()`
  - `_rendererKey.currentState?.setAnnotationMode(...)` → `_rendererController.setAnnotationMode(...)`

  **Pass controller to `buildMusicXmlRenderer`**:
  In the `_SheetMusicPage` widget, pass the controller through to the renderer:
  - Add `MusicRendererController? controller` to `_SheetMusicPage` constructor
  - Pass from parent: `controller: _rendererController`
  - In `_buildMusicXmlView()`: pass `controller: widget.controller` to `buildMusicXmlRenderer`
  - Remove the `rendererKey` parameter from `_SheetMusicPage` (no longer needed)
  - Remove `widget.rendererKey` from the `buildMusicXmlRenderer` key parameter — use `ValueKey('musicxml-${widget.page.path}-$orientation')` instead

  **Remove `kIsWeb` import** if no longer used anywhere in the file. Check — it's imported from `package:flutter/foundation.dart`. If `kIsWeb` is only used for the annotation guard, remove the guard only; keep `kIsWeb` if used elsewhere.

  **Must NOT do**:
  - Do NOT break zoom controls or page navigation
  - Do NOT remove any existing callbacks (onLoaded, onError, etc.)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Blocks**: Task 6
  - **Blocked By**: Tasks 2, 3, 4

  **References**:
  - `flutter/lib/screens/sheet_music_viewer_screen.dart` — Full screen file. Key areas:
    - Line 4: `import 'package:flutter/foundation.dart' show kIsWeb;` — may need to keep for other uses
    - Line 13: `import '../widgets/musicxml_web_renderer.dart';` — REMOVE
    - Line 28-31: State variables including `_rendererKey` — replace with controller
    - Lines 111-143: Annotation UI with `!kIsWeb` guard — remove guard
    - Lines 187-195: `_SheetMusicPage` constructor — replace rendererKey with controller
    - `_buildMusicXmlView()` — pass controller instead of rendererKey

  **Acceptance Criteria**:
  - [ ] No `kIsWeb` guard around annotation controls
  - [ ] No `GlobalKey<MusicXmlWebRendererState>` — replaced with `MusicRendererController`
  - [ ] No import of `musicxml_web_renderer.dart`
  - [ ] Undo/redo buttons use controller
  - [ ] Draw toggle uses controller
  - [ ] Controller passed to `buildMusicXmlRenderer`
  - [ ] `fvm flutter analyze` shows no new errors
  - [ ] `fvm flutter test test/models/annotation_test.dart test/services/annotation_exporter_test.dart` — all 24 pass
  - [ ] `fvm flutter test` — no new failures (same ~59 pass / ~18 pre-existing fail)

  **Commit**: YES
  - Message: `Enable annotation drawing mode on web platform`
  - Files: `flutter/lib/screens/sheet_music_viewer_screen.dart`

---

- [ ] 6. Final verification and push

  **What to do**:
  - Run `fvm flutter analyze` — verify no new errors
  - Run `fvm flutter test` — verify no regressions
  - Push all commits to remote

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `["git-master"]`

  **Parallelization**:
  - **Blocked By**: All previous tasks

  **Acceptance Criteria**:
  - [ ] `fvm flutter analyze` — no new errors
  - [ ] `fvm flutter test test/models/annotation_test.dart test/services/annotation_exporter_test.dart` — 24/24 pass
  - [ ] `fvm flutter test` — no new failures
  - [ ] `git push` succeeds
  - [ ] `git status` shows "up to date with origin"

  **Commit**: NO (just push existing commits)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `Add MusicRendererController for platform-agnostic annotation control` | `music_renderer_controller.dart`, `musicxml_platform_renderer.dart` | flutter analyze |
| 2+3 | `Add annotation drawing support to web renderer` | `osmd_frame.html`, `musicxml_web_renderer_html.dart` | flutter analyze |
| 4 | `Wire MusicRendererController through native and web platform adapters` | `musicxml_web_renderer.dart`, `*_platform_renderer_native.dart`, `*_platform_renderer_web.dart` | flutter analyze |
| 5 | `Enable annotation drawing mode on web platform` | `sheet_music_viewer_screen.dart` | flutter test |
| 6 | Push all | — | git push |

---

## Success Criteria

### Verification Commands
```bash
cd flutter
fvm flutter analyze 2>&1 | grep "error"  # Expected: 0 new errors
fvm flutter test test/models/annotation_test.dart test/services/annotation_exporter_test.dart  # Expected: 24/24 pass
fvm flutter test 2>&1 | tail -1  # Expected: +59 -18 (same as before)
```

### Final Checklist
- [ ] Drawing mode button visible on web (no kIsWeb guard)
- [ ] Controller pattern works on both platforms
- [ ] Canvas overlay renders on web OSMD pages
- [ ] Freehand drawing captured as SVG paths on web
- [ ] Undo/redo buttons enabled/disabled correctly on web
- [ ] No regression on native platform
- [ ] All tests pass
- [ ] All commits pushed
