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

  final MusicLibraryService _musicLibrary = MusicLibraryService();

  /// The music library service for managing folders.
  MusicLibraryService get musicLibrary => _musicLibrary;

  /// List of registered music folders.
  List<String> get musicFolders => _musicLibrary.folders;

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

  /// Add a music folder and rescan.
  Future<String?> addMusicFolder() async {
    final path = await _musicLibrary.pickAndAddFolder();
    if (path != null) {
      await rescanLibrary();
    }
    return path;
  }

  /// Remove a music folder and rescan.
  Future<void> removeMusicFolder(String path) async {
    await _musicLibrary.removeFolder(path);
    await rescanLibrary();
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
      // Use Flutter's AssetManifest which handles both old and new formats
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = assetManifest.listAssets();

      // Find all files in assets/music/
      final musicAssets = allAssets
          .where((key) => key.startsWith('assets/music/'))
          .toList();

      if (musicAssets.isEmpty) {
        debugPrint('No music assets found in assets/music/');
        return songs;
      }

      debugPrint('Found ${musicAssets.length} music assets: $musicAssets');

      // Group files by directory (song)
      final Map<String, List<String>> songFiles = {};
      for (final asset in musicAssets) {
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
