import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/models.dart';
import 'file_scanner_service.dart';

/// Repository for managing songs derived from scanned sheet music files.
class SongRepository {
  final FileScannerService _fileScanner;

  /// Current list of songs.
  List<Song> _songs = [];

  /// Gets the current list of songs.
  List<Song> get songs => List.unmodifiable(_songs);

  SongRepository({FileScannerService? fileScanner})
      : _fileScanner = fileScanner ?? FileScannerService();

  /// Scans a directory and builds the song list.
  ///
  /// Files are grouped into songs based on their parent directory.
  /// Files in the same directory are treated as pages of the same song.
  Future<List<Song>> loadFromDirectory(String path) async {
    final files = await _fileScanner.scanDirectory(path);
    _songs = _groupFilesIntoSongs(files);
    return _songs;
  }

  /// Synchronous version of loadFromDirectory.
  List<Song> loadFromDirectorySync(String path) {
    final files = _fileScanner.scanDirectorySync(path);
    _songs = _groupFilesIntoSongs(files);
    return _songs;
  }

  /// Gets a song by ID.
  Song? getSongById(String id) {
    try {
      return _songs.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Gets the JSON representation of all songs.
  Map<String, dynamic> toJson() => {
        'songs': _songs.map((s) => s.toJson()).toList(),
      };

  /// Gets the JSON string representation of all songs.
  String toJsonString() => jsonEncode(toJson());

  /// Groups files into songs based on directory structure.
  List<Song> _groupFilesIntoSongs(List<SheetMusicFile> files) {
    // Group files by their parent directory
    final Map<String, List<SheetMusicFile>> filesByDirectory = {};

    for (final file in files) {
      final dirPath = _getParentDirectory(file.path);
      filesByDirectory.putIfAbsent(dirPath, () => []).add(file);
    }

    // Convert each group into a Song
    final songs = <Song>[];
    for (final entry in filesByDirectory.entries) {
      final dirPath = entry.key;
      final dirFiles = entry.value;

      // Sort files by name to determine page order
      dirFiles.sort((a, b) => _naturalCompare(a.name, b.name));

      // Generate a stable ID from the directory path
      final id = _generateId(dirPath);

      // Use the directory name as the song name
      final name = _getDirectoryName(dirPath);

      // Create pages from files
      final pages = <Page>[];
      for (var i = 0; i < dirFiles.length; i++) {
        final file = dirFiles[i];
        pages.add(Page(
          pageNumber: i + 1,
          path: file.path,
          extension: file.extension,
        ));
      }

      songs.add(Song(
        id: id,
        name: name,
        pages: pages,
        directoryPath: dirPath,
      ));
    }

    // Sort songs by name
    songs.sort((a, b) => _naturalCompare(a.name, b.name));
    return songs;
  }

  /// Gets the parent directory path from a file path.
  String _getParentDirectory(String filePath) {
    final lastSeparator = filePath.lastIndexOf('/');
    if (lastSeparator == -1) {
      return '.';
    }
    return filePath.substring(0, lastSeparator);
  }

  /// Gets the directory name from a path.
  String _getDirectoryName(String dirPath) {
    final lastSeparator = dirPath.lastIndexOf('/');
    if (lastSeparator == -1) {
      return dirPath;
    }
    return dirPath.substring(lastSeparator + 1);
  }

  /// Generates a stable ID from a string.
  String _generateId(String input) {
    final bytes = utf8.encode(input);
    final hash = md5.convert(bytes);
    return hash.toString().substring(0, 8);
  }

  /// Natural string comparison (handles numbers correctly).
  int _naturalCompare(String a, String b) {
    final aLower = a.toLowerCase();
    final bLower = b.toLowerCase();

    final regex = RegExp(r'(\d+)|(\D+)');
    final aParts = regex.allMatches(aLower).map((m) => m.group(0)!).toList();
    final bParts = regex.allMatches(bLower).map((m) => m.group(0)!).toList();

    for (var i = 0; i < aParts.length && i < bParts.length; i++) {
      final aPart = aParts[i];
      final bPart = bParts[i];

      final aNum = int.tryParse(aPart);
      final bNum = int.tryParse(bPart);

      int cmp;
      if (aNum != null && bNum != null) {
        cmp = aNum.compareTo(bNum);
      } else {
        cmp = aPart.compareTo(bPart);
      }

      if (cmp != 0) return cmp;
    }

    return aParts.length.compareTo(bParts.length);
  }
}
