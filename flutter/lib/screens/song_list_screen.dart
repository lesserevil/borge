import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import 'sheet_music_viewer_screen.dart';

/// Screen displaying a list of available songs.
class SongListScreen extends StatelessWidget {
  final AppState appState;

  const SongListScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sheet Music'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Scan for music',
            onPressed: () => _scanForMusic(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          if (appState.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for sheet music...'),
                ],
              ),
            );
          }

          if (appState.songs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sheet music found',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the refresh button to scan for music',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _loadDemoSongs(context),
                    icon: const Icon(Icons.library_music),
                    label: const Text('Load Demo Songs'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: appState.songs.length,
            itemBuilder: (context, index) {
              final song = appState.songs[index];
              return _SongListTile(
                song: song,
                onTap: () => _openSong(context, song),
              );
            },
          );
        },
      ),
    );
  }

  void _scanForMusic(BuildContext context) {
    // For now, just load demo songs since we're in browser
    _loadDemoSongs(context);
  }

  void _loadDemoSongs(BuildContext context) {
    appState.loadDemoSongs();
  }

  void _openSong(BuildContext context, Song song) {
    appState.selectSong(song);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SheetMusicViewerScreen(appState: appState),
      ),
    );
  }
}

/// A list tile for displaying a song.
class _SongListTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SongListTile({
    required this.song,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.music_note,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        song.name,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        '${song.pageCount} ${song.pageCount == 1 ? 'page' : 'pages'}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
