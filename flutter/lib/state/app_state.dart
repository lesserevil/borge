import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/music_library_service.dart';

/// Application state for managing songs and current playback.
class AppState extends ChangeNotifier {
  List<Song> _songs = [];
  List<Song> _assetSongs = [];
  List<Song> _librarySongs = [];
  Song? _currentSong;
  int _currentPageIndex = 0;
  bool _isLoading = false;
  double _zoom = 1.0;

  final MusicLibraryService _musicLibrary = MusicLibraryService();

  /// The music library service for managing folders.
  MusicLibraryService get musicLibrary => _musicLibrary;

  /// Zoom level (1.0 = 100%).
  double get zoom => _zoom;
  set zoom(double value) {
    if (_zoom == value) return;
    _zoom = value;
    notifyListeners();
  }

  /// List of registered music folders.
  List<MusicFolder> get musicFolders => _musicLibrary.folders;

  /// Whether user is signed in to Google Drive
  bool get isDriveSignedIn => _musicLibrary.isDriveSignedIn;

  /// Google Drive user email
  String? get driveUserEmail => _musicLibrary.driveUserEmail;

  /// All available songs.
  List<Song> get songs => List.unmodifiable(_songs);

  /// Currently selected song.
  Song? get currentSong => _currentSong;

  /// Current page index (0-based).
  int get currentPageIndex => _currentPageIndex;

  /// Current page (1-indexed for display).
  int get currentPageNumber => _currentPageIndex + 1;

  /// Current page object.
  Page? get currentPage {
    if (_currentSong == null || _currentSong!.pages.isEmpty) return null;
    if (_currentPageIndex < 0 ||
        _currentPageIndex >= _currentSong!.pages.length) {
      return null;
    }
    return _currentSong!.pages[_currentPageIndex];
  }

  /// Total pages in current song.
  int get totalPages => _currentSong?.pageCount ?? 0;

  /// Whether the app is loading.
  bool get isLoading => _isLoading;

  /// Whether we can go to the previous page.
  bool get canGoPrevious => _currentPageIndex > 0;

  /// Whether we can go to the next page.
  bool get canGoNext =>
      _currentSong != null &&
      _currentPageIndex < _currentSong!.pages.length - 1;

  /// Load songs from a list.
  void loadSongs(List<Song> songs) {
    _songs = songs;
    notifyListeners();
  }

  /// Select a song and reset to the first page.
  void selectSong(Song song) {
    _currentSong = song;
    _currentPageIndex = 0;
    notifyListeners();
  }

  /// Go to the next page.
  void nextPage() {
    if (canGoNext) {
      _currentPageIndex++;
      notifyListeners();
    }
  }

  /// Go to the previous page.
  void previousPage() {
    if (canGoPrevious) {
      _currentPageIndex--;
      notifyListeners();
    }
  }

  /// Go to a specific page (0-indexed).
  void goToPage(int index) {
    if (_currentSong == null) return;
    if (index < 0 || index >= _currentSong!.pages.length) return;
    _currentPageIndex = index;
    notifyListeners();
  }

  /// Clear current song selection.
  void clearSelection() {
    _currentSong = null;
    _currentPageIndex = 0;
    notifyListeners();
  }

  /// Expand the current document into multiple logical pages.
  /// Used for multi-page MusicXML or PDF files identified at runtime.
  void expandDocument(int internalPageCount) {
    final song = _currentSong;
    if (song == null || song.pages.isEmpty) return;
    
    // We only support expanding songs that consist of a single source file.
    // If the song has different paths for different pages, it's a true multi-file song.
    final firstPath = song.pages.first.path;
    final isSingleSource = song.pages.every((p) => p.path == firstPath);
    
    if (!isSingleSource) {
      debugPrint('Song ${song.name} has multiple source files, skipping expansion.');
      return;
    }

    final currentPage = song.pages[0]; // Use the first page as template
    final newPages = <Page>[];
    for (var i = 1; i <= internalPageCount; i++) {
      newPages.add(Page(
        pageNumber: i,
        path: currentPage.path,
        extension: currentPage.extension,
        internalPageNumber: i,
      ));
    }
    
    _currentSong = Song(
      id: song.id,
      name: song.name,
      pages: newPages,
      directoryPath: song.directoryPath,
    );
    
    // Keep current page index within bounds if page count decreased
    if (_currentPageIndex >= internalPageCount) {
      _currentPageIndex = internalPageCount - 1;
    }
    
    debugPrint('Expanded ${song.name} to $internalPageCount pages.');
    
    // Defer notifyListeners with delay to ensure all OSMD operations complete
    Future.delayed(const Duration(milliseconds: 200), () => notifyListeners());
  }

  /// Initialize the app state.
  Future<void> initialize() async {
    await _musicLibrary.initialize();
    await loadAllSongs();
  }

  /// Load songs from all sources (assets + library folders).
  Future<void> loadAllSongs() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load from assets
      _assetSongs = await _loadSongsFromAssets();
      debugPrint('Loaded ${_assetSongs.length} songs from assets');

      // Load from library folders (if on a platform that supports it)
      if (!kIsWeb) {
        _librarySongs = await _musicLibrary.scanFolders();
        debugPrint('Loaded ${_librarySongs.length} songs from library folders');
      }

