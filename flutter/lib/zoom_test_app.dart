import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_cef/webview_cef.dart';

import 'widgets/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb && Platform.isLinux) {
    await WebviewManager().initialize();
  }
  
  runApp(const ZoomTestApp());
}

class ZoomTestApp extends StatelessWidget {
  const ZoomTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSMD Zoom Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ZoomTestHomeScreen(),
    );
  }
}

class ZoomTestHomeScreen extends StatefulWidget {
  const ZoomTestHomeScreen({super.key});

  @override
  State<ZoomTestHomeScreen> createState() => _ZoomTestHomeScreenState();
}

class _ZoomTestHomeScreenState extends State<ZoomTestHomeScreen> {
  double _zoom = 1.0;
  String? _musicXml;
  bool _loading = true;
  int _pageCount = 0;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadTestData();
  }

  Future<void> _loadTestData() async {
    try {
      final data = await rootBundle.loadString('assets/music/Echigo-Jishi.musicxml');
      setState(() {
        _musicXml = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading test musicxml: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  void _adjustZoom(double delta) {
    setState(() {
      _zoom = (_zoom + delta).clamp(0.2, 4.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OSMD Zoom Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          _zoomButton('50%', 0.5),
          _zoomButton('100%', 1.0),
          _zoomButton('150%', 1.5),
          _zoomButton('200%', 2.0),
          const VerticalDivider(),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () => _adjustZoom(-0.1),
          ),
          Center(
            child: Text(
              '${(_zoom * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _adjustZoom(0.1),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _musicXml == null
              ? const Center(child: Text('Failed to load test MusicXML'))
              : Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: buildMusicXmlRenderer(
                          musicXml: _musicXml,
                          options: MusicXmlRenderOptions(
                            zoom: _zoom,
                            currentPage: _currentPage,
                          ),
                          onLoaded: (info) {
                            debugPrint('Score loaded: ${info.pageCount} pages');
                            setState(() {
                              _pageCount = info.pageCount;
                              if (_currentPage > _pageCount && _pageCount > 0) {
                                _currentPage = _pageCount;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        child: Row(
                          children: [
                            const Icon(Icons.pages_outlined),
                            const SizedBox(width: 8),
                            Text(
                              'Page $_currentPage of $_pageCount',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _currentPage > 1
                                  ? () => setState(() => _currentPage--)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _currentPage < _pageCount
                                  ? () => setState(() => _currentPage++)
                                  : null,
                            ),
                            const Spacer(),
                            Text(
                              'Zoom: ${(_zoom * 100).toInt()}%',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _zoomButton(String label, double value) {
    return TextButton(
      onPressed: () => setState(() => _zoom = value),
      child: Text(label),
    );
  }
}
