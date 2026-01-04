import 'page.dart';

/// Represents a song with multiple pages of sheet music.
class Song {
  /// Unique identifier for the song.
  final String id;

  /// Display name of the song.
  final String name;

  /// List of pages in this song.
  final List<Page> pages;

  /// Optional directory path containing the song files.
  final String? directoryPath;

  const Song({
    required this.id,
    required this.name,
    required this.pages,
    this.directoryPath,
  });

  /// Total number of pages in this song.
  int get pageCount => pages.length;

  /// Returns true if this song has any pages.
  bool get hasPages => pages.isNotEmpty;

  /// Gets a page by number (1-indexed).
  Page? getPage(int pageNumber) {
    if (pageNumber < 1 || pageNumber > pages.length) return null;
    return pages[pageNumber - 1];
  }

  /// Converts to JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pages': pages.map((p) => p.toJson()).toList(),
        if (directoryPath != null) 'directoryPath': directoryPath,
      };

  /// Creates from JSON map.
  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String,
        name: json['name'] as String,
        pages: (json['pages'] as List<dynamic>)
            .map((p) => Page.fromJson(p as Map<String, dynamic>))
            .toList(),
        directoryPath: json['directoryPath'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Song(id: $id, name: $name, pages: ${pages.length})';
}
