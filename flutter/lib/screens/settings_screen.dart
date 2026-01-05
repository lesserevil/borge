import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/nearby_connections_service.dart';
import '../services/remote_control_service.dart';
import '../state/app_state.dart';

/// Settings screen for managing app configuration and music folders.
class SettingsScreen extends StatelessWidget {
  final AppState appState;
  final RemoteControlService? remoteControlService;

  const SettingsScreen({
    super.key,
    required this.appState,
    this.remoteControlService,
  });

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

              // Remote Control Section (Android only)
              if (!kIsWeb &&
                  Platform.isAndroid &&
                  remoteControlService != null) ...[
                _buildSectionHeader(context, 'Remote Control'),
                _buildRemoteControlSection(context),
                const Divider(height: 32),
              ],

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

  Widget _buildRemoteControlSection(BuildContext context) {
    final service = remoteControlService!;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        return Column(
          children: [
            // Mode selection
            ListTile(
              leading: Icon(
                service.isEnabled
                    ? Icons.wifi_tethering
                    : Icons.wifi_tethering_off,
                color: service.isEnabled ? Colors.green : null,
              ),
              title: const Text('Remote Control'),
              subtitle: Text(_getModeDescription(service)),
              trailing: service.isEnabled
                  ? TextButton(
                      onPressed: () => service.disable(),
                      child: const Text('Disable'),
                    )
                  : null,
            ),

            // Mode buttons when not enabled
            if (!service.isEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _enableViewerMode(context),
                        icon: const Icon(Icons.tablet),
                        label: const Text('Viewer Mode'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _enableRelayMode(context),
                        icon: const Icon(Icons.phone_android),
                        label: const Text('Relay Mode'),
                      ),
                    ),
                  ],
                ),
              ),

            // Connection status when enabled
            if (service.isEnabled) ...[
              ListTile(
                leading: Icon(
                  _getConnectionIcon(service.connectionState),
                  color: _getConnectionColor(service.connectionState),
                ),
                title: Text(_getConnectionStatusText(service)),
                subtitle: service.isConnected
                    ? Text(
                        '${service.connectedEndpoints.length} device(s) connected',
                      )
                    : null,
              ),

              // Show discovered devices in relay mode
              if (service.mode == RemoteControlMode.relay)
                ..._buildDiscoveredDevicesList(context, service),
            ],

            // Error display
            if (service.lastError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            service.lastError!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Help text
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How it works:',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Viewer Mode: Use on a tablet to display sheet music. '
                        'The tablet will accept page turn commands from connected devices.',
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Relay Mode: Use on a phone to relay Pebble watch commands '
                        'to a tablet running in Viewer mode.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildDiscoveredDevicesList(
    BuildContext context,
    RemoteControlService service,
  ) {
    if (service.discoveredViewers.isEmpty) {
      return [
        const ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Searching for viewers...'),
          subtitle: Text('Make sure the tablet is in Viewer mode'),
        ),
      ];
    }

    return service.discoveredViewers.map((endpoint) {
      final isConnecting =
          service.connectionState == NearbyConnectionState.connecting;
      final isConnected = service.connectedEndpoints.any(
        (e) => e.id == endpoint.id,
      );

      return ListTile(
        leading: Icon(
          isConnected ? Icons.tablet : Icons.tablet_android,
          color: isConnected ? Colors.green : null,
        ),
        title: Text(endpoint.name),
        subtitle: Text(isConnected ? 'Connected' : 'Tap to connect'),
        trailing: isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isConnected
            ? IconButton(
                icon: const Icon(Icons.link_off),
                onPressed: () => service.disconnectFromViewer(endpoint.id),
              )
            : const Icon(Icons.chevron_right),
        onTap: isConnected || isConnecting
            ? null
            : () => _connectToViewer(context, endpoint.id),
      );
    }).toList();
  }

  String _getModeDescription(RemoteControlService service) {
    if (!service.isEnabled) {
      return 'Control sheet music remotely via Pebble watch';
    }
    switch (service.mode) {
      case RemoteControlMode.standalone:
        return 'Disabled';
      case RemoteControlMode.viewer:
        return 'Viewer mode - accepting remote commands';
      case RemoteControlMode.relay:
        return 'Relay mode - forwarding Pebble commands';
    }
  }

  IconData _getConnectionIcon(NearbyConnectionState state) {
    switch (state) {
      case NearbyConnectionState.disconnected:
        return Icons.wifi_off;
      case NearbyConnectionState.advertising:
        return Icons.wifi_tethering;
      case NearbyConnectionState.discovering:
        return Icons.wifi_find;
      case NearbyConnectionState.connecting:
        return Icons.sync;
      case NearbyConnectionState.connected:
        return Icons.wifi;
    }
  }

  Color _getConnectionColor(NearbyConnectionState state) {
    switch (state) {
      case NearbyConnectionState.disconnected:
        return Colors.grey;
      case NearbyConnectionState.advertising:
      case NearbyConnectionState.discovering:
        return Colors.orange;
      case NearbyConnectionState.connecting:
        return Colors.blue;
      case NearbyConnectionState.connected:
        return Colors.green;
    }
  }

  String _getConnectionStatusText(RemoteControlService service) {
    switch (service.connectionState) {
      case NearbyConnectionState.disconnected:
        return 'Disconnected';
      case NearbyConnectionState.advertising:
        return 'Advertising as "${service.deviceName}"';
      case NearbyConnectionState.discovering:
        return 'Searching for viewers...';
      case NearbyConnectionState.connecting:
        return 'Connecting...';
      case NearbyConnectionState.connected:
        return 'Connected';
    }
  }

  Future<void> _enableViewerMode(BuildContext context) async {
    final service = remoteControlService!;
    final success = await service.enableViewerMode();

    if (context.mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.lastError ?? 'Failed to enable viewer mode'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _enableRelayMode(BuildContext context) async {
    final service = remoteControlService!;
    final success = await service.enableRelayMode();

    if (context.mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.lastError ?? 'Failed to enable relay mode'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _connectToViewer(BuildContext context, String endpointId) async {
    final service = remoteControlService!;
    final success = await service.connectToViewer(endpointId);

    if (context.mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to viewer')),
      );
    }
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
