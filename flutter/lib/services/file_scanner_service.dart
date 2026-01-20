import 'dart:io';

import '../models/sheet_music_file.dart';

/// Exception thrown when scanning encounters an error.
class FileScanException implements Exception {
  final String message;
  final String? path;

  FileScanException(this.message, {this.path});

  @override
  String toString() => path != null
      ? 'FileScanException: $message (path: $path)'
      : 'FileScanException: $message';
}

/// Service for scanning directories for sheet music files.
class FileScannerService {
  /// Supported file extensions for sheet music (MusicXML focus).
  static const supportedExtensions = {'.musicxml', '.xml', '.mxl'};

  /// Scans a directory for sheet music files.
  ///
  /// Returns a list of [SheetMusicFile] objects for files matching
  /// supported extensions (.pdf, .png, .svg, .musicxml).
  ///
  /// Throws [FileScanException] if the directory doesn't exist or
  /// cannot be accessed.
  Future<List<SheetMusicFile>> scanDirectory(String path) async {
    final directory = Directory(path);

    if (!await directory.exists()) {
      throw FileScanException('Directory does not exist', path: path);
    }

    try {
      final files = <SheetMusicFile>[];

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final file = await _processFile(entity);
          if (file != null) {
            files.add(file);
          }
        }
      }

      // Sort by name for consistent ordering
      files.sort((a, b) => a.name.compareTo(b.name));
      return files;
    } on FileSystemException catch (e) {
      throw FileScanException(
        'Permission denied or cannot access directory',
        path: e.path ?? path,
      );
    }
  }

  /// Synchronously scans a directory for sheet music files.
  ///
  /// Useful for testing or when async is not needed.
  List<SheetMusicFile> scanDirectorySync(String path) {
    final directory = Directory(path);

    if (!directory.existsSync()) {
      throw FileScanException('Directory does not exist', path: path);
    }

    try {
      final files = <SheetMusicFile>[];

      for (final entity in directory.listSync(recursive: true)) {
        if (entity is File) {
          final file = _processFileSync(entity);
          if (file != null) {
            files.add(file);
          }
        }
      }

      // Sort by name for consistent ordering
      files.sort((a, b) => a.name.compareTo(b.name));
      return files;
    } on FileSystemException catch (e) {
      throw FileScanException(
        'Permission denied or cannot access directory',
        path: e.path ?? path,
      );
    }
  }

  /// Processes a file and returns a SheetMusicFile if it's a supported type.
  Future<SheetMusicFile?> _processFile(File file) async {
    final name = file.uri.pathSegments.last;
    final ext = _getExtension(name);

    if (!supportedExtensions.contains(ext)) {
      return null;
    }

    try {
      final stat = await file.stat();
      return SheetMusicFile.fromFileInfo(
        path: file.path,
        name: name,
        sizeBytes: stat.size,
        lastModified: stat.modified,
      );
    } on FileSystemException {
      // Skip files we can't access
      return null;
    }
  }

  /// Synchronous version of _processFile.
  SheetMusicFile? _processFileSync(File file) {
    final name = file.uri.pathSegments.last;
    final ext = _getExtension(name);

    if (!supportedExtensions.contains(ext)) {
      return null;
    }

    try {
      final stat = file.statSync();
      return SheetMusicFile.fromFileInfo(
        path: file.path,
        name: name,
        sizeBytes: stat.size,
        lastModified: stat.modified,
      );
    } on FileSystemException {
      // Skip files we can't access
      return null;
    }
  }

  /// Extracts the lowercase extension from a filename.
  String _getExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == filename.length - 1) {
      return '';
    }
    return filename.substring(dotIndex).toLowerCase();
  }
}
