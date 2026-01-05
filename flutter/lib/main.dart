import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'screens/screens.dart';
import 'state/state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (kIsWeb) {
      // On web, just load demo songs from assets
      await _appState.loadDemoSongs();
    } else {
      // On native platforms, initialize the music library
      await _appState.initialize();
    }
    setState(() {
      _initialized = true;
    });
  }

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
      home: _initialized
          ? SongListScreen(appState: _appState)
          : const _SplashScreen(),
    );
  }
}

/// Splash screen shown while the app initializes.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text('Borge', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Sheet Music Viewer',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
