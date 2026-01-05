/// Native platform implementation of platform-adaptive MusicXML renderer.
///
/// This file is used on Android, iOS, macOS, Windows, and Linux.
/// It uses the WebView-based renderer.
library;

import 'package:flutter/material.dart';

import 'musicxml_web_renderer.dart';

/// Builds a MusicXML renderer appropriate for the current platform.
///
/// On native platforms, this returns a [MusicXmlWebRenderer] which uses WebView.
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
