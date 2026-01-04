import 'package:flutter/material.dart';

import 'screens/screens.dart';
import 'state/state.dart';

void main() {
  runApp(const BorgeApp());
}

/// Borge - Sheet Music Viewer with Pebble Control
class BorgeApp extends StatefulWidget {
  const BorgeApp({super.key});

  @override
  State<BorgeApp> createState() => _BorgeAppState();
}

class _BorgeAppState extends State<BorgeApp> {
  final AppState _appState = AppState();

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Borge - Sheet Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: SongListScreen(appState: _appState),
    );
  }
}
