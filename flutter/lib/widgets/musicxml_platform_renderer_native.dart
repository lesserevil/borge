/// Native platform implementation of platform-adaptive MusicXML renderer.
///
/// This file is used on Android, iOS, macOS, Windows, and Linux.
/// It uses the WebView-based renderer.
library;

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'musicxml_renderer.dart';
import 'musicxml_web_renderer.dart';
import 'musicxml_mscore_renderer.dart';
import 'musicxml_verovio_renderer.dart';

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
}) {
  // For Linux and Android, use the high-quality Verovio renderer for reflow
  if ((Platform.isLinux || Platform.isAndroid) && musicXml != null) {
    return MusicXmlVerovioRenderer(
      key: key,
      musicXml: musicXml,
      options: options,
      backgroundColor: backgroundColor,
      onLoaded: onLoaded,
      onError: onError,
    );
  }

  // Fallback to OSMD Web Renderer for other platforms
  return MusicXmlWebRenderer(
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
