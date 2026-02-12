/// Native platform implementation of platform-adaptive MusicXML renderer.
///
/// This file is used on Android, iOS, macOS, Windows, and Linux.
/// It uses the OSMD-based renderer.
library;

import 'package:flutter/material.dart';
import 'musicxml_types.dart';
import 'musicxml_web_renderer.dart';

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
  OnAnnotationsConverted? onAnnotationsConverted,
  bool annotationMode = false,
}) {
  return MusicXmlWebRenderer(
    key: key,
    musicXml: musicXml,
    musicXmlUrl: musicXmlUrl,
    options: options,
    backgroundColor: backgroundColor,
    onLoaded: onLoaded,
    onError: onError,
    onReady: onReady,
    onAnnotationAdded: onAnnotationAdded,
    onAnnotationRemoved: onAnnotationRemoved,
    onAnnotationsCleared: onAnnotationsCleared,
    onAnnotationModeChanged: onAnnotationModeChanged,
    onHistoryChanged: onHistoryChanged,
    onAnnotationsConverted: onAnnotationsConverted,
    annotationMode: annotationMode,
  );
}
