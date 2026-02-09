import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'musicxml_types.dart';

/// A widget that renders MusicXML content using OpenSheetMusicDisplay via WebView.
///
/// This provides high-quality, professional music notation rendering by leveraging
/// the OpenSheetMusicDisplay (OSMD) JavaScript library.
///
/// Example usage:
/// ```dart
/// MusicXmlWebRenderer(
///   musicXml: myMusicXmlString,
///   onLoaded: (info) => print('Loaded: ${info.title}'),
///   onError: (msg, type) => print('Error: $msg'),
/// )
/// ```
class MusicXmlWebRenderer extends StatefulWidget {
  /// The MusicXML content to render.
  final String? musicXml;

  /// URL to load MusicXML from (alternative to musicXml).
  final String? musicXmlUrl;

  /// Rendering options.
  final MusicXmlRenderOptions options;

  /// Background color for the renderer.
  final Color backgroundColor;

  /// Called when the score is successfully loaded.
  final OnScoreLoaded? onLoaded;

  /// Called when an error occurs.
  final OnError? onError;

  /// Called when the renderer is ready to accept content.
  final OnReady? onReady;

  /// Called when a freehand annotation is added via drawing.
  final OnAnnotationAdded? onAnnotationAdded;

  /// Called when an annotation is removed.
  final OnAnnotationRemoved? onAnnotationRemoved;

  /// Called when annotations are cleared.
  final OnAnnotationsCleared? onAnnotationsCleared;

  /// Called when annotation drawing mode changes.
  final OnAnnotationModeChanged? onAnnotationModeChanged;

  /// Called when undo/redo history state changes.
  final OnHistoryChanged? onHistoryChanged;

  const MusicXmlWebRenderer({
    super.key,
    this.musicXml,
    this.musicXmlUrl,
    this.options = const MusicXmlRenderOptions(),
    this.backgroundColor = Colors.white,
    this.onLoaded,
    this.onError,
    this.onReady,
    this.onAnnotationAdded,
    this.onAnnotationRemoved,
    this.onAnnotationsCleared,
    this.onAnnotationModeChanged,
    this.onHistoryChanged,
  }) : assert(
         musicXml != null || musicXmlUrl != null,
         'Either musicXml or musicXmlUrl must be provided',
       );

  @override
  State<MusicXmlWebRenderer> createState() => MusicXmlWebRendererState();
}

class MusicXmlWebRendererState extends State<MusicXmlWebRenderer> {
  WebViewController? _controller;
  bool _isReady = false;
  bool _isLoading = true;
  String? _error;
  String? _htmlContent;

  // Completer to track when load is truly complete
  Completer<void>? _loadCompleter;

  @override
  void initState() {
    super.initState();
    _loadHtmlTemplate();
  }

  @override
  void didUpdateWidget(MusicXmlWebRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);

    debugPrint('=== TRACE: didUpdateWidget called');

    // Reload if content changed - wait for it to complete
    if (oldWidget.musicXml != widget.musicXml ||
        oldWidget.musicXmlUrl != widget.musicXmlUrl) {
      debugPrint('=== TRACE: Content changed, loading...');
      _loadContent().then((_) {
        debugPrint('=== TRACE: Load completed in didUpdateWidget');
        // Content loaded, now safe to handle other updates
      });
      return; // Don't process other changes while loading
    }

    // Update zoom if changed
    if (oldWidget.options.zoom != widget.options.zoom) {
      debugPrint('=== TRACE: Zoom changed to ${widget.options.zoom}');
      setZoom(widget.options.zoom);
    }

