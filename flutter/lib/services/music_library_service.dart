import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'google_drive/google_drive_auth_service.dart';
import 'google_drive/google_drive_service.dart';
import 'song_repository.dart';

/// Service for managing music library folders and scanning for songs.
///
/// This service handles:
/// - Persisting user-selected music folders (local and Google Drive)
/// - Requesting storage permissions on Android
/// - Scanning folders for music files
/// - Syncing Google Drive folders
/// - Combining songs from multiple sources (assets + file system + cloud)
class MusicLibraryService {
  static const _foldersKey = 'music_library_folders_v2';
  static const _uuid = Uuid();

  final SongRepository _songRepository = SongRepository();
  final GoogleDriveAuthService _driveAuthService = GoogleDriveAuthService();
  GoogleDriveService? _driveService;

  List<MusicFolder> _folders = [];
  bool _permissionGranted = false;

  /// List of user-selected music folders.
  List<MusicFolder> get folders => List.unmodifiable(_folders);

  /// Whether storage permission has been granted.
  bool get hasPermission => _permissionGranted;

  /// Google Drive auth service
  GoogleDriveAuthService get driveAuthService => _driveAuthService;

  /// Whether the user is signed in to Google Drive
  bool get isDriveSignedIn => _driveAuthService.isSignedIn;

  /// Google Drive user email
  String? get driveUserEmail => _driveAuthService.userEmail;

