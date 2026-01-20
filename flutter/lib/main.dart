import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'screens/screens.dart';
import 'services/remote_control_service.dart';
import 'services/rest_api_controller.dart';
import 'services/song_navigation_controller.dart';
import 'services/song_repository.dart';
import 'state/state.dart';

import 'package:webview_cef/webview_cef.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isLinux) {
    await WebviewManager().initialize();
  }
  
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
  RemoteControlService? _remoteControlService;
  RestApiController? _restApiController;
  SongNavigationController? _songNavigationController;
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

      // Initialize remote control service on Android
      if (Platform.isAndroid) {
        _remoteControlService = RemoteControlService(appState: _appState);
        // Set device name based on device model (could be customized in settings)
        _remoteControlService!.setDeviceName('Borge Viewer');
      }

      // Initialize song navigation controller
      _songNavigationController = SongNavigationController(appState: _appState, port: 3001);
      await _songNavigationController!.start();

      // Initialize REST API controller on native platforms
      if (!kIsWeb) {
        // Create a SongRepository instance to use with the REST API
        final songRepository = SongRepository();
        _restApiController = RestApiController(
          songRepository: songRepository,
          appState: _appState,
        );
        await _restApiController!.start();
      }
    }
    setState(() {
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _remoteControlService?.dispose();
    _restApiController?.stop();
    _songNavigationController?.stop();
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
          ? SongListScreen(
              appState: _appState,
              remoteControlService: _remoteControlService,
            )
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
