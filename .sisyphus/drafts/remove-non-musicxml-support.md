# Draft: Remove Non-MusicXML File Support

## Requirements (confirmed)
- Remove ALL non-MusicXML file support (PDF, PNG, JPG, JPEG, SVG, GIF, WEBP)
- Only support MusicXML files (.musicxml, .xml, .mxl) for music files
- Do NOT support PDF or images for music files

## Research Findings

### Affected Areas (Full Inventory)

**1. Flutter App - Model Layer:**
- `flutter/lib/models/sheet_music_file.dart:28` — `isSupportedExtension()` includes `.pdf`, `.png`, `.svg` (needs to be `.musicxml`, `.xml`, `.mxl` only)
- `flutter/lib/models/sheet_music_file.dart:15` — docstring says "e.g., '.pdf', '.png'" 
- `flutter/lib/models/page.dart:6` — docstring says "e.g., MusicXML, PDF"
- `flutter/lib/models/page.dart:12` — docstring says "e.g., '.pdf', '.png'"

**2. Flutter App - Service Layer:**
- `flutter/lib/services/file_scanner_service.dart:21` — `supportedExtensions` already correct: `{'.musicxml', '.xml', '.mxl'}` ✅ (BUT docstring at line 26 says ".pdf, .png, .svg, .musicxml")
- `flutter/lib/services/song_repository.dart` — Already MusicXML-only ✅

**3. Flutter App - UI Layer (Sheet Music Viewer Screen):**
- `flutter/lib/screens/sheet_music_viewer_screen.dart:8` — `import 'package:pdfx/pdfx.dart'` (PDF dependency)
- `flutter/lib/screens/sheet_music_viewer_screen.dart:7` — `import 'package:flutter_svg/flutter_svg.dart'` (SVG dependency)
- `flutter/lib/screens/sheet_music_viewer_screen.dart:259` — docstring "Supports PDF, PNG, JPG, SVG"
- `flutter/lib/screens/sheet_music_viewer_screen.dart:281` — `PdfControllerPinch?` field
- `flutter/lib/screens/sheet_music_viewer_screen.dart:322` — `if (ext == '.pdf')` branch
- `flutter/lib/screens/sheet_music_viewer_screen.dart:396-430` — entire `_loadPdf()` method
- `flutter/lib/screens/sheet_music_viewer_screen.dart:458-476` — switch cases for `.pdf`, `.svg`, `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`
- `flutter/lib/screens/sheet_music_viewer_screen.dart:520-543` — `_buildPdfView()` method
- `flutter/lib/screens/sheet_music_viewer_screen.dart:546-596` — `_buildSvgView()` + `_buildSvgFromFile()` methods
- `flutter/lib/screens/sheet_music_viewer_screen.dart:598-656` — `_buildImageView()` method

**4. Flutter App - State Layer:**
- `flutter/lib/state/app_state.dart:121` — docstring mentions "MusicXML or PDF"
- `flutter/lib/state/app_state.dart:330-335` — `_loadSongsFromAssets()` already filters MusicXML only ✅

**5. Flutter Dependencies (pubspec.yaml):**
- `flutter/pubspec.yaml:42` — `pdfx: ^2.6.0` (can be removed)
- `flutter/pubspec.yaml:45` — `flutter_svg: ^2.2.3` (can be removed IF not used elsewhere)

**6. Python Tools (tools/ directory):**
- `tools/borge_tools/__init__.py` — "PDF to MusicXML conversion utilities"
- `tools/borge_tools/pdf2musicxml.py` — Entire file: PDF → MusicXML conversion
- `tools/borge_tools/img2musicxml.py` — Entire file: Image → MusicXML conversion
- `tools/borge_tools/batch_convert.py` — Batch PDF → MusicXML conversion
- `tools/pyproject.toml` — pymupdf dependency, pdf2musicxml/img2musicxml/batch-convert scripts
- `tools/README.md` — Documents PDF/image conversion pipeline

**7. Test Files:**
- `flutter/test/models/sheet_music_file_test.dart` — Heavy PDF/PNG references throughout
- `flutter/test/models/song_test.dart` — Uses `.pdf` extensions in all test data
- `flutter/test/services/file_scanner_service_test.dart` — Tests for PDF, PNG, SVG scanning
- `flutter/test/services/song_repository_test.dart` — Uses `.pdf` test files throughout

**8. Documentation:**
- `README.md:11` — "supporting PDF, PNG, SVG, and MusicXML files"
- `tools/README.md` — Entire file documents PDF/image pipeline

**9. OSMD Demo (likely keep):**
- `flutter/osmd-source/demo/index.js` — PDF export in OSMD demo (this is a 3rd party demo, probably leave as-is)

### Note: SVG rendering may still be needed
The MusicXML rendering pipeline (`musicxml_mscore_renderer.dart`) uses SVG output from MuseScore. The `flutter_svg` package may still be needed for the MusicXML *rendering* pipeline, even though we don't want to support SVG as a *source* music file format.

## Technical Decisions
- Remove pdfx dependency entirely (no PDF viewing needed)
- Keep flutter_svg if used by MusicXML renderer (needs verification)
- Remove Python tools entirely OR keep them as optional conversion utilities
- Update all tests to use .musicxml extensions

## Open Questions
- Should the Python tools (pdf2musicxml, img2musicxml) be kept as conversion utilities for users to convert their PDFs offline, or removed entirely?
- Is flutter_svg used by the MusicXML rendering pipeline (it appears so - SVG output from MuseScore)?

## Scope Boundaries
- INCLUDE: Remove all PDF/image file support from the Flutter app
- INCLUDE: Update all tests to use MusicXML file types
- INCLUDE: Remove unused dependencies from pubspec.yaml
- INCLUDE: Update documentation
- QUESTION: Python tools — remove or keep?
