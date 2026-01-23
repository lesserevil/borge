import 'package:flutter/material.dart';

import '../services/google_drive/google_drive_service.dart';

/// Dialog for browsing and selecting Google Drive folders
class GoogleDriveFolderPickerDialog extends StatefulWidget {
  final GoogleDriveService driveService;

  const GoogleDriveFolderPickerDialog({
    super.key,
    required this.driveService,
  });

  @override
  State<GoogleDriveFolderPickerDialog> createState() =>
      _GoogleDriveFolderPickerDialogState();
}

class _GoogleDriveFolderPickerDialogState
    extends State<GoogleDriveFolderPickerDialog> {
  final List<_BreadcrumbItem> _breadcrumbs = [];
  List<DriveItem> _currentFolders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRootFolders();
  }

  Future<void> _loadRootFolders() async {
    setState(() {
      _loading = true;
      _error = null;
      _breadcrumbs.clear();
    });

    try {
      final folders = await widget.driveService.listFolders();
      setState(() {
        _currentFolders = folders;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load folders: $e';
        _loading = false;
      });
    }
  }

  Future<void> _navigateToFolder(DriveItem folder) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final folders = await widget.driveService.listFolders(
        parentId: folder.id,
      );

      setState(() {
        _breadcrumbs.add(_BreadcrumbItem(
          id: folder.id,
          name: folder.name,
        ));
        _currentFolders = folders;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load folder: $e';
        _loading = false;
      });
    }
  }

  Future<void> _navigateToBreadcrumb(int index) async {
    if (index == -1) {
      // Go to root
      await _loadRootFolders();
      return;
    }

    final breadcrumb = _breadcrumbs[index];
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final folders = await widget.driveService.listFolders(
        parentId: breadcrumb.id,
      );

      setState(() {
        _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
        _currentFolders = folders;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load folder: $e';
        _loading = false;
      });
    }
  }

  void _selectCurrentFolder() {
    if (_breadcrumbs.isEmpty) {
      // Can't select root
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a specific folder, not the root'),
        ),
      );
      return;
    }

    final selectedFolder = _breadcrumbs.last;
    Navigator.of(context).pop(selectedFolder);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title and close button
            Row(
              children: [
                const Icon(Icons.folder, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Select Google Drive Folder',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),

            // Breadcrumbs
            if (_breadcrumbs.isNotEmpty) ...[
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildBreadcrumb('My Drive', -1),
                    for (int i = 0; i < _breadcrumbs.length; i++) ...[
                      const Icon(Icons.chevron_right, color: Colors.grey),
                      _buildBreadcrumb(_breadcrumbs[i].name, i),
                    ],
                  ],
                ),
              ),
              const Divider(),
            ],

            // Folder list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                onPressed: _breadcrumbs.isEmpty
                                    ? _loadRootFolders
                                    : () => _navigateToBreadcrumb(
                                        _breadcrumbs.length - 1),
                              ),
                            ],
                          ),
                        )
                      : _currentFolders.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.folder_open,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No folders found',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _currentFolders.length,
                              itemBuilder: (context, index) {
                                final folder = _currentFolders[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.folder,
                                    color: Colors.blue,
                                  ),
                                  title: Text(folder.name),
                                  subtitle: folder.modifiedTime != null
                                      ? Text(
                                          'Modified: ${_formatDate(folder.modifiedTime!)}',
                                          style: const TextStyle(fontSize: 12),
                                        )
                                      : null,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _navigateToFolder(folder),
                                );
                              },
                            ),
            ),

            const Divider(),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Select This Folder'),
                  onPressed: _breadcrumbs.isEmpty ? null : _selectCurrentFolder,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(String label, int index) {
    final isLast = index == _breadcrumbs.length - 1;
    return TextButton(
      onPressed: isLast ? null : () => _navigateToBreadcrumb(index),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
          color: isLast ? Theme.of(context).primaryColor : Colors.blue,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _BreadcrumbItem {
  final String id;
  final String name;

  _BreadcrumbItem({required this.id, required this.name});
}
