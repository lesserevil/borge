import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';

import 'google_drive_auth_service.dart';

/// Item in Google Drive (file or folder)
class DriveItem {
  final String id;
  final String name;
  final bool isFolder;
  final DateTime? modifiedTime;
  final int? size;

  const DriveItem({
    required this.id,
    required this.name,
    required this.isFolder,
    this.modifiedTime,
    this.size,
  });

  factory DriveItem.fromDriveFile(drive.File file) {
    return DriveItem(
      id: file.id!,
      name: file.name!,
      isFolder: file.mimeType == 'application/vnd.google-apps.folder',
      modifiedTime: file.modifiedTime,
      size: file.size != null ? int.parse(file.size!) : null,
    );
  }

  @override
  String toString() => 'DriveItem($name, ${isFolder ? "folder" : "file"})';
}

/// Service for interacting with Google Drive API
class GoogleDriveService {
  final GoogleDriveAuthService _authService;
  drive.DriveApi? _driveApi;

  GoogleDriveService({required GoogleDriveAuthService authService})
      : _authService = authService;

  /// Initialize the Drive API
  Future<bool> initialize() async {
    if (!_authService.isSignedIn) {
      debugPrint('Not signed in to Google');
      return false;
    }

    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('Failed to get authenticated client');
        return false;
      }

      _driveApi = drive.DriveApi(client);
      debugPrint('Google Drive API initialized');
      return true;
    } catch (e) {
      debugPrint('Error initializing Drive API: $e');
      return false;
    }
  }

  /// List folders in the given parent folder (or root if parentId is null)
  Future<List<DriveItem>> listFolders({String? parentId}) async {
    debugPrint('=== listFolders called with parentId: $parentId ===');
    
    if (_driveApi == null) {
      debugPrint('ERROR: Drive API not initialized');
      return [];
    }

    try {
      final query = parentId != null
          ? "'$parentId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"
          : "mimeType='application/vnd.google-apps.folder' and trashed=false and 'root' in parents";

      debugPrint('Drive query: $query');

      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, modifiedTime)',
        orderBy: 'name',
      );

      debugPrint('Drive API response received');
      debugPrint('Number of files: ${fileList.files?.length ?? 0}');
      
      if (fileList.files != null) {
        for (var file in fileList.files!) {
          debugPrint('  - ${file.name} (${file.id})');
        }
      }

      final items = fileList.files?.map((f) => DriveItem.fromDriveFile(f)).toList() ?? [];
      debugPrint('Returning ${items.length} folders');
      return items;
    } catch (e, stackTrace) {
      debugPrint('ERROR listing Drive folders: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// List MusicXML files in a folder (non-recursive)
  Future<List<DriveItem>> listMusicXmlFiles(String folderId) async {
    if (_driveApi == null) {
      debugPrint('Drive API not initialized');
      return [];
    }

    try {
      // Query for .musicxml and .xml files
      final query =
          "'$folderId' in parents and (name contains '.musicxml' or name contains '.xml') and trashed=false";

      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, modifiedTime, size)',
        orderBy: 'name',
      );

      final items =
          fileList.files?.map((f) => DriveItem.fromDriveFile(f)).toList() ??
              [];

      // Filter to only .musicxml and .xml files
      return items
          .where((item) =>
              !item.isFolder &&
              (item.name.toLowerCase().endsWith('.musicxml') ||
                  item.name.toLowerCase().endsWith('.xml')))
          .toList();
    } catch (e) {
      debugPrint('Error listing MusicXML files: $e');
      return [];
    }
  }

  /// List MusicXML files in a folder and all its subfolders recursively
  Future<List<DriveItem>> listMusicXmlFilesRecursive(String folderId, {String folderPath = ''}) async {
    if (_driveApi == null) {
      debugPrint('Drive API not initialized');
      return [];
    }

    final allFiles = <DriveItem>[];

    try {
      // Get files in current folder
      final files = await listMusicXmlFiles(folderId);
      
      // Add folder path to each file's metadata for display purposes
      for (final file in files) {
        allFiles.add(file);
      }
      
      debugPrint('Found ${files.length} music files in folder $folderPath');

      // Get subfolders
      final subfolders = await listFolders(parentId: folderId);
      debugPrint('Found ${subfolders.length} subfolders in $folderPath');

      // Recursively scan each subfolder
      for (final subfolder in subfolders) {
        final subPath = folderPath.isEmpty ? subfolder.name : '$folderPath/${subfolder.name}';
        debugPrint('Recursively scanning subfolder: $subPath');
        final subFiles = await listMusicXmlFilesRecursive(subfolder.id, folderPath: subPath);
        allFiles.addAll(subFiles);
      }
    } catch (e) {
      debugPrint('Error in recursive file listing: $e');
    }

    return allFiles;
  }

  /// Get folder information by ID
  Future<DriveItem?> getFolder(String folderId) async {
    if (_driveApi == null) {
      debugPrint('Drive API not initialized');
      return null;
    }

    try {
      final file = await _driveApi!.files.get(
        folderId,
        $fields: 'id, name, mimeType, modifiedTime',
      ) as drive.File;

      return DriveItem.fromDriveFile(file);
    } catch (e) {
      debugPrint('Error getting folder info: $e');
      return null;
    }
  }

  /// Download a file from Google Drive to local cache
  /// Returns the local file path
  Future<String?> downloadFile(String fileId, String fileName) async {
    if (_driveApi == null) {
      debugPrint('Drive API not initialized');
      return null;
    }

    try {
      // Get the app's cache directory
      final cacheDir = await _getCacheDir();
      if (cacheDir == null) return null;

      final localPath = '${cacheDir.path}/$fileId-$fileName';
      final localFile = File(localPath);

      // Download the file
      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Write to local file
      final sink = localFile.openWrite();
      await media.stream.pipe(sink);

      debugPrint('Downloaded file to: $localPath');
      return localPath;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      return null;
    }
  }

  /// Download all MusicXML files from a folder (recursively scans subfolders)
  /// Returns a map of file ID to local path
  Future<Map<String, String>> downloadFolderContents(String folderId) async {
    final files = await listMusicXmlFilesRecursive(folderId);
    final downloads = <String, String>{};

    for (final file in files) {
      final localPath = await downloadFile(file.id, file.name);
      if (localPath != null) {
        downloads[file.id] = localPath;
      }
    }

    debugPrint('Downloaded ${downloads.length} files from folder $folderId (including subfolders)');
    return downloads;
  }

  /// Get the cache directory for Google Drive files
  Future<Directory?> _getCacheDir() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final driveCache = Directory('${appDir.path}/google_drive_cache');

      if (!await driveCache.exists()) {
        await driveCache.create(recursive: true);
      }

      return driveCache;
    } catch (e) {
      debugPrint('Error getting cache directory: $e');
      return null;
    }
  }

  /// Clear the Google Drive cache
  Future<void> clearCache() async {
    final cacheDir = await _getCacheDir();
    if (cacheDir == null) return;

    try {
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('Cleared Google Drive cache');
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    final cacheDir = await _getCacheDir();
    if (cacheDir == null) return 0;

    try {
      if (!await cacheDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
      return 0;
    }
  }
}
