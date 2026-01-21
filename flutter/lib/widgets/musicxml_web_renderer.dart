import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'musicxml_types.dart';
// import 'musicxml_web_renderer_html.dart'; // Avoid importing web-only file in native
import '../services/musicxml_splitter.dart';

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

  const MusicXmlWebRenderer({
    super.key,
    this.musicXml,
    this.musicXmlUrl,
    this.options = const MusicXmlRenderOptions(),
    this.backgroundColor = Colors.white,
    this.onLoaded,
    this.onError,
    this.onReady,
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

  // Splitting and Caching state
  String? _fullMusicXml;
  final Map<int, String> _pageXmlCache = {};
  final Map<int, int> _pageStartMeasure = {0: 0};
  int _currentPageIndex = 0;
  int _totalMeasureCount = 0;
  bool _isSplitting = false;

  @override
  void initState() {
    super.initState();
    _loadHtmlTemplate();
  }

  @override
  void didUpdateWidget(MusicXmlWebRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload if content changed
    if (oldWidget.musicXml != widget.musicXml ||
        oldWidget.musicXmlUrl != widget.musicXmlUrl) {
      _loadContent();
    }

    // Update zoom if changed
    if (oldWidget.options.zoom != widget.options.zoom) {
      setZoom(widget.options.zoom);
    }

    if (oldWidget.options.currentPage != widget.options.currentPage &&
        widget.options.currentPage != null) {
      setPage(widget.options.currentPage!);
    }
  }

  Future<void> _loadHtmlTemplate() async {
    try {
      // Load the HTML template from assets
      final html = await rootBundle.loadString(
        'assets/html/osmd_template.html',
      );
      setState(() {
        _htmlContent = html;
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
        ..loadHtmlString(_htmlContent!, baseUrl: 'https://localhost');

      setState(() {
        _controller = controller;
      });
    } catch (e) {
      debugPrint('WebView initialization failed: $e');
      setState(() {
        _error = 'WebView is not supported on this platform.\n'
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
          widget.onError?.call(errorMsg, errorType);
          break;
      }
    } catch (e) {
      debugPrint('Error parsing JS message: $e');
    }
  }

  void _sendToJs(String action, [dynamic payload]) {
    if (_controller == null) return;

    final message = jsonEncode({'action': action, 'payload': payload});

    _controller!.runJavaScript('handleFlutterMessage($message)');
  }

  void _loadContent() {
    if (!_isReady) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (widget.musicXml != null) {
      if (_fullMusicXml != widget.musicXml) {
        _fullMusicXml = widget.musicXml;
        _pageXmlCache.clear();
        _pageStartMeasure.clear();
        _pageStartMeasure[0] = 0;
        _currentPageIndex = 0;
        _totalMeasureCount = MusicXmlSplitter.getMeasureCount(_fullMusicXml!);
      }

      _loadCurrentPage();
    } else if (widget.musicXmlUrl != null) {
      // For URL, we don't support splitting easily yet unless we fetch it first
      _sendToJs('loadUrl', {'url': widget.musicXmlUrl});
    }
  }

  void _loadCurrentPage() {
    if (_fullMusicXml == null) return;

    String? xmlToLoad = _pageXmlCache[_currentPageIndex];
    
    if (xmlToLoad == null) {
      final start = _pageStartMeasure[_currentPageIndex] ?? 0;
      xmlToLoad = MusicXmlSplitter.split(_fullMusicXml!, start, _totalMeasureCount - 1);
    }

    _sendToJs('load', {'xml': xmlToLoad});
  }

  void _handleScoreLoaded(MusicXmlScoreInfo info) {
    setState(() {
      _isLoading = false;
      _isSplitting = false;
    });

    // If we just loaded a page, and we have a lastFittingMeasure,
    // we can calculate the start of the NEXT page.
    if (info.lastFittingMeasure != -1 && info.lastFittingMeasure < _totalMeasureCount - 1) {
      final nextStart = info.lastFittingMeasure + 1;
      _pageStartMeasure[_currentPageIndex + 1] = nextStart;
      
      // Update cache for current page if not already there
      if (!_pageXmlCache.containsKey(_currentPageIndex)) {
          final start = _pageStartMeasure[_currentPageIndex] ?? 0;
          _pageXmlCache[_currentPageIndex] = MusicXmlSplitter.split(_fullMusicXml!, start, info.lastFittingMeasure);
          
          // Reload the page with the truncated XML to ensure visual correctness
          _loadCurrentPage();
      }
    }

    // If we have total measures and last fitting measure, we can estimate better.
    int estimatedPages = info.pageCount;
    if (_totalMeasureCount > 0 && info.lastFittingMeasure != -1) {
        // Simple estimate: if current page fits N measures (from start...lastFitting),
        // and we have T total. 
        // Note: info.lastFittingMeasure is 0-indexed index of last measure on THIS page.
        // Measures on this page = (lastFittingMeasure + 1) - startMeasureOfPage.
        
        final startMeasure = _pageStartMeasure[_currentPageIndex] ?? 0;
        final measuresOnThisPage = (info.lastFittingMeasure + 1) - startMeasure;
        
        if (measuresOnThisPage > 0) {
            // How many measures left?
            final measuresLeft = _totalMeasureCount - (info.lastFittingMeasure + 1);
            if (measuresLeft > 0) {
                final pagesLeft = (measuresLeft / measuresOnThisPage).ceil();
                estimatedPages = (_currentPageIndex + 1) + pagesLeft;
            } else {
                estimatedPages = _currentPageIndex + 1;
            }
        }
    } else if (_totalMeasureCount > 0 && info.measureCount < _totalMeasureCount) {
        // Fallback: we don't know the exact fitting measure, but we know the sub-doc
        // is smaller than the total. Assume at least one more page.
        // We ensure button is enabled by saying pageCount = current + 2
        // (current page is +1, plus at least one more)
        estimatedPages = (_currentPageIndex + 1) + 1;
    }
    
    // Create new info object with estimated page count
    final updatedInfo = MusicXmlScoreInfo(
        title: info.title,
        composer: info.composer,
        subtitle: info.subtitle,
        partCount: info.partCount,
        measureCount: info.measureCount, // This is measure count of the sub-doc
        pageCount: estimatedPages,
        lastFittingMeasure: info.lastFittingMeasure,
        totalMeasureCount: _totalMeasureCount,
    );

    // Report to parent
    widget.onLoaded?.call(updatedInfo);
  }

  /// Set the current page in a paginated view.
  void setPage(int page) {
    if (page - 1 == _currentPageIndex) return;
    
    setState(() {
        _currentPageIndex = page - 1;
        _isLoading = true;
    });
    
    _loadCurrentPage();
  }

  /// Reload the current content.
  void reload() {
    _loadContent();
  }

  /// Set the zoom level (1.0 = 100%).
  void setZoom(double zoom) {
    _sendToJs('setZoom', {'zoom': zoom});
    // Invalidate cache on zoom change because fit will change
    _pageXmlCache.clear();
    _pageStartMeasure.clear();
    _pageStartMeasure[0] = 0;
    _currentPageIndex = 0;
    _loadCurrentPage();
  }

  /// Navigate to a specific measure.
  void goToMeasure(int measureNumber) {
    _sendToJs('goToMeasure', {'measure': measureNumber});
  }

  /// Clear the rendered content.
  void clear() {
    _sendToJs('clear');
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