  /// Initialize the service and load saved folders.
  Future<void> initialize() async {
    await _loadSavedFolders();
    await _checkPermission();
    
    // Initialize Google Drive auth
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _driveAuthService.initialize();
      
      if (_driveAuthService.isSignedIn) {
        _driveService = GoogleDriveService(authService: _driveAuthService);
        await _driveService!.initialize();
      }
    }
  }

  /// Load saved folders from shared preferences.
  Future<void> _loadSavedFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final foldersJson = prefs.getStringList(_foldersKey) ?? [];
      
      _folders = foldersJson
          .map((json) {
            try {
              return MusicFolder.fromJson(jsonDecode(json) as Map<String, dynamic>);
            } catch (e) {
              debugPrint('Error parsing folder JSON: $e');
              return null;
            }
          })
          .whereType<MusicFolder>()
          .toList();
      
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
      final foldersJson = _folders
          .map((folder) => jsonEncode(folder.toJson()))
          .toList();
      
      await prefs.setStringList(_foldersKey, foldersJson);
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

  /// Sign in to Google Drive
  Future<bool> signInToGoogleDrive() async {
    final success = await _driveAuthService.signIn();
    
    if (success) {
      _driveService = GoogleDriveService(authService: _driveAuthService);
      await _driveService!.initialize();
    }
    
    return success;
  }

  /// Sign out from Google Drive
  Future<void> signOutFromGoogleDrive() async {
    await _driveAuthService.signOut();
    _driveService = null;
    
    // Remove all Google Drive folders
    _folders.removeWhere((folder) => folder.isGoogleDrive);
    await _saveFolders();
  }

  /// Open a folder picker and add the selected local folder.
  ///
  /// Returns the selected folder, or null if cancelled.
  Future<MusicFolder?> pickAndAddLocalFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Music Folder',
      );

      if (result != null && !_folders.any((f) => f.path == result)) {
        final folder = MusicFolder.local(
          id: _uuid.v4(),
          path: result,
        );
        
        _folders.add(folder);
        await _saveFolders();
        debugPrint('Added local music folder: $result');
        return folder;
      }

      return null;
    } catch (e) {
      debugPrint('Error picking folder: $e');
      return null;
    }
  }

  /// Add a Google Drive folder
  ///
  /// Returns the added folder, or null if operation failed
  Future<MusicFolder?> addGoogleDriveFolder(
    String folderId,
    String folderName,
  ) async {
    if (_driveService == null) {
      debugPrint('Google Drive service not initialized');
      return null;
    }

    try {
      // Check if folder already added
      if (_folders.any((f) => f.driveMetadata?.folderId == folderId)) {
        debugPrint('Folder already added: $folderName');
        return null;
      }

      // Create folder model
      final metadata = GoogleDriveFolderMetadata(
        folderId: folderId,
        folderName: folderName,
        lastSync: DateTime.now(),
        fileCount: 0,
      );

      final folder = MusicFolder.googleDrive(
        id: _uuid.v4(),
        metadata: metadata,
      );

      _folders.add(folder);
      await _saveFolders();
      
      debugPrint('Added Google Drive folder: $folderName');
      return folder;
    } catch (e) {
      debugPrint('Error adding Google Drive folder: $e');
      return null;
    }
  }

  /// Remove a folder from the library.
  Future<void> removeFolder(MusicFolder folder) async {
    _folders.remove(folder);
    await _saveFolders();
    debugPrint('Removed music folder: ${folder.displayName}');
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
        debugPrint('Scanning folder: ${folder.displayName}');
        final songs = await _scanFolder(folder);
        allSongs.addAll(songs);
        debugPrint('Found ${songs.length} songs in ${folder.displayName}');
      } catch (e) {
        debugPrint('Error scanning folder ${folder.displayName}: $e');
        // Continue with other folders
      }
    }

    // Sort all songs by name
    allSongs.sort((a, b) => a.name.compareTo(b.name));

    return allSongs;
  }

  /// Scan a specific folder for songs.
  Future<List<Song>> _scanFolder(MusicFolder folder) async {
    if (folder.isLocal) {
      return await _songRepository.loadFromDirectory(folder.path);
    } else if (folder.isGoogleDrive) {
      return await _scanGoogleDriveFolder(folder);
    }
    
    return [];
  }

  /// Scan a Google Drive folder for songs
  Future<List<Song>> _scanGoogleDriveFolder(MusicFolder folder) async {
    if (_driveService == null || folder.driveMetadata == null) {
      debugPrint('Google Drive service not available');
      return [];
    }

    try {
      // Download all MusicXML files from the folder
      final downloads = await _driveService!.downloadFolderContents(
        folder.driveMetadata!.folderId,
      );

      // Load songs from downloaded files
      final songs = <Song>[];
      for (final localPath in downloads.values) {
        try {
          final song = await _songRepository.loadFromFile(localPath);
          if (song != null) {
            songs.add(song);
          }
        } catch (e) {
          debugPrint('Error loading song from $localPath: $e');
        }
      }

      // Update folder metadata with file count
      final updatedMetadata = folder.driveMetadata!.copyWith(
        fileCount: downloads.length,
        lastSync: DateTime.now(),
      );

      final updatedFolder = folder.copyWith(driveMetadata: updatedMetadata);
      final index = _folders.indexWhere((f) => f.id == folder.id);
      if (index != -1) {
        _folders[index] = updatedFolder;
        await _saveFolders();
      }

      return songs;
    } catch (e) {
      debugPrint('Error scanning Google Drive folder: $e');
      return [];
    }
  }

  /// Sync all Google Drive folders
  Future<void> syncGoogleDriveFolders() async {
    if (_driveService == null) return;

    final driveFolders = _folders.where((f) => f.isGoogleDrive).toList();
    
    for (final folder in driveFolders) {
      try {
        await _scanGoogleDriveFolder(folder);
      } catch (e) {
        debugPrint('Error syncing folder ${folder.displayName}: $e');
      }
    }
  }

  /// Check if a folder exists and is accessible.
  Future<bool> isFolderAccessible(MusicFolder folder) async {
    if (folder.isGoogleDrive) {
      // For Drive folders, check if we have a valid Drive service
      return _driveService != null;
    }

    if (kIsWeb) return false;

    try {
      final dir = Directory(folder.path);
      return await dir.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get Drive service (for external use like folder picker)
  GoogleDriveService? getDriveService() => _driveService;

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

  /// Get Google Drive cache size
  Future<int> getDriveCacheSize() async {
    if (_driveService == null) return 0;
    return await _driveService!.getCacheSize();
  }

  /// Clear Google Drive cache
  Future<void> clearDriveCache() async {
    if (_driveService == null) return;
    await _driveService!.clearCache();
  }
}
