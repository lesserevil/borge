import 'package:flutter/foundation.dart';

/// Represents a music folder source
enum MusicFolderType {
  local,
  googleDrive,
}

/// Metadata for a Google Drive folder
@immutable
class GoogleDriveFolderMetadata {
  final String folderId;
  final String folderName;
  final DateTime? lastSync;
  final int fileCount;

  const GoogleDriveFolderMetadata({
    required this.folderId,
    required this.folderName,
    this.lastSync,
    this.fileCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'folderId': folderId,
        'folderName': folderName,
        'lastSync': lastSync?.toIso8601String(),
        'fileCount': fileCount,
      };

  factory GoogleDriveFolderMetadata.fromJson(Map<String, dynamic> json) {
    return GoogleDriveFolderMetadata(
      folderId: json['folderId'] as String,
      folderName: json['folderName'] as String,
      lastSync: json['lastSync'] != null
          ? DateTime.parse(json['lastSync'] as String)
          : null,
      fileCount: json['fileCount'] as int? ?? 0,
    );
  }

  GoogleDriveFolderMetadata copyWith({
    String? folderId,
    String? folderName,
    DateTime? lastSync,
    int? fileCount,
  }) {
    return GoogleDriveFolderMetadata(
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      lastSync: lastSync ?? this.lastSync,
      fileCount: fileCount ?? this.fileCount,
    );
  }
}

/// Represents a music folder (local or cloud-based)
@immutable
class MusicFolder {
  final String id;
  final MusicFolderType type;
  final String path; // Local path or "drive://{folderId}"
  final String displayName;
  final GoogleDriveFolderMetadata? driveMetadata;

  const MusicFolder({
    required this.id,
    required this.type,
    required this.path,
    required this.displayName,
    this.driveMetadata,
  });

  bool get isLocal => type == MusicFolderType.local;
  bool get isGoogleDrive => type == MusicFolderType.googleDrive;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'path': path,
        'displayName': displayName,
        'driveMetadata': driveMetadata?.toJson(),
      };

  factory MusicFolder.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = MusicFolderType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => MusicFolderType.local,
    );

    return MusicFolder(
      id: json['id'] as String,
      type: type,
      path: json['path'] as String,
      displayName: json['displayName'] as String,
      driveMetadata: json['driveMetadata'] != null
          ? GoogleDriveFolderMetadata.fromJson(
              json['driveMetadata'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Create a local music folder
  factory MusicFolder.local({
    required String id,
    required String path,
  }) {
    // Extract display name from path
    final displayName = path.split('/').last;
    return MusicFolder(
      id: id,
      type: MusicFolderType.local,
      path: path,
      displayName: displayName,
    );
  }

  /// Create a Google Drive music folder
  factory MusicFolder.googleDrive({
    required String id,
    required GoogleDriveFolderMetadata metadata,
  }) {
    return MusicFolder(
      id: id,
      type: MusicFolderType.googleDrive,
      path: 'drive://${metadata.folderId}',
      displayName: metadata.folderName,
      driveMetadata: metadata,
    );
  }

  MusicFolder copyWith({
    String? id,
    MusicFolderType? type,
    String? path,
    String? displayName,
    GoogleDriveFolderMetadata? driveMetadata,
  }) {
    return MusicFolder(
      id: id ?? this.id,
      type: type ?? this.type,
      path: path ?? this.path,
      displayName: displayName ?? this.displayName,
      driveMetadata: driveMetadata ?? this.driveMetadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicFolder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MusicFolder($type: $displayName)';
}
