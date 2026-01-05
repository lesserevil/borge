import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// Settings screen for managing app configuration and music folders.
class SettingsScreen extends StatelessWidget {
  final AppState appState;

  const SettingsScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          return ListView(
            children: [
              // Music Library Section
              _buildSectionHeader(context, 'Music Library'),
              if (kIsWeb)
                _buildWebOnlyMessage(context)
              else ...[
                _buildPermissionTile(context),
                _buildAddFolderTile(context),
                ..._buildFolderTiles(context),
                if (appState.musicFolders.isEmpty)
                  _buildNoFoldersMessage(context),
              ],

              const Divider(height: 32),

              // About Section
              _buildSectionHeader(context, 'About'),
              _buildAboutTile(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildWebOnlyMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Folder scanning is not available on web. '
                  'Music files are loaded from bundled assets.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile(BuildContext context) {
    final hasPermission = appState.hasStoragePermission;

    return ListTile(
      leading: Icon(
        hasPermission ? Icons.check_circle : Icons.warning,
        color: hasPermission ? Colors.green : Colors.orange,
      ),
      title: const Text('Storage Permission'),
      subtitle: Text(
        hasPermission ? 'Permission granted' : 'Required to scan music folders',
      ),
      trailing: hasPermission
          ? null
          : FilledButton(
              onPressed: () => _requestPermission(context),
              child: const Text('Grant'),
            ),
    );
  }

  Widget _buildAddFolderTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.create_new_folder),
      title: const Text('Add Music Folder'),
      subtitle: const Text('Select a folder containing sheet music'),
      trailing: const Icon(Icons.add),
      onTap: () => _addFolder(context),
    );
  }

  List<Widget> _buildFolderTiles(BuildContext context) {
    return appState.musicFolders.map((folder) {
      // Get just the folder name for display
      final folderName = folder.split('/').last;

      return ListTile(
        leading: const Icon(Icons.folder),
        title: Text(folderName),
        subtitle: Text(
          folder,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _removeFolder(context, folder),
        ),
      );
    }).toList();
  }

  Widget _buildNoFoldersMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.folder_open,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                'No music folders added',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Add a folder to scan for sheet music files',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('Borge Sheet Music Viewer'),
      subtitle: const Text('Version 1.0.0'),
      onTap: () => _showAboutDialog(context),
    );
  }

  Future<void> _requestPermission(BuildContext context) async {
    final granted = await appState.requestStoragePermission();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Storage permission granted'
                : 'Storage permission denied. Please enable in Settings.',
          ),
        ),
      );
    }
  }

  Future<void> _addFolder(BuildContext context) async {
    // Check permission first
    if (!appState.hasStoragePermission) {
      final granted = await appState.requestStoragePermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to add folders'),
            ),
          );
        }
        return;
      }
    }

    final path = await appState.addMusicFolder();

    if (context.mounted) {
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added folder: ${path.split('/').last}')),
        );
      }
    }
  }

  Future<void> _removeFolder(BuildContext context, String folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Folder?'),
        content: Text(
          'Remove "${folder.split('/').last}" from the music library?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await appState.removeMusicFolder(folder);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Folder removed')));
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Borge',
      applicationVersion: '1.0.0',
      applicationLegalese:
          '2024 - Sheet music viewer with hands-free navigation',
      children: [
        const SizedBox(height: 16),
        const Text(
          'A sheet music viewer app designed for musicians who need '
          'hands-free page turning using Pebble smartwatch control.',
        ),
      ],
    );
  }
}