      // Combine and deduplicate by name
      _songs = _combineSongs(_assetSongs, _librarySongs);
    } catch (e) {
      debugPrint('Error loading songs: $e');
      _songs = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load songs from assets only (for demo/web).
  Future<void> loadDemoSongs() async {
    _isLoading = true;
    notifyListeners();

    try {
      _assetSongs = await _loadSongsFromAssets();
      _songs = _assetSongs;
    } catch (e) {
      debugPrint('Error loading songs from assets: $e');
      _songs = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Rescan library folders for new songs.
  Future<void> rescanLibrary() async {
    if (kIsWeb) return;

    _isLoading = true;
    notifyListeners();

    try {
      _librarySongs = await _musicLibrary.scanFolders();
      _songs = _combineSongs(_assetSongs, _librarySongs);
    } catch (e) {
      debugPrint('Error rescanning library: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add a local music folder and rescan.
  Future<MusicFolder?> addLocalMusicFolder() async {
    final folder = await _musicLibrary.pickAndAddLocalFolder();
    if (folder != null) {
      await rescanLibrary();
    }
    return folder;
  }

  /// Add a Google Drive folder and rescan.
  Future<MusicFolder?> addGoogleDriveFolder(String folderId, String folderName) async {
    final folder = await _musicLibrary.addGoogleDriveFolder(folderId, folderName);
    if (folder != null) {
      await rescanLibrary();
    }
    return folder;
  }

  /// Remove a music folder and rescan.
  Future<void> removeMusicFolder(MusicFolder folder) async {
    await _musicLibrary.removeFolder(folder);
    await rescanLibrary();
  }

  /// Sign in to Google Drive
  Future<bool> signInToGoogleDrive() async {
    final success = await _musicLibrary.signInToGoogleDrive();
    if (success) {
      notifyListeners();
    }
    return success;
  }

  /// Sign out from Google Drive
  Future<void> signOutFromGoogleDrive() async {
    await _musicLibrary.signOutFromGoogleDrive();
    await rescanLibrary();
    notifyListeners();
  }

  /// Sync Google Drive folders
  Future<void> syncGoogleDriveFolders() async {
    await _musicLibrary.syncGoogleDriveFolders();
    await rescanLibrary();
  }

  /// Get Google Drive service for folder picker
  Future<dynamic> getDriveService() => _musicLibrary.getDriveService();

  /// Get Drive cache size
  Future<int> getDriveCacheSize() => _musicLibrary.getDriveCacheSize();

  /// Clear Drive cache
  Future<void> clearDriveCache() async {
    await _musicLibrary.clearDriveCache();
    notifyListeners();
  }

  /// Request storage permission.
  Future<bool> requestStoragePermission() async {
    return await _musicLibrary.requestPermission();
  }

  /// Check if storage permission is granted.
  bool get hasStoragePermission => _musicLibrary.hasPermission;

  /// Combine songs from multiple sources, preferring library over assets.
  List<Song> _combineSongs(List<Song> assets, List<Song> library) {
    final combined = <String, Song>{};

    // Add asset songs first
    for (final song in assets) {
      combined[song.name.toLowerCase()] = song;
    }

    // Library songs override assets with same name
    for (final song in library) {
      combined[song.name.toLowerCase()] = song;
    }

    final result = combined.values.toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// Load songs from the assets/music directory.
  Future<List<Song>> _loadSongsFromAssets() async {
    final songs = <Song>[];

    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final musicAssets = assetManifest.listAssets()
          .where((key) => key.startsWith('assets/music/'))
          .toList();

      debugPrint('Found ${musicAssets.length} music assets: $musicAssets');

      // Filter for MusicXML extensions only
      const musicXmlExtensions = ['.musicxml', '.xml', '.mxl'];
      final filteredAssets = musicAssets.where((asset) {
        final ext = _getFileExtension(asset);
        return musicXmlExtensions.contains(ext);
      }).toList();

      if (filteredAssets.isEmpty) {
        debugPrint('No MusicXML assets found');
        return songs;
      }

      // Group files by directory (song)
      final Map<String, List<String>> songFiles = {};
      for (final asset in filteredAssets) {
        // Extract the song directory name
        // e.g., "assets/music/MySong/page1.png" -> "MySong"
        // e.g., "assets/music/FurElise.musicxml" -> "FurElise"
        final parts = asset.split('/');
        if (parts.length >= 3) {
          final songDir = parts.length > 3
              ? parts[2]
              : _getFileBaseName(parts[2]);
          songFiles.putIfAbsent(songDir, () => []).add(asset);
        }
      }

      // Create Song objects
      for (final entry in songFiles.entries) {
        final songName = entry.key;
        final files = entry.value..sort(); // Sort for consistent page order

        final pages = <Page>[];
        for (var i = 0; i < files.length; i++) {
          final filePath = files[i];
          final ext = _getFileExtension(filePath);
          pages.add(Page(pageNumber: i + 1, path: filePath, extension: ext));
        }

        if (pages.isNotEmpty) {
          songs.add(
            Song(
              id: songName.hashCode.toRadixString(16),
              name: _formatSongName(songName),
              pages: pages,
            ),
          );
        }
      }

      // Sort songs by name
      songs.sort((a, b) => a.name.compareTo(b.name));
    } catch (e, stackTrace) {
      debugPrint('Error parsing asset manifest: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    return songs;
  }

  /// Get file extension including the dot.
  String _getFileExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return '';
    return path.substring(lastDot).toLowerCase();
  }

  /// Get file base name without extension.
  String _getFileBaseName(String path) {
    final lastSlash = path.lastIndexOf('/');
    final fileName = lastSlash == -1 ? path : path.substring(lastSlash + 1);
    final lastDot = fileName.lastIndexOf('.');
    return lastDot == -1 ? fileName : fileName.substring(0, lastDot);
  }

  /// Format song name from directory/file name.
  String _formatSongName(String name) {
    // Replace underscores and hyphens with spaces
    var formatted = name.replaceAll('_', ' ').replaceAll('-', ' ');

    // Capitalize first letter of each word
    formatted = formatted
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');

    return formatted;
  }
}
