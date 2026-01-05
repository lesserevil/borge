// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
/// Web-specific implementation of MusicXML renderer using iframe/HtmlElementView.
///
/// This file uses dart:html and should only be imported on web platform.
library;

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'musicxml_web_renderer.dart';

/// Unique ID counter for iframe registration.
int _iframeCounter = 0;

/// Web-specific implementation of MusicXmlWebRenderer using an iframe.
///
/// This widget embeds the OSMD HTML page in an iframe and communicates
/// with it via postMessage.
class MusicXmlWebRendererHtml extends StatefulWidget {
  final String? musicXml;
  final String? musicXmlUrl;
  final MusicXmlRenderOptions options;
  final Color backgroundColor;
  final OnScoreLoaded? onLoaded;
  final OnError? onError;
  final OnReady? onReady;

  const MusicXmlWebRendererHtml({
    super.key,
    this.musicXml,
    this.musicXmlUrl,
    this.options = const MusicXmlRenderOptions(),
    this.backgroundColor = Colors.white,
    this.onLoaded,
    this.onError,
    this.onReady,
  });

  @override
  State<MusicXmlWebRendererHtml> createState() =>
      MusicXmlWebRendererHtmlState();
}

class MusicXmlWebRendererHtmlState extends State<MusicXmlWebRendererHtml> {
  late final String _viewType;
  late final String _frameId;
  html.IFrameElement? _iframe;
  bool _isReady = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _frameId = 'osmd-frame-${_iframeCounter++}';
    _viewType = 'osmd-iframe-$_frameId';
    _registerView();
    _setupMessageListener();
  }

  @override
  void didUpdateWidget(MusicXmlWebRendererHtml oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.musicXml != widget.musicXml ||
        oldWidget.musicXmlUrl != widget.musicXmlUrl) {
      _loadContent();
    }

    if (oldWidget.options.zoom != widget.options.zoom) {
      setZoom(widget.options.zoom);
    }
  }

  @override
  void dispose() {
    _iframe = null;
    super.dispose();
  }

  void _registerView() {
    // Convert background color to CSS hex
    final bgColorHex =
        '#${widget.backgroundColor.value.toRadixString(16).substring(2)}';

    // Create the iframe element
    _iframe = html.IFrameElement()
      ..src =
          'osmd_frame.html?frameId=$_frameId&bgColor=${Uri.encodeComponent(bgColorHex)}'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'fullscreen';

    // Register the view factory
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe!,
    );
  }

  void _setupMessageListener() {
    html.window.onMessage.listen((event) {
      debugPrint('OSMD message received: ${event.data}');
      _handleMessage(event);
    });
  }

  void _handleMessage(html.MessageEvent event) {
    try {
      final rawData = event.data;
      if (rawData == null) return;

      // Convert JS object to Dart Map if needed
      Map<String, dynamic> data;
      if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else {
        // Not a map, ignore
        return;
      }

      // Check if this message is for our frame
      final frameId = data['frameId'];
      if (frameId != _frameId) return;

      final type = data['type'] as String?;
      final payloadRaw = data['data'];
      final payload = payloadRaw is Map
          ? Map<String, dynamic>.from(payloadRaw)
          : null;

      switch (type) {
        case 'ready':
          setState(() {
            _isReady = true;
            _isLoading = false;
          });
          widget.onReady?.call();
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
      debugPrint('Error handling iframe message: $e');
    }
  }

  void _sendToIframe(String action, [dynamic payload]) {
    if (_iframe?.contentWindow == null) {
      debugPrint('OSMD: Cannot send message, iframe not ready');
      return;
    }

    final message = {
      'action': action,
      'payload': payload,
      'targetFrameId': _frameId,
    };

    debugPrint('OSMD: Sending to iframe: $action');
    _iframe!.contentWindow!.postMessage(message, '*');
  }

  void _loadContent() {
    if (!_isReady) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (widget.musicXml != null) {
      _sendToIframe('load', {'xml': widget.musicXml});
    } else if (widget.musicXmlUrl != null) {
      _sendToIframe('loadUrl', {'url': widget.musicXmlUrl});
    }
  }

  /// Reload the current content.
  void reload() {
    _loadContent();
  }

  /// Set the zoom level (1.0 = 100%).
  void setZoom(double zoom) {
    _sendToIframe('setZoom', {'zoom': zoom});
  }

  /// Navigate to a specific measure.
  void goToMeasure(int measureNumber) {
    _sendToIframe('goToMeasure', {'measure': measureNumber});
  }

  /// Clear the rendered content.
  void clear() {
    _sendToIframe('clear');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HtmlElementView(viewType: _viewType),
        if (_isLoading) _buildLoading(),
        if (_error != null) _buildError(),
      ],
    );
  }

  Widget _buildLoading() {
    return Container(
      color: widget.backgroundColor.withOpacity(0.9),
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
}
