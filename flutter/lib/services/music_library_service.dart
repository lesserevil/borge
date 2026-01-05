import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'song_repository.dart';

/// Service for managing music library folders and scanning for songs.
///
/// This service handles:
/// - Persisting user-selected music folders
/// - Requesting storage permissions on Android
/// - Scanning folders for music files
/// - Combining songs from multiple sources (assets + file system)
class MusicLibraryService {
  static const _foldersKey = 'music_library_folders';

  final SongRepository _songRepository = SongRepository();

  List<String> _folders = [];
  bool _permissionGranted = false;

  /// List of user-selected music folders.
  List<String> get folders => List.unmodifiable(_folders);

  /// Whether storage permission has been granted.
  bool get hasPermission => _permissionGranted;

  /// Initialize the service and load saved folders.
  Future<void> initialize() async {
    await _loadSavedFolders();
    await _checkPermission();
  }

  /// Load saved folders from shared preferences.
  Future<void> _loadSavedFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _folders = prefs.getStringList(_foldersKey) ?? [];
      debugPrint('Loaded ${_folders.length} saved music folders');
    } catch (e) {
      debugPrint('Error loading saved folders: $e');
      _folders = [];
    }
  }

  /// Save folders to shared preferences.
  Future<void> _saveFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_foldersKey, _folders);
    } catch (e) {
      debugPrint('Error saving folders: $e');
    }
  }

  /// Check if storage permission is granted.
  Future<void> _checkPermission() async {
    if (kIsWeb) {
      _permissionGranted = true;
      return;
    }

    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we need different permissions
      // For older versions, we need storage permission
      final status = await Permission.manageExternalStorage.status;
      _permissionGranted = status.isGranted;

      if (!_permissionGranted) {
        // Try regular storage permission as fallback
        final storageStatus = await Permission.storage.status;
        _permissionGranted = storageStatus.isGranted;
      }
    } else if (Platform.isIOS || Platform.isMacOS) {
      // iOS/macOS use file picker which handles permissions internally
      _permissionGranted = true;
    } else {
      // Linux/Windows don't need special permissions
      _permissionGranted = true;
    }
  }

  /// Request storage permission.
  ///
  /// Returns true if permission is granted.
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      _permissionGranted = true;
      return true;
    }

    if (Platform.isAndroid) {
      // Try manage external storage first (for full access)
      var status = await Permission.manageExternalStorage.request();

      if (!status.isGranted) {
        // Fall back to regular storage permission
        status = await Permission.storage.request();
      }

      _permissionGranted = status.isGranted;

      if (status.isPermanentlyDenied) {
        // Open app settings so user can grant permission manually
        await openAppSettings();
      }

      return _permissionGranted;
    }

    _permissionGranted = true;
    return true;
  }

  /// Open a folder picker and add the selected folder.
  ///
  /// Returns the selected folder path, or null if cancelled.
  Future<String?> pickAndAddFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Music Folder',
      );

      if (result != null && !_folders.contains(result)) {
        _folders.add(result);
        await _saveFolders();
        debugPrint('Added music folder: $result');
      }

      return result;
    } catch (e) {
      debugPrint('Error picking folder: $e');
      return null;
    }
  }

  /// Remove a folder from the library.
  Future<void> removeFolder(String path) async {
    _folders.remove(path);
    await _saveFolders();
    debugPrint('Removed music folder: $path');
  }

  /// Clear all folders.
  Future<void> clearFolders() async {
    _folders.clear();
    await _saveFolders();
  }

  /// Scan all registered folders for songs.
  ///
  /// Returns a list of songs found in all folders.
  Future<List<Song>> scanFolders() async {
    if (_folders.isEmpty) {
      debugPrint('No music folders configured');
      return [];
    }

    final allSongs = <Song>[];

    for (final folder in _folders) {
      try {
        debugPrint('Scanning folder: $folder');
        final songs = await _songRepository.loadFromDirectory(folder);
        allSongs.addAll(songs);
        debugPrint('Found ${songs.length} songs in $folder');
      } catch (e) {
        debugPrint('Error scanning folder $folder: $e');
        // Continue with other folders
      }
    }

    // Sort all songs by name
    allSongs.sort((a, b) => a.name.compareTo(b.name));

    return allSongs;
  }

  /// Scan a specific folder for songs.
  Future<List<Song>> scanFolder(String path) async {
    try {
      return await _songRepository.loadFromDirectory(path);
    } catch (e) {
      debugPrint('Error scanning folder $path: $e');
      return [];
    }
  }

  /// Check if a folder exists and is accessible.
  Future<bool> isFolderAccessible(String path) async {
    if (kIsWeb) return false;

    try {
      final dir = Directory(path);
      return await dir.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get suggested music folder paths for the current platform.
  List<String> getSuggestedFolders() {
    if (kIsWeb) return [];

    if (Platform.isAndroid) {
      return [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Music/SheetMusic',
      ];
    } else if (Platform.isIOS) {
      return []; // iOS uses document picker
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return ['$home/Music', '$home/Documents', '$home/Downloads'];
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      return ['$home/Music', '$home/Documents', '$home/Downloads'];
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      return [
        '$userProfile\\Music',
        '$userProfile\\Documents',
        '$userProfile\\Downloads',
      ];
    }

    return [];
  }
}
