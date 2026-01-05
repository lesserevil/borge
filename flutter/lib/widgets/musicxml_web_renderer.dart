import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Information about the loaded score.
class MusicXmlScoreInfo {
  final String title;
  final String composer;
  final String subtitle;
  final int partCount;
  final int measureCount;

  const MusicXmlScoreInfo({
    this.title = '',
    this.composer = '',
    this.subtitle = '',
    this.partCount = 0,
    this.measureCount = 0,
  });

  factory MusicXmlScoreInfo.fromJson(Map<String, dynamic> json) {
    return MusicXmlScoreInfo(
      title: json['title'] as String? ?? '',
      composer: json['composer'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      partCount: json['partCount'] as int? ?? 0,
      measureCount: json['measureCount'] as int? ?? 0,
    );
  }
}

/// Configuration options for the MusicXML renderer.
class MusicXmlRenderOptions {
  /// Whether to draw the title.
  final bool drawTitle;

  /// Whether to draw the composer name.
  final bool drawComposer;

  /// Whether to draw measure numbers.
  final bool drawMeasureNumbers;

  /// Whether to draw time signatures.
  final bool drawTimeSignatures;

  /// Whether to draw part names.
  final bool drawPartNames;

  /// Zoom level (1.0 = 100%).
  final double zoom;

  const MusicXmlRenderOptions({
    this.drawTitle = true,
    this.drawComposer = true,
    this.drawMeasureNumbers = true,
    this.drawTimeSignatures = true,
    this.drawPartNames = true,
    this.zoom = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'drawTitle': drawTitle,
      'drawComposer': drawComposer,
      'drawMeasureNumbers': drawMeasureNumbers,
      'drawTimeSignatures': drawTimeSignatures,
      'drawPartNames': drawPartNames,
    };
  }
}

/// Callback types for renderer events.
typedef OnScoreLoaded = void Function(MusicXmlScoreInfo info);
typedef OnError = void Function(String message, String type);
typedef OnReady = void Function();

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
    } catch (e) {
      debugPrint('Failed to load OSMD template: $e');
      setState(() {
        _error = 'Failed to load renderer template';
        _isLoading = false;
      });
    }
  }

  void _initWebView() {
    if (_htmlContent == null) return;

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
          setState(() {
            _isLoading = false;
            _error = null;
          });
          if (payload != null) {
            widget.onLoaded?.call(MusicXmlScoreInfo.fromJson(payload));
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
      // Escape the XML for JSON
      _sendToJs('load', {'xml': widget.musicXml});
    } else if (widget.musicXmlUrl != null) {
      _sendToJs('loadUrl', {'url': widget.musicXmlUrl});
    }
  }

  /// Reload the current content.
  void reload() {
    _loadContent();
  }

  /// Set the zoom level (1.0 = 100%).
  void setZoom(double zoom) {
    _sendToJs('setZoom', {'zoom': zoom});
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
