/// Represents a single page of sheet music within a song.
class Page {
  /// The page number (1-indexed).
  final int pageNumber;

  /// Absolute path to the page file.
  final String path;

  /// File extension (e.g., '.pdf', '.png').
  final String extension;

  const Page({
    required this.pageNumber,
    required this.path,
    required this.extension,
  });

  /// Converts to JSON map.
  Map<String, dynamic> toJson() => {
        'page': pageNumber,
        'path': path,
        'extension': extension,
      };

  /// Creates from JSON map.
  factory Page.fromJson(Map<String, dynamic> json) => Page(
        pageNumber: json['page'] as int,
        path: json['path'] as String,
        extension: json['extension'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Page &&
          runtimeType == other.runtimeType &&
          pageNumber == other.pageNumber &&
          path == other.path;

  @override
  int get hashCode => Object.hash(pageNumber, path);

  @override
  String toString() => 'Page(pageNumber: $pageNumber, path: $path)';
}
