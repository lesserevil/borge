import 'package:flutter/foundation.dart';

/// Type of annotation drawn on sheet music.
enum AnnotationType {
  /// Freehand drawing captured as SVG path strings.
  freehand,

  /// Predefined symbols (finger numbers, dynamics, bowing, articulations).
  structured,
}

/// Kind of structured annotation symbol.
enum StructuredAnnotationKind {
  /// Finger number indicators (1-5).
  fingerNumber,

  /// Dynamic markings (pp, p, mp, mf, f, ff, etc.).
  dynamicMark,

  /// Bowing indicators (up-bow, down-bow).
  bowing,

  /// Articulation marks (staccato, accent, tenuto, etc.).
  articulation,
}

/// Represents a user-drawn annotation on sheet music.
///
/// Annotations can be either freehand drawings (SVG paths) or structured
/// symbols placed on specific measures of a music score.
@immutable
class Annotation {
  /// Unique identifier for this annotation.
  final String id;

  /// Reference to the MusicFolder.id this annotation belongs to.
  final String fileId;

  /// The 1-indexed measure number this annotation is associated with.
  final int measureNumber;

  /// Whether this is a freehand drawing or structured symbol.
  final AnnotationType type;

  /// The annotation data:
  /// - For freehand: SVG path string (e.g., "M 10 20 L 30 40 ...")
  /// - For structured: JSON string with symbol-specific data
  final String data;

  /// When this annotation was created.
  final DateTime createdAt;

  /// Normalized x position relative to the measure (0.0 to 1.0).
  final double x;

  /// Normalized y position relative to the measure (0.0 to 1.0).
  final double y;

  /// The kind of structured annotation. Only set when [type] is
  /// [AnnotationType.structured].
  final StructuredAnnotationKind? structuredKind;

  const Annotation({
    required this.id,
    required this.fileId,
    required this.measureNumber,
    required this.type,
    required this.data,
    required this.createdAt,
    required this.x,
    required this.y,
    this.structuredKind,
  });

  /// Converts this annotation to a JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'fileId': fileId,
    'measureNumber': measureNumber,
    'type': type.name,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'x': x,
    'y': y,
    if (structuredKind != null) 'structuredKind': structuredKind!.name,
  };

  /// Creates an [Annotation] from a JSON map.
  factory Annotation.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = AnnotationType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => AnnotationType.freehand,
    );

    StructuredAnnotationKind? structuredKind;
    if (json['structuredKind'] != null) {
      final kindStr = json['structuredKind'] as String;
      structuredKind = StructuredAnnotationKind.values.firstWhere(
        (k) => k.name == kindStr,
        orElse: () => StructuredAnnotationKind.fingerNumber,
      );
    }

    return Annotation(
      id: json['id'] as String,
      fileId: json['fileId'] as String,
      measureNumber: json['measureNumber'] as int,
      type: type,
      data: json['data'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      structuredKind: structuredKind,
    );
  }

  /// Creates a copy of this annotation with the given fields replaced.
  Annotation copyWith({
    String? id,
    String? fileId,
    int? measureNumber,
    AnnotationType? type,
    String? data,
    DateTime? createdAt,
    double? x,
    double? y,
    StructuredAnnotationKind? structuredKind,
  }) {
    return Annotation(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      measureNumber: measureNumber ?? this.measureNumber,
      type: type ?? this.type,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      x: x ?? this.x,
      y: y ?? this.y,
      structuredKind: structuredKind ?? this.structuredKind,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Annotation && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Annotation(id: $id, measure: $measureNumber, type: $type)';
}
