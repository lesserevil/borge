import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdfx/pdfx.dart';

import '../models/models.dart' as models;
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

  @override
  void initState() {
    super.initState();
    // Request focus for keyboard navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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
        widget.appState.zoom = (widget.appState.zoom + 0.1).clamp(0.5, 3.0);
      } else if (event.logicalKey == LogicalKeyboardKey.minus ||
                 event.logicalKey == LogicalKeyboardKey.underscore) {
        widget.appState.zoom = (widget.appState.zoom - 0.1).clamp(0.5, 3.0);
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
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: () => widget.appState.zoom = (widget.appState.zoom - 0.1).clamp(0.5, 3.0),
              tooltip: 'Zoom Out',
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: () => widget.appState.zoom = (widget.appState.zoom + 0.1).clamp(0.5, 3.0),
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
              onTapUp: (details) => _handleTap(context, details),
              onHorizontalDragEnd: (details) => _handleSwipe(details),
              child: Stack(
                children: [
                  // Sheet music display
                SizedBox.expand(
                  child: _SheetMusicPage(
                    key: ValueKey(page.path),
                    page: page,
                    songName: widget.appState.currentSong?.name ?? "",
                    appState: widget.appState,
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
/// Supports PDF, PNG, JPG, SVG, and shows a placeholder for demo/missing files.
class _SheetMusicPage extends StatefulWidget {
  final models.Page page;
  final String songName;
  final AppState appState;

  const _SheetMusicPage({
    super.key,
    required this.page,
    required this.songName,
    required this.appState,
  });

  @override
  State<_SheetMusicPage> createState() => _SheetMusicPageState();
}

class _SheetMusicPageState extends State<_SheetMusicPage> {
  PdfControllerPinch? _pdfController;
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
    _pdfController?.dispose();
    _pdfController = null;
    _musicXmlContent = null;
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final ext = widget.page.extension.toLowerCase();

    try {
      if (ext == '.pdf') {
        await _loadPdf();
      } else if (ext == '.musicxml' || ext == '.xml' || ext == '.mxl') {
        await _loadMusicXml();
      } else {
        // For images and SVGs, just mark as loaded - they load on demand
        setState(() {
          _isLoading = false;
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

  Future<void> _loadPdf() async {
    final path = widget.page.path;

    try {
      PdfDocument document;

      if (path.startsWith('http://') || path.startsWith('https://')) {
        // Network PDF
        document = await PdfDocument.openData(
          await NetworkAssetBundle(
            Uri.parse(path),
          ).load(path).then((data) => data.buffer.asUint8List()),
        );
      } else if (path.startsWith('assets/')) {
        // Asset PDF
        document = await PdfDocument.openAsset(path);
      } else if (!kIsWeb) {
        // File system PDF (not available on web)
        document = await PdfDocument.openFile(path);
      } else {
        throw Exception('Cannot load local files on web');
      }

      _pdfController = PdfControllerPinch(document: Future.value(document));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load PDF: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: _buildContent(),
    );
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
      case '.pdf':
        return _buildPdfView();
      case '.svg':
        return _buildSvgView(path);
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.webp':
        return _buildImageView(path);
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

    // Use platform-adaptive MusicXML renderer for high-quality notation
    // Automatically selects WebView (native) or iframe (web) implementation
    return buildMusicXmlRenderer(
      key: ValueKey('musicxml-${widget.page.path}'),
      musicXml: _musicXmlContent!,
      backgroundColor: Colors.white,
      options: MusicXmlRenderOptions(
        initialPage: widget.page.internalPageNumber,
        currentPage: widget.page.internalPageNumber,
        zoom: widget.appState.zoom,
      ),
      onLoaded: (info) {
        debugPrint('MusicXML loaded: ${info.title} by ${info.composer}');
        debugPrint('Parts: ${info.partCount}, Measures: ${info.measureCount}, Pages: ${info.pageCount}');
        
        // Notify AppState to expand document if multiple pages exist
        if (info.pageCount > 1) {
          // Update page count (may have changed due to zoom)
          Future.microtask(() {
            widget.appState.expandDocument(info.pageCount);
          });
        }
      },
      onError: (message, type) {
        debugPrint('MusicXML render error ($type): $message');
      },
    );
  }

  Widget _buildPdfView() {
    if (_pdfController == null) {
      return _buildPlaceholder(error: 'PDF controller not initialized');
    }

    return AspectRatio(
      aspectRatio: 8.5 / 11,
      child: PdfViewPinch(
        controller: _pdfController!,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          pageLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, error) => Center(
            child: Text(
              'Error loading PDF: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSvgView(String path) {
    Widget svgWidget;

    if (path.startsWith('http://') || path.startsWith('https://')) {
      svgWidget = SvgPicture.network(
        path,
        fit: BoxFit.contain,
        placeholderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
      );
    } else if (path.startsWith('assets/')) {
      svgWidget = SvgPicture.asset(path, fit: BoxFit.contain);
    } else if (!kIsWeb) {
      // Load SVG from file system (not available on web)
      return _buildSvgFromFile(path);
    } else {
      return _buildPlaceholder(error: 'Cannot load local files on web');
    }

    return AspectRatio(
      aspectRatio: 8.5 / 11,
      child: Padding(padding: const EdgeInsets.all(16), child: svgWidget),
    );
  }

  Widget _buildSvgFromFile(String path) {
    // Read SVG file and render from string to avoid File type conflicts
    return FutureBuilder<String>(
      future: io.File(path).readAsString(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AspectRatio(
            aspectRatio: 8.5 / 11,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _buildPlaceholder(
            error: 'Failed to load SVG: ${snapshot.error}',
          );
        }
        return AspectRatio(
          aspectRatio: 8.5 / 11,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SvgPicture.string(snapshot.data!, fit: BoxFit.contain),
          ),
        );
      },
    );
  }

  Widget _buildImageView(String path) {
    Widget imageWidget;

    if (path.startsWith('http://') || path.startsWith('https://')) {
      imageWidget = Image.network(
        path,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      );
    } else if (path.startsWith('assets/')) {
      imageWidget = Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(error: 'Asset not found: $path');
        },
      );
    } else if (!kIsWeb) {
      imageWidget = Image.file(
        io.File(path),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(error: 'File not found: $path');
        },
      );
    } else {
      return _buildPlaceholder(error: 'Cannot load local files on web');
    }

    return AspectRatio(
      aspectRatio: 8.5 / 11,
      child: Padding(padding: const EdgeInsets.all(16), child: imageWidget),
    );
  }

  /// Builds a placeholder with mock staff lines for demo mode.
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
