/// Represents a sheet music file discovered during directory scanning.
class SheetMusicFile {
  /// The file name without path.
  final String name;

  /// The absolute path to the file.
  final String path;

  /// The file size in bytes.
  final int sizeBytes;

  /// The last modified timestamp.
  final DateTime lastModified;

  /// The file extension (e.g., '.musicxml', '.xml').
  final String extension;

  const SheetMusicFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.lastModified,
    required this.extension,
  });

  /// Returns true if this file type is supported.
  static bool isSupportedExtension(String ext) {
    const supported = {'.musicxml', '.xml', '.mxl'};
    return supported.contains(ext.toLowerCase());
  }

  /// Creates a SheetMusicFile from a file path and stats.
  factory SheetMusicFile.fromFileInfo({
    required String path,
    required String name,
    required int sizeBytes,
    required DateTime lastModified,
  }) {
    final ext = name.contains('.')
        ? '.${name.split('.').last}'.toLowerCase()
        : '';
    return SheetMusicFile(
      name: name,
      path: path,
      sizeBytes: sizeBytes,
      lastModified: lastModified,
      extension: ext,
    );
  }

  /// Converts to JSON map.
  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'sizeBytes': sizeBytes,
    'lastModified': lastModified.toIso8601String(),
    'extension': extension,
  };

  /// Creates from JSON map.
  factory SheetMusicFile.fromJson(Map<String, dynamic> json) => SheetMusicFile(
    name: json['name'] as String,
    path: json['path'] as String,
    sizeBytes: json['sizeBytes'] as int,
    lastModified: DateTime.parse(json['lastModified'] as String),
    extension: json['extension'] as String,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SheetMusicFile &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'SheetMusicFile(name: $name, path: $path)';
}
