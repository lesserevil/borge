// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
/// Web-specific implementation of MusicXML renderer using iframe/HtmlElementView.
///
/// This file uses package:web and dart:js_interop and should only be imported on web platform.
library;

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';

import 'musicxml_types.dart';

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
  final OnAnnotationAdded? onAnnotationAdded;
  final OnAnnotationRemoved? onAnnotationRemoved;
  final OnAnnotationsCleared? onAnnotationsCleared;
  final OnAnnotationModeChanged? onAnnotationModeChanged;
  final OnHistoryChanged? onHistoryChanged;
  final OnAnnotationsConverted? onAnnotationsConverted;

  const MusicXmlWebRendererHtml({
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
    this.onAnnotationsConverted,
  });

  @override
  State<MusicXmlWebRendererHtml> createState() =>
      MusicXmlWebRendererHtmlState();
}

class MusicXmlWebRendererHtmlState extends State<MusicXmlWebRendererHtml> {
  late final String _viewType;
  late final String _frameId;
  web.HTMLIFrameElement? _iframe;
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

    if (oldWidget.options.currentPage != widget.options.currentPage &&
        widget.options.currentPage != null) {
      setPage(widget.options.currentPage!);
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
    _iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..src =
          'osmd_frame.html?frameId=$_frameId&bgColor=${Uri.encodeComponent(bgColorHex)}&v=${DateTime.now().millisecondsSinceEpoch}'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'fullscreen';

    // Register the view factory
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe!,
    );
  }

  void _setupMessageListener() {
    web.window.onMessage.listen((web.MessageEvent event) {
      debugPrint('OSMD message received: ${event.data}');
      _handleMessage(event);
    });
  }

  void _handleMessage(web.MessageEvent event) {
    try {
      final rawData = event.data;
      if (rawData == null) return;

      // In modern interop, data might be a JSObject
      if (!rawData.isA<JSObject>()) return;
      
      final data = Map<String, dynamic>.from(rawData.dartify() as Map);

      // Check if this message is for our frame
      final frameId = data['frameId'];
      if (frameId != _frameId) return;

      final type = data['type'] as String?;
      final payload = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
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

        case 'annotationsConverted':
          if (payload != null && payload['annotations'] != null) {
            final annotations = (payload['annotations'] as List)
                .map((a) => Map<String, dynamic>.from(a as Map))
                .toList();
            widget.onAnnotationsConverted?.call(annotations);
          }
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
    _iframe!.contentWindow!.postMessage(message.jsify(), '*'.toJS);
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

  /// Set the current page in a paginated view.
  void setPage(int page) {
    _sendToIframe('setPage', {'page': page});
  }

  // ── Annotation Control Methods ──────────────────────────────────

  /// Enable or disable annotation drawing mode.
  void setAnnotationMode(bool enabled) {
    _sendToIframe('setAnnotationMode', {'enabled': enabled});
  }

  /// Set the stroke color and width for drawing annotations.
  void setAnnotationStyle({String? color, double? width}) {
    _sendToIframe('setAnnotationStyle', {
      if (color != null) 'color': color,
      if (width != null) 'width': width,
    });
  }

  /// Load previously saved annotations into the renderer.
  void loadAnnotations(List<Map<String, dynamic>> annotations) {
    _sendToIframe('loadAnnotations', {'annotations': annotations});
  }

  /// Clear annotations for a specific page, or all pages if [pageIndex] is null.
  void clearAnnotations({int? pageIndex}) {
    _sendToIframe('clearAnnotations', {'pageIndex': pageIndex});
  }

  /// Remove the last drawn annotation from a specific page.
  void removeLastAnnotation(int pageIndex) {
    _sendToIframe('removeLastAnnotation', {'pageIndex': pageIndex});
  }

  /// Add a structured annotation symbol to a specific page.
  void addStructuredAnnotation({
    required int pageIndex,
    required String kind,
    required int measureNumber,
    required double x,
    required double y,
    Map<String, dynamic>? data,
  }) {
    _sendToIframe('addStructuredAnnotation', {
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
    _sendToIframe('undo');
  }

  /// Redo the last undone annotation action.
  void redo() {
    _sendToIframe('redo');
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
            Icon(Icons.error_outline, size: 48, color: Colors.blueGrey),
            const SizedBox(height: 16),
            Text(
              'Failed to render sheet music',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[700],
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
