import 'dart:convert';
import 'dart:io' show Platform, File, Directory;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Conditionally import libraries to avoid compilation errors on incorrect platforms
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';

// ignore: uri_does_not_exist
import 'package:webview_cef/webview_cef.dart' as cef;

// Web-specific imports (stubbed on other platforms if needed, but we use conditional imports or kIsWeb check)
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'musicxml_types.dart';

/// A MusicXML renderer that uses Verovio (WASM) for high-quality, reflowable engraving.
class MusicXmlVerovioRenderer extends StatefulWidget {
  final String? musicXml;
  final String? musicXmlUrl;
  final MusicXmlRenderOptions options;
  final Color backgroundColor;
  final OnScoreLoaded? onLoaded;
  final OnError? onError;

  const MusicXmlVerovioRenderer({
    super.key,
    this.musicXml,
    this.musicXmlUrl,
    this.options = const MusicXmlRenderOptions(),
    this.backgroundColor = Colors.white,
    this.onLoaded,
    this.onError,
  });

  @override
  State<MusicXmlVerovioRenderer> createState() => _MusicXmlVerovioRendererState();
}

class _MusicXmlVerovioRendererState extends State<MusicXmlVerovioRenderer> {
  // webview_flutter members (Mobile)
  WebViewController? _controller;
  
  // webview_cef members (Linux)
  cef.WebViewController? _cefController;

  // IFrame member (Web)
  html.IFrameElement? _iframe;
  String? _viewType;
  
  bool _isLoading = true;
  String? _error;
  String? _htmlContent;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWebIframe();
    } else {
      _loadHtmlTemplate();
    }
  }

  @override
  void didUpdateWidget(MusicXmlVerovioRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.musicXml != widget.musicXml) {
       _loadContent();
    }
  }

  void _initWebIframe() {
    final frameId = 'verovio-frame-${DateTime.now().millisecondsSinceEpoch}';
    _viewType = 'verovio-iframe-$frameId';

    _iframe = html.IFrameElement()
      ..src = 'assets/assets/html/verovio_template.html'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';

    // Register view factory
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType!,
      (int viewId) => _iframe!,
    );

    // Initial listener
    html.window.onMessage.listen((event) {
      // Basic security check: ensure data is what we expect
      if (event.data is String) {
        _handleJsMessage(event.data);
      }
    });

    setState(() {
      _isLoading = false; 
    });
  }

  Future<void> _loadHtmlTemplate() async {
    try {
      if (Platform.isLinux) {
        await _initCefWebView();
      } else {
        _htmlContent = await rootBundle.loadString('assets/html/verovio_template.html');
        _initMobileWebView();
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to load Verovio template: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _error = 'Failed to load Verovio engine: $e';
        _isLoading = false;
      });
    }
  }

  void _initMobileWebView() {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(widget.backgroundColor)
        ..addJavaScriptChannel(
          'FlutterChannel',
          onMessageReceived: (message) => _handleJsMessage(message.message),
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              _isReady = true;
              _loadContent();
            },
            onWebResourceError: (error) {
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
        _error = 'WebView not supported on this platform.';
        _isLoading = false;
      });
    }
  }

  Future<void> _initCefWebView() async {
    try {
      final controller = cef.WebviewManager().createWebView();
      await cef.WebviewManager().ready;
      
      final tempDir = await getTemporaryDirectory();
      final htmlFile = await _copyAssetToTemp('assets/html/verovio_template.html', 'verovio_template.html', tempDir);
      await _copyAssetToTemp('assets/js/verovio-toolkit-wasm.js', 'verovio-toolkit-wasm.js', tempDir);
      
      debugPrint('Initializing Verovio with file: ${htmlFile.uri}');
      await controller.initialize(htmlFile.uri.toString());

      controller.setJavaScriptChannels({
        cef.JavascriptChannel(
          name: 'FlutterChannel',
          onMessageReceived: (message) => _handleJsMessage(message.message),
        ),
      });

      setState(() {
        _cefController = controller;
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          // Assuming ready after a second as fallback if JS doesn't fire
          // But usually we wait for 'ready' message
        }
      });
    } catch (e) {
      debugPrint('CEF WebView initialization failed: $e');
      setState(() {
        _error = 'CEF WebView initialization failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<File> _copyAssetToTemp(String assetPath, String filename, Directory tempDir) async {
    final ByteData data = await rootBundle.load(assetPath);
    final List<int> bytes = data.buffer.asUint8List();
    final File file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  void _handleJsMessage(String message) {
    try {
      final data = jsonDecode(message);
      final action = data['action'];

      switch (action) {
        // 'ready' is sent by JS when Verovio toolkit is initialized
        case 'ready':
          debugPrint('Verovio engine reported READY');
          setState(() {
             _isReady = true;
          });
          _loadContent();
          break;
        case 'scoreLoaded':
          setState(() {
            _isLoading = false;
          });
          final scoreData = data['data'];
          widget.onLoaded?.call(MusicXmlScoreInfo(
            title: scoreData['title'] ?? '',
            composer: scoreData['composer'] ?? '',
            pageCount: scoreData['pageCount'] ?? 1,
          ));
          break;
        case 'error':
          setState(() {
            _error = data['message'];
            _isLoading = false;
          });
          widget.onError?.call(data['message'], 'verovio');
          break;
      }
    } catch (e) {
      debugPrint('Error parsing JS message: $e');
    }
  }

  void _loadContent() {
    if (!_isReady) return;

    if (widget.musicXml != null) {
      _sendToJs('load', {
        'content': widget.musicXml,
        'options': widget.options.toJson(),
      });
    }
  }

  void _sendToJs(String action, dynamic data) {
    final message = jsonEncode({'action': action, ...data});
    
    if (kIsWeb) {
      _iframe?.contentWindow?.postMessage(message, '*');
    } else if (Platform.isLinux) {
      final script = "handleFlutterMessage('${message.replaceAll("'", "\\'").replaceAll("\n", "\\n")}')";
      _cefController?.executeJavaScript(script);
    } else {
      final script = "handleFlutterMessage('${message.replaceAll("'", "\\'").replaceAll("\n", "\\n")}')";
      _controller?.runJavaScript(script);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildError();
    }

    if (kIsWeb && _viewType != null) {
       return Stack(
          children: [
             HtmlElementView(viewType: _viewType!),
             if (_isLoading || !_isReady) _buildLoading(),
          ]
       );
    }

    if (_htmlContent == null && !kIsWeb) { // Logic for native loading
      if (_controller == null && _cefController == null) {
          return _buildLoading();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isReady) {
          _sendToJs('setWidth', {'width': constraints.maxWidth});
        }

        return Stack(
          children: [
            if (Platform.isLinux)
              cef.WebView(_cefController!)
            else if (!kIsWeb)
              WebViewWidget(controller: _controller!),
            if (_isLoading || !_isReady) _buildLoading(),
          ],
        );
      },
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
            Text('Initializing Verovio engine...'),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: widget.backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Render Error',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
