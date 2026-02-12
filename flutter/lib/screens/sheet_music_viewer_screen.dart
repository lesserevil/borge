import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/annotation.dart';
import '../models/models.dart' as models;
import '../services/annotation_exporter.dart';
import '../services/annotation_repository.dart';
import '../state/app_state.dart';
import '../widgets/musicxml_platform_renderer.dart';

/// Screen for viewing sheet music pages with navigation.
class SheetMusicViewerScreen extends StatefulWidget {
  final AppState appState;

  const SheetMusicViewerScreen({super.key, required this.appState});

  @override
  State<SheetMusicViewerScreen> createState() => _SheetMusicViewerScreenState();
}

class _SheetMusicViewerScreenState extends State<SheetMusicViewerScreen> {
  final FocusNode _focusNode = FocusNode();
  Orientation? _lastOrientation;
  bool _annotationMode = false;
  bool _canUndo = false;
  bool _canRedo = false;
  bool _isRendering = false;
  final GlobalKey _rendererKey = GlobalKey();

  // Annotation persistence
  final AnnotationRepository _annotationRepo = AnnotationRepository();
  static const _uuid = Uuid();
  // Track annotation IDs by measure for undo/removal mapping
  final Map<int, List<String>> _annotationIdsByMeasure = {};

  @override
  void initState() {
    super.initState();
    // Request focus for keyboard navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    // Re-request focus when it's lost (e.g. WebView steals it during load)
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && mounted && !_annotationMode) {
      // WebView or another widget stole focus — take it back
      // so gamepad/keyboard input keeps working
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_focusNode.hasFocus && !_annotationMode) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Track orientation changes
    final currentOrientation = MediaQuery.of(context).orientation;
    if (_lastOrientation != null && _lastOrientation != currentOrientation) {
      // Orientation changed - trigger re-render
      debugPrint(
        '🔄 Orientation changed from $_lastOrientation to $currentOrientation',
      );
      _handleOrientationChange();
    }
    _lastOrientation = currentOrientation;
  }

  void _handleOrientationChange() {
    // Trigger a re-render by setting a flag that the widget can respond to
    // The MusicXmlWebRenderer will pick this up through didUpdateWidget
    setState(() {
      // Force a rebuild which will cause the WebView to resize
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _annotationRepo.close();
    super.dispose();
  }

  void _zoomIn() {
    if (_isRendering || _annotationMode) return;
    setState(() { _isRendering = true; });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isRendering) setState(() { _isRendering = false; });
    });
    widget.appState.zoom = (widget.appState.zoom + 0.1).clamp(0.4, 3.0);
  }

  void _zoomOut() {
    if (_isRendering || _annotationMode) return;
    setState(() { _isRendering = true; });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isRendering) setState(() { _isRendering = false; });
    });
    widget.appState.zoom = (widget.appState.zoom - 0.1).clamp(0.4, 3.0);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.pageDown) {
        widget.appState.nextPage();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.pageUp) {
        widget.appState.previousPage();
      } else if (event.logicalKey == LogicalKeyboardKey.home) {
        widget.appState.goToPage(0);
      } else if (event.logicalKey == LogicalKeyboardKey.end) {
        widget.appState.goToPage(widget.appState.totalPages - 1);
      } else if (event.logicalKey == LogicalKeyboardKey.equal ||
          event.logicalKey == LogicalKeyboardKey.add) {
        _zoomIn();
      } else if (event.logicalKey == LogicalKeyboardKey.minus ||
          event.logicalKey == LogicalKeyboardKey.underscore) {
        _zoomOut();
      } else if (event.logicalKey == LogicalKeyboardKey.gameButtonRight1) {
        widget.appState.nextPage();
      } else if (event.logicalKey == LogicalKeyboardKey.gameButtonLeft1) {
        widget.appState.previousPage();
      } else if (event.logicalKey == LogicalKeyboardKey.gameButtonRight2) {
        _zoomIn();
      } else if (event.logicalKey == LogicalKeyboardKey.gameButtonLeft2) {
        _zoomOut();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          backgroundColor: Colors.grey[850],
          foregroundColor: Colors.white,
          title: Text(widget.appState.currentSong?.name ?? 'Sheet Music'),
          actions: [
            // Annotation controls
            if (_annotationMode) ...[
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _canUndo
                    ? () => (_rendererKey.currentState as dynamic)?.undo()
                    : null,
                tooltip: 'Undo',
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                onPressed: _canRedo
                    ? () => (_rendererKey.currentState as dynamic)?.redo()
                    : null,
                tooltip: 'Redo',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => (_rendererKey.currentState as dynamic)?.clearAnnotations(),
                tooltip: 'Clear All Annotations',
              ),
              const VerticalDivider(width: 1, color: Colors.white24),
              // Export/import only on native (requires file system)
              if (!kIsWeb) ...[
                IconButton(
                  icon: const Icon(Icons.file_upload_outlined),
                  onPressed: _exportAnnotations,
                  tooltip: 'Export Annotations',
                ),
                IconButton(
                  icon: const Icon(Icons.file_download_outlined),
                  onPressed: _importAnnotations,
                  tooltip: 'Import Annotations',
                ),
                const VerticalDivider(width: 1, color: Colors.white24),
              ],
            ],
            IconButton(
              icon: Icon(
                _annotationMode ? Icons.draw : Icons.draw_outlined,
                color: _annotationMode ? Colors.amber : null,
              ),
              onPressed: () {
                setState(() {
                  _annotationMode = !_annotationMode;
                });
                (_rendererKey.currentState as dynamic)?.setAnnotationMode(_annotationMode);
              },
              tooltip: _annotationMode ? 'Exit Drawing Mode' : 'Drawing Mode',
            ),
            const VerticalDivider(width: 1, color: Colors.white24),
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: (_annotationMode || _isRendering) ? null : _zoomOut,
              tooltip: 'Zoom Out',
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: (_annotationMode || _isRendering) ? null : _zoomIn,
              tooltip: 'Zoom In',
            ),
            ListenableBuilder(
              listenable: widget.appState,
              builder: (context, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      'Page ${widget.appState.currentPageNumber} of ${widget.appState.totalPages}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: widget.appState,
          builder: (context, _) {
            final page = widget.appState.currentPage;
            if (page == null) {
              return const Center(
                child: Text(
                  'No page to display',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return GestureDetector(
              onTapUp: _annotationMode ? null : (details) => _handleTap(context, details),
              onHorizontalDragEnd: _annotationMode ? null : (details) => _handleSwipe(details),
              child: Stack(
                children: [
                  // Sheet music display
                  SizedBox.expand(
                    child: _SheetMusicPage(
                      key: ValueKey(page.path),
                      page: page,
                      songName: widget.appState.currentSong?.name ?? "",
                      appState: widget.appState,
                      annotationMode: _annotationMode,
                      rendererKey: _rendererKey,
                      onHistoryChanged: (canUndo, canRedo) {
                        setState(() {
                          _canUndo = canUndo;
                          _canRedo = canRedo;
                        });
                      },
                      onAnnotationAdded: _handleAnnotationAdded,
                      onAnnotationRemoved: _handleAnnotationRemoved,
                      onAnnotationsCleared: _handleAnnotationsCleared,
                      onAnnotationsConverted: _handleAnnotationsConverted,
                      onScoreLoaded: _loadSavedAnnotations,
                    ),
                  ),
                  // Navigation overlay
                  _NavigationOverlay(
                    canGoPrevious: widget.appState.canGoPrevious,
                    canGoNext: widget.appState.canGoNext,
                    onPrevious: widget.appState.previousPage,
                    onNext: widget.appState.nextPage,
                  ),
                  // Page indicator
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: _PageIndicator(
                      currentPage: widget.appState.currentPageIndex,
                      totalPages: widget.appState.totalPages,
                      onPageSelected: widget.appState.goToPage,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Annotation Persistence ──────────────────────────────────────

  String get _currentFileId =>
      widget.appState.currentSong?.id ??
      widget.appState.currentPage?.path ??
      'unknown';

  void _handleAnnotationAdded(AnnotationEvent event) {
    final id = _uuid.v4();
    final annotation = Annotation(
      id: id,
      fileId: _currentFileId,
      measureNumber: event.measureNumber,
      type: AnnotationType.freehand,
      data: event.svgPath,
      createdAt: DateTime.now(),
      x: event.x,
      y: event.y,
    );

    _annotationIdsByMeasure
        .putIfAbsent(event.measureNumber, () => [])
        .add(id);

    _annotationRepo.insert(annotation);
    debugPrint('Annotation saved: $id (measure ${event.measureNumber})');
  }

  void _handleAnnotationRemoved(
    int pageIndex,
    int measureNumber,
    int remaining,
  ) {
    final ids = _annotationIdsByMeasure[measureNumber];
    if (ids != null && ids.isNotEmpty) {
      final removedId = ids.removeLast();
      _annotationRepo.delete(removedId);
      debugPrint('Annotation deleted: $removedId (measure $measureNumber)');
    }
  }

  void _handleAnnotationsCleared(int pageIndex) {
    final fileId = _currentFileId;
    _annotationRepo.deleteByFileId(fileId);
    _annotationIdsByMeasure.clear();
    debugPrint('All annotations cleared for file: $fileId');
  }

  void _handleAnnotationsConverted(List<Map<String, dynamic>> annotations) {
    for (final ann in annotations) {
      final measureNumber = ann['measureNumber'] as int;
      final svgPath = ann['svgPath'] as String;
      final x = (ann['x'] as num).toDouble();
      final y = (ann['y'] as num).toDouble();
      
      final ids = _annotationIdsByMeasure[measureNumber];
      if (ids == null || ids.isEmpty) continue;
      
      for (final id in ids) {
        _annotationRepo.updateData(id, svgPath, x, y);
      }
    }
    debugPrint('Updated ${annotations.length} annotations with measure-relative coords');
  }

  /// Detect whether SVG path data is in pixel coordinates or measure-relative (0-1) range.
  /// Measure-relative paths from convertAnnotationsToMeasureRelative have coords in 0-1 range.
  /// Pixel-space paths have coords in canvas pixel range (typically 100+).
  String _detectCoordSystem(String svgPath) {
    final match = RegExp(r'M\s*(-?[\d.]+)\s+(-?[\d.]+)').firstMatch(svgPath);
    if (match == null) return 'pixel';
    final x = double.tryParse(match.group(1)!) ?? 0;
    final y = double.tryParse(match.group(2)!) ?? 0;
    // Measure-relative coords are normalized 0-1 (with some tolerance for near-edge annotations)
    return (x.abs() <= 2.0 && y.abs() <= 2.0) ? 'measure' : 'pixel';
  }

  Future<void> _loadSavedAnnotations() async {
    if (kIsWeb) return;

    final fileId = _currentFileId;
    final saved = await _annotationRepo.getByFileId(fileId);

    // Re-request focus so gamepad/keyboard input works immediately after load
    _focusNode.requestFocus();

    if (saved.isEmpty) return;

    // Rebuild the ID tracking map
    _annotationIdsByMeasure.clear();
    for (final ann in saved) {
      _annotationIdsByMeasure
          .putIfAbsent(ann.measureNumber, () => [])
          .add(ann.id);
    }

    // Convert to the format expected by the JS renderer
    final annotations = saved.map((ann) => <String, dynamic>{
      'svgPath': ann.data,
      'measureNumber': ann.measureNumber,
      'x': ann.x,
      'y': ann.y,
      'color': '#1A3A6B',
      'width': 2.5,
      'coordSystem': _detectCoordSystem(ann.data),
    }).toList();

    (_rendererKey.currentState as dynamic)?.loadAnnotations(annotations);
    debugPrint('Loaded ${saved.length} saved annotations for $fileId');
  }

  Future<void> _exportAnnotations() async {
    final page = widget.appState.currentPage;
    if (page == null || page.path.startsWith('assets/') || page.path.startsWith('demo/')) {
      _showSnackBar('Cannot export annotations for bundled assets');
      return;
    }

    final fileId = _currentFileId;
    final saved = await _annotationRepo.getByFileId(fileId);
    if (saved.isEmpty) {
      _showSnackBar('No annotations to export');
      return;
    }

    try {
      await AnnotationExporter.exportToFile(page.path, saved);
      _showSnackBar('Exported ${saved.length} annotations');
    } catch (e) {
      debugPrint('Export failed: $e');
      _showSnackBar('Export failed: $e');
    }
  }

  Future<void> _importAnnotations() async {
    final page = widget.appState.currentPage;
    if (page == null || page.path.startsWith('assets/') || page.path.startsWith('demo/')) {
      _showSnackBar('Cannot import annotations for bundled assets');
      return;
    }

    try {
      final imported = await AnnotationExporter.importFromFile(page.path);
      if (imported.isEmpty) {
        _showSnackBar('No annotation file found');
        return;
      }

      // Replace existing annotations in the DB for this file
      final fileId = _currentFileId;
      await _annotationRepo.deleteByFileId(fileId);
      await _annotationRepo.insertAll(imported);

      // Rebuild tracking map and reload into renderer
      _annotationIdsByMeasure.clear();
      for (final ann in imported) {
        _annotationIdsByMeasure
            .putIfAbsent(ann.measureNumber, () => [])
            .add(ann.id);
      }

      // Reload annotations into the renderer
      (_rendererKey.currentState as dynamic)?.clearAnnotations();
      final annotationMaps = imported.map((ann) => <String, dynamic>{
        'svgPath': ann.data,
        'measureNumber': ann.measureNumber,
        'x': ann.x,
        'y': ann.y,
        'color': '#1A3A6B',
        'width': 2.5,
      }).toList();
      (_rendererKey.currentState as dynamic)?.loadAnnotations(annotationMaps);

      _showSnackBar('Imported ${imported.length} annotations');
    } catch (e) {
      debugPrint('Import failed: $e');
      _showSnackBar('Import failed: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _handleTap(BuildContext context, TapUpDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    // Tap on left third goes back, right third goes forward
    if (tapX < screenWidth / 3) {
      widget.appState.previousPage();
    } else if (tapX > screenWidth * 2 / 3) {
      widget.appState.nextPage();
    }
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 300) {
      // Swipe right - go back
      widget.appState.previousPage();
    } else if (velocity < -300) {
      // Swipe left - go forward
      widget.appState.nextPage();
    }
  }
}

/// Widget displaying a single sheet music page.
/// Supports MusicXML files and shows a placeholder for demo/missing files.
class _SheetMusicPage extends StatefulWidget {
  final models.Page page;
  final String songName;
  final AppState appState;
  final GlobalKey? rendererKey;
  final bool annotationMode;
  final OnHistoryChanged? onHistoryChanged;
  final OnAnnotationAdded? onAnnotationAdded;
  final OnAnnotationRemoved? onAnnotationRemoved;
  final OnAnnotationsCleared? onAnnotationsCleared;
  final OnAnnotationsConverted? onAnnotationsConverted;
  final VoidCallback? onScoreLoaded;

  const _SheetMusicPage({
    super.key,
    required this.page,
    required this.songName,
    required this.appState,
    this.rendererKey,
    this.annotationMode = false,
    this.onHistoryChanged,
    this.onAnnotationAdded,
    this.onAnnotationRemoved,
    this.onAnnotationsCleared,
    this.onAnnotationsConverted,
    this.onScoreLoaded,
  });

  @override
  State<_SheetMusicPage> createState() => _SheetMusicPageState();
}

class _SheetMusicPageState extends State<_SheetMusicPage> {
  String? _musicXmlContent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void didUpdateWidget(_SheetMusicPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.path != widget.page.path) {
      _disposeControllers();
      _loadPage();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _musicXmlContent = null;
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final ext = widget.page.extension.toLowerCase();

    try {
      if (ext == '.musicxml' || ext == '.xml' || ext == '.mxl') {
        await _loadMusicXml();
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Unsupported file type: $ext';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMusicXml() async {
    final path = widget.page.path;

    try {
      String xmlContent;

      if (path.startsWith('http://') || path.startsWith('https://')) {
        // Network MusicXML
        final bytes = await NetworkAssetBundle(
          Uri.parse(path),
        ).load(path).then((data) => data.buffer.asUint8List());

        try {
          xmlContent = utf8.decode(bytes);
        } catch (_) {
          // If UTF-8 fails, treat as binary (MXL) and Base64 encode it
          xmlContent = base64Encode(bytes);
        }
      } else if (path.startsWith('assets/')) {
        // Asset MusicXML
        try {
          xmlContent = await rootBundle.loadString(path);
        } catch (_) {
          final data = await rootBundle.load(path);
          final bytes = data.buffer.asUint8List();
          xmlContent = base64Encode(bytes);
        }
      } else if (!kIsWeb) {
        // File system MusicXML (not available on web)
        final file = io.File(path);
        try {
          xmlContent = await file.readAsString();
        } catch (_) {
          final bytes = await file.readAsBytes();
          xmlContent = base64Encode(bytes);
        }
      } else {
        throw Exception('Cannot load local files on web');
      }

      debugPrint('Loaded MusicXML content (${xmlContent.length} chars)');
      _musicXmlContent = xmlContent;

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Failed to load MusicXML: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
        _error = 'Failed to load MusicXML: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.white, child: _buildContent());
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const AspectRatio(
        aspectRatio: 8.5 / 11,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      // Show placeholder with error
      return _buildPlaceholder(error: _error);
    }

    final ext = widget.page.extension.toLowerCase();
    final path = widget.page.path;

    // Check if this is a demo/placeholder path
    if (path.startsWith('demo/')) {
      return _buildPlaceholder();
    }

    switch (ext) {
      case '.musicxml':
      case '.xml':
      case '.mxl':
        return _buildMusicXmlView();
      default:
        return _buildPlaceholder(error: 'Unsupported file type: $ext');
    }
  }

  Widget _buildMusicXmlView() {
    if (_musicXmlContent == null) {
      return _buildPlaceholder(error: 'MusicXML content not loaded');
    }

    // Get current orientation to force re-render on rotation
    final orientation = MediaQuery.of(context).orientation;

    // Use platform-adaptive MusicXML renderer for high-quality notation
    // Automatically selects WebView (native) or iframe (web) implementation
    return buildMusicXmlRenderer(
      key:
          widget.rendererKey ??
          ValueKey('musicxml-${widget.page.path}-$orientation'),
      musicXml: _musicXmlContent!,
      backgroundColor: Colors.white,
      annotationMode: widget.annotationMode,
      options: MusicXmlRenderOptions(
        initialPage: widget.page.internalPageNumber,
        currentPage: widget.page.internalPageNumber,
        zoom: widget.appState.zoom,
      ),
      onLoaded: (info) {
        debugPrint('MusicXML loaded: ${info.title} by ${info.composer}');
        debugPrint(
          'Parts: ${info.partCount}, Measures: ${info.measureCount}, Pages: ${info.pageCount}',
        );

        // Notify AppState to expand document if multiple pages exist
        if (info.pageCount > 1) {
          // Update page count (may have changed due to zoom)
          Future.microtask(() {
            widget.appState.expandDocument(info.pageCount);
          });
        }

        // Load saved annotations after score is rendered
        widget.onScoreLoaded?.call();
      },
      onError: (message, type) {
        debugPrint('MusicXML render error ($type): $message');
      },
      onHistoryChanged: widget.onHistoryChanged,
      onAnnotationAdded: widget.onAnnotationAdded,
      onAnnotationRemoved: widget.onAnnotationRemoved,
      onAnnotationsCleared: widget.onAnnotationsCleared,
      onAnnotationsConverted: widget.onAnnotationsConverted,
    );
  }

  Widget _buildPlaceholder({String? error}) {
    return AspectRatio(
      aspectRatio: 8.5 / 11,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // Title
            Text(
              widget.songName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Page ${widget.page.pageNumber}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        error,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            // Mock staff lines
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  6,
                  (staffIndex) => _StaffLines(staffIndex: staffIndex),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws 5 horizontal lines representing a musical staff.
class _StaffLines extends StatelessWidget {
  final int staffIndex;

  const _StaffLines({required this.staffIndex});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          5,
          (index) => Container(height: 1, color: Colors.black87),
        ),
      ),
    );
  }
}

/// Navigation overlay with previous/next buttons.
class _NavigationOverlay extends StatelessWidget {
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _NavigationOverlay({
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Previous button
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedOpacity(
                opacity: canGoPrevious ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  onPressed: canGoPrevious ? onPrevious : null,
                  icon: const Icon(Icons.chevron_left, size: 48),
                  color: Colors.white70,
                  tooltip: 'Previous page',
                ),
              ),
            ),
          ),
        ),
        // Next button
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedOpacity(
                opacity: canGoNext ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  onPressed: canGoNext ? onNext : null,
                  icon: const Icon(Icons.chevron_right, size: 48),
                  color: Colors.white70,
                  tooltip: 'Next page',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Page indicator dots at the bottom.
class _PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageSelected;

  const _PageIndicator({
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    // For many pages, show a simplified indicator
    if (totalPages > 10) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${currentPage + 1} / $totalPages',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            totalPages,
            (index) => GestureDetector(
              onTap: () => onPageSelected(index),
              child: Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == currentPage
                      ? Colors.white
                      : Colors.white.withAlpha(102),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
