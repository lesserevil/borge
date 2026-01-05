/// Platform-adaptive MusicXML renderer.
///
/// This file exports the appropriate renderer for the current platform:
/// - Native (Android, iOS, macOS): Uses WebView-based renderer
/// - Web: Uses iframe/HtmlElementView-based renderer
///
/// Usage:
/// ```dart
/// import 'package:borge/widgets/musicxml_platform_renderer.dart';
///
/// // This automatically uses the right implementation for the platform
/// buildMusicXmlRenderer(
///   musicXml: myXmlContent,
///   onLoaded: (info) => print('Loaded'),
/// )
/// ```
library;

export 'musicxml_web_renderer.dart'
    show
        MusicXmlScoreInfo,
        MusicXmlRenderOptions,
        OnScoreLoaded,
        OnError,
        OnReady;

export 'musicxml_platform_renderer_native.dart'
    if (dart.library.html) 'musicxml_platform_renderer_web.dart';