    if (oldWidget.options.currentPage != widget.options.currentPage &&
        widget.options.currentPage != null) {
      debugPrint(
        '=== TRACE: currentPage changed from ${oldWidget.options.currentPage} to ${widget.options.currentPage}',
      );
      // Don't trigger setPage if this is the initial expansion (null -> 1)
      if (oldWidget.options.currentPage != null ||
          widget.options.currentPage != 1) {
        debugPrint('=== TRACE: Calling setPage(${widget.options.currentPage})');
        setPage(widget.options.currentPage!);
      } else {
        debugPrint('=== TRACE: Skipping setPage (initial expansion)');
      }
    }
  }

  Future<void> _loadHtmlTemplate() async {
    try {
      // Load the HTML template and OSMD library from assets
      final html = await rootBundle.loadString(
        'assets/html/osmd_template.html',
      );
      final osmdJs = await rootBundle.loadString(
        'assets/js/opensheetmusicdisplay.min.js',
      );

      // Replace the script tag with inline JavaScript
      final htmlWithEmbeddedJs = html.replaceFirst(
        '<script src="opensheetmusicdisplay.min.js"></script>',
        '<script>$osmdJs</script>',
      );

      setState(() {
        _htmlContent = htmlWithEmbeddedJs;
      });
      _initWebView();
    } catch (e, stackTrace) {
      debugPrint('Failed to load OSMD template: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _error = 'Failed to load renderer template: $e';
        _isLoading = false;
        _htmlContent = ''; // Set to empty string to avoid loading spinner loop
      });
    }
  }

  void _initWebView() {
    if (_htmlContent == null) return;

    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(widget.backgroundColor)
        ..addJavaScriptChannel(
          'FlutterChannel',
          onMessageReceived: _handleJsMessage,
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              // Initialize OSMD after page loads
              _sendToJs('init', widget.options.toJson());
            },
            onWebResourceError: (error) {
              debugPrint('WebView error: ${error.description}');
              setState(() {
                _error = error.description;
                _isLoading = false;
              });
            },
          ),
        )
        ..loadHtmlString(_htmlContent!);

      setState(() {
        _controller = controller;
      });
    } catch (e) {
      debugPrint('WebView initialization failed: $e');
      setState(() {
        _error =
            'WebView is not supported on this platform.\n'
            'Full MusicXML rendering (OSMD) requires Android or iOS.\n'
            'Local development on Linux should use an Android/iOS emulator.';
        _isLoading = false;
      });
    }
  }

  void _handleJsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String;
      final payload = data['data'] as Map<String, dynamic>?;

      switch (type) {
        case 'ready':
          setState(() {
            _isReady = true;
            _isLoading = false;
          });
          widget.onReady?.call();
          // Load content now that OSMD is ready
          _loadContent();
          break;

        case 'loaded':
          if (payload != null) {
            final info = MusicXmlScoreInfo.fromJson(payload);
            _handleScoreLoaded(info);
          }
          break;

        case 'error':
          final errorMsg = payload?['message'] as String? ?? 'Unknown error';
          final errorType = payload?['type'] as String? ?? 'unknown';
          setState(() {
            _error = errorMsg;
            _isLoading = false;
          });

          // Complete the load operation with error
          if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
            _loadCompleter!.completeError(errorMsg);
          }

          widget.onError?.call(errorMsg, errorType);
          break;

        // ── Annotation Events ──
        case 'annotationAdded':
          if (payload != null) {
            final event = AnnotationEvent.fromJson(payload);
            widget.onAnnotationAdded?.call(event);
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
            widget.onAnnotationsCleared?.call(
              payload['pageIndex'] as int? ?? -1,
            );
          }
          break;

        case 'annotationModeChanged':
          if (payload != null) {
            widget.onAnnotationModeChanged?.call(
              payload['enabled'] as bool? ?? false,
            );
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
      }
    } catch (e) {
      debugPrint('Error parsing JS message: $e');
    }
  }

  void _sendToJs(String action, [dynamic payload]) {
    if (_controller == null) return;

    final message = jsonEncode({'action': action, 'payload': payload});

    // Debug: Check if we're sending XML
    if (action == 'load' && payload is Map && payload['xml'] != null) {
      final xml = payload['xml'] as String;
      debugPrint(
        'Sending XML to JS (first 100 chars): ${xml.substring(0, xml.length > 100 ? 100 : xml.length)}',
      );
    }

    // Escape for JavaScript string literal
    final escapedMessage = message
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');

    _controller!.runJavaScript("handleFlutterMessage('$escapedMessage')");
  }

  Future<void> _loadContent() async {
    if (!_isReady) return;

    // Create a new completer for this load operation
    _loadCompleter = Completer<void>();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (widget.musicXml != null) {
      // Always load the FULL document - no splitting!
      _sendToJs('load', {'xml': widget.musicXml});
    } else if (widget.musicXmlUrl != null) {
      _sendToJs('loadUrl', {'url': widget.musicXmlUrl});
    }

    // Wait for the load to complete
    return _loadCompleter!.future;
  }

  void _handleScoreLoaded(MusicXmlScoreInfo info) {
    debugPrint('=== TRACE: _handleScoreLoaded START (page=${info.pageCount})');

    setState(() {
      _isLoading = false;
    });

    debugPrint('=== TRACE: Completing load completer');
    // Complete the load operation
    if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
      _loadCompleter!.complete();
    }

    // Report to parent - just pass through the info from OSMD
    debugPrint(
      '=== TRACE: Calling widget.onLoaded callback (pageCount=${info.pageCount})',
    );
    widget.onLoaded?.call(info);
    debugPrint('=== TRACE: _handleScoreLoaded END');
  }

  /// Set the current page in a paginated view.
  void setPage(int page) {
    // Just tell OSMD to scroll to the page - no reloading needed!
    _sendToJs('setPage', {'page': page});
  }

  /// Reload the current content.
  void reload() {
    _loadContent();
  }

  /// Set the zoom level (1.0 = 100%).
  void setZoom(double zoom) {
    // Update zoom level in JavaScript
    _controller?.runJavaScript('zoomLevel = $zoom;');

    // Reload the FULL document at new zoom
    setState(() {
      _isLoading = true;
    });
    _loadContent();
  }

  /// Navigate to a specific measure.
  void goToMeasure(int measureNumber) {
    _sendToJs('goToMeasure', {'measure': measureNumber});
  }

  /// Clear the rendered content.
  void clear() {
    _sendToJs('clear');
  }

  // ── Annotation Control Methods ──────────────────────────────────

  /// Enable or disable annotation drawing mode.
  void setAnnotationMode(bool enabled) {
    _sendToJs('setAnnotationMode', {'enabled': enabled});
  }

  /// Set the stroke color and width for drawing annotations.
  void setAnnotationStyle({String? color, double? width}) {
    _sendToJs('setAnnotationStyle', {
      if (color != null) 'color': color,
      if (width != null) 'width': width,
    });
  }

  /// Load previously saved annotations into the renderer.
  ///
  /// Each annotation should have: pageIndex, svgPath, measureNumber, x, y,
  /// color, width.
  void loadAnnotations(List<Map<String, dynamic>> annotations) {
    _sendToJs('loadAnnotations', {'annotations': annotations});
  }

  /// Clear annotations for a specific page, or all pages if [pageIndex] is null.
  void clearAnnotations({int? pageIndex}) {
    _sendToJs('clearAnnotations', {'pageIndex': pageIndex});
  }

  /// Remove the last drawn annotation from a specific page.
  void removeLastAnnotation(int pageIndex) {
    _sendToJs('removeLastAnnotation', {'pageIndex': pageIndex});
  }

  /// Add a structured annotation symbol to a specific page.
  ///
  /// [kind] must be one of: 'fingerNumber', 'dynamicMark', 'bowing', 'articulation'.
  /// [data] contains symbol-specific values (e.g., {'value': '3'} for finger number).
  void addStructuredAnnotation({
    required int pageIndex,
    required String kind,
    required int measureNumber,
    required double x,
    required double y,
    Map<String, dynamic>? data,
  }) {
    _sendToJs('addStructuredAnnotation', {
      'pageIndex': pageIndex,
      'kind': kind,
      'measureNumber': measureNumber,
      'x': x,
      'y': y,
      'data': data ?? {},
    });
  }

  /// Undo the last annotation action.
  void undo() {
    _sendToJs('undo');
  }

  /// Redo the last undone annotation action.
  void redo() {
    _sendToJs('redo');
  }

  @override
  Widget build(BuildContext context) {
    // WebView is not supported on web platform
    if (kIsWeb) {
      return _buildWebFallback();
    }

    if (_error != null) {
      return _buildError();
    }

    if (_htmlContent == null || _controller == null) {
      return _buildLoading();
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading) _buildLoading(),
        if (_error != null) _buildError(),
      ],
    );
  }

  Widget _buildLoading() {
    return Container(
      color: widget.backgroundColor,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading sheet music...'),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: widget.backgroundColor,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to render sheet music',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Fallback for web platform - returns the web-specific renderer.
  Widget _buildWebFallback() {
    // Import the web implementation dynamically to avoid dart:html on native
    return _WebRendererWrapper(
      musicXml: widget.musicXml,
      musicXmlUrl: widget.musicXmlUrl,
      options: widget.options,
      backgroundColor: widget.backgroundColor,
      onLoaded: widget.onLoaded,
      onError: widget.onError,
      onReady: widget.onReady,
    );
  }
}

/// Wrapper that lazily loads the web implementation.
/// This avoids importing dart:html on native platforms.
class _WebRendererWrapper extends StatelessWidget {
  final String? musicXml;
  final String? musicXmlUrl;
  final MusicXmlRenderOptions options;
  final Color backgroundColor;
  final OnScoreLoaded? onLoaded;
  final OnError? onError;
  final OnReady? onReady;

  const _WebRendererWrapper({
    this.musicXml,
    this.musicXmlUrl,
    this.options = const MusicXmlRenderOptions(),
    this.backgroundColor = Colors.white,
    this.onLoaded,
    this.onError,
    this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    // On web, we need to use the HTML implementation
    // This widget should only be built when kIsWeb is true
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note, size: 64, color: Colors.blue[400]),
            const SizedBox(height: 16),
            Text(
              'MusicXML Web Renderer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use MusicXmlWebRendererHtml widget directly for web platform.\n'
              'Import from musicxml_web_renderer_html.dart',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
