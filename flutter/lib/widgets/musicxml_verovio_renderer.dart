import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_cef/webview_cef.dart' as cef;

import 'musicxml_web_renderer.dart';

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
  // webview_flutter members
  WebViewController? _controller;
  
  // webview_cef members
  cef.WebViewController? _cefController;
  
  bool _isLoading = true;
  String? _error;
  String? _htmlContent;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _loadHtmlTemplate();
  }

  Future<void> _loadHtmlTemplate() async {
    try {
      _htmlContent = await rootBundle.loadString('assets/html/verovio_template.html');
      if (Platform.isLinux) {
        await _initCefWebView();
      } else {
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
      
      // Wait for manager to be ready
      await cef.WebviewManager().ready;
      
      // Initialize with blank page
      await controller.initialize('about:blank');

      controller.setJavaScriptChannels({
        cef.JavascriptChannel(
          name: 'FlutterChannel',
          onMessageReceived: (message) => _handleJsMessage(message.message),
        ),
      });

      // Load content as data URL since loadHtmlString is missing
      final String contentBase64 = base64Encode(const Utf8Encoder().convert(_htmlContent!));
      await controller.loadUrl('data:text/html;base64,$contentBase64');

      setState(() {
        _cefController = controller;
      });

      // Give it a moment to load and script to execute
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isReady = true;
          });
          _loadContent();
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

  void _handleJsMessage(String message) {
    try {
      final data = jsonDecode(message);
      final action = data['action'];

      switch (action) {
        case 'ready':
          _isReady = true;
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
    final script = "handleFlutterMessage('${message.replaceAll("'", "\\'").replaceAll("\n", "\\n")}')";
    
    if (Platform.isLinux) {
      _cefController?.executeJavaScript(script);
    } else {
      _controller?.runJavaScript(script);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildError();
    }

    if (_htmlContent == null || (_controller == null && _cefController == null)) {
      return _buildLoading();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // When width changes, notify Verovio to reflow
        if (_isReady) {
          _sendToJs('setWidth', {'width': constraints.maxWidth});
        }

        return Stack(
          children: [
            if (Platform.isLinux)
              cef.WebView(_cefController!)
            else
              WebViewWidget(controller: _controller!),
            if (_isLoading) _buildLoading(),
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
