/// Web platform implementation of platform-adaptive MusicXML renderer.
///
/// This file is used on Flutter Web.
/// It uses the iframe/HtmlElementView-based renderer (OSMD).
library;

import 'package:flutter/material.dart';

import 'musicxml_types.dart';
import 'musicxml_web_renderer_html.dart';

/// Builds a MusicXML renderer appropriate for the current platform.
///
Widget buildMusicXmlRenderer({
  Key? key,
  String? musicXml,
  String? musicXmlUrl,
  MusicXmlRenderOptions options = const MusicXmlRenderOptions(),
  Color backgroundColor = Colors.white,
  OnScoreLoaded? onLoaded,
  OnError? onError,
  OnReady? onReady,
  OnAnnotationAdded? onAnnotationAdded,
  OnAnnotationRemoved? onAnnotationRemoved,
  OnAnnotationsCleared? onAnnotationsCleared,
  OnAnnotationModeChanged? onAnnotationModeChanged,
  OnHistoryChanged? onHistoryChanged,
}) {
  return MusicXmlWebRendererHtml(
    key: key,
    musicXml: musicXml,
    musicXmlUrl: musicXmlUrl,
    options: options,
    backgroundColor: backgroundColor,
    onLoaded: onLoaded,
    onError: onError,
    onReady: onReady,
  );
}
