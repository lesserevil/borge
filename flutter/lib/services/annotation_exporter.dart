import 'dart:io';

import 'package:xml/xml.dart';

import '../models/annotation.dart';

/// Service for exporting and importing annotations as XML files.
///
/// Annotations are saved alongside MusicXML files as `.annotation.xml` files.
class AnnotationExporter {
  /// Export annotations to an XML file alongside the music file.
  ///
  /// Given a music file at `/path/to/song.musicxml`, creates
  /// `/path/to/song.annotation.xml`.
  static Future<void> exportToFile(
    String musicFilePath,
    List<Annotation> annotations,
  ) async {
    final xmlPath = _annotationPathFor(musicFilePath);
    final xmlString = toXmlString(annotations);
    await File(xmlPath).writeAsString(xmlString);
  }

  /// Import annotations from an XML file alongside the music file.
  ///
  /// Returns an empty list if no annotation file exists.
  static Future<List<Annotation>> importFromFile(String musicFilePath) async {
    final xmlPath = _annotationPathFor(musicFilePath);
    final file = File(xmlPath);

    if (!await file.exists()) {
      return [];
    }

    final xmlString = await file.readAsString();
    return fromXmlString(xmlString);
  }

  /// Convert a list of annotations to an XML string.
  static String toXmlString(List<Annotation> annotations) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'annotations',
      nest: () {
        builder.attribute('version', '1');
        builder.attribute('count', '${annotations.length}');

        for (final ann in annotations) {
          builder.element(
            'annotation',
            nest: () {
              builder.attribute('id', ann.id);
              builder.attribute('type', ann.type.name);

              builder.element('fileId', nest: ann.fileId);
              builder.element('measureNumber', nest: '${ann.measureNumber}');
              builder.element('x', nest: '${ann.x}');
              builder.element('y', nest: '${ann.y}');
              builder.element(
                'createdAt',
                nest: ann.createdAt.toIso8601String(),
              );
              builder.element(
                'data',
                nest: () {
                  builder.cdata(ann.data);
                },
              );

              if (ann.structuredKind != null) {
                builder.element(
                  'structuredKind',
                  nest: ann.structuredKind!.name,
                );
              }
            },
          );
        }
      },
    );

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Parse annotations from an XML string.
  static List<Annotation> fromXmlString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final annotationsElement = document.rootElement;

    if (annotationsElement.localName != 'annotations') {
      return [];
    }

    final results = <Annotation>[];

    for (final element in annotationsElement.findElements('annotation')) {
      try {
        final id = element.getAttribute('id') ?? '';
        final typeStr = element.getAttribute('type') ?? 'freehand';

        final type = AnnotationType.values.firstWhere(
          (t) => t.name == typeStr,
          orElse: () => AnnotationType.freehand,
        );

        final fileId = _textOf(element, 'fileId');
        final measureNumber =
            int.tryParse(_textOf(element, 'measureNumber')) ?? 1;
        final x = double.tryParse(_textOf(element, 'x')) ?? 0.0;
        final y = double.tryParse(_textOf(element, 'y')) ?? 0.0;
        final createdAt =
            DateTime.tryParse(_textOf(element, 'createdAt')) ?? DateTime.now();

        // Data may be wrapped in CDATA
        final dataElement = element.findElements('data').firstOrNull;
        String data = '';
        if (dataElement != null) {
          data = dataElement.children
              .map((n) => n is XmlCDATA ? n.value : n.value)
              .join();
        }

        StructuredAnnotationKind? structuredKind;
        final kindStr = _textOf(element, 'structuredKind');
        if (kindStr.isNotEmpty) {
          structuredKind = StructuredAnnotationKind.values.firstWhere(
            (k) => k.name == kindStr,
            orElse: () => StructuredAnnotationKind.fingerNumber,
          );
        }

        results.add(
          Annotation(
            id: id,
            fileId: fileId,
            measureNumber: measureNumber,
            type: type,
            data: data,
            createdAt: createdAt,
            x: x,
            y: y,
            structuredKind: structuredKind,
          ),
        );
      } catch (e) {
        // Skip malformed annotation entries
        continue;
      }
    }

    return results;
  }

  /// Check if an annotation file exists for a given music file.
  static Future<bool> hasAnnotations(String musicFilePath) async {
    return File(_annotationPathFor(musicFilePath)).exists();
  }

  /// Delete the annotation file for a given music file.
  static Future<void> deleteAnnotationFile(String musicFilePath) async {
    final file = File(_annotationPathFor(musicFilePath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  static String _annotationPathFor(String musicFilePath) {
    final lastDot = musicFilePath.lastIndexOf('.');
    if (lastDot == -1) {
      return '$musicFilePath.annotation.xml';
    }
    return '${musicFilePath.substring(0, lastDot)}.annotation.xml';
  }

  static String _textOf(XmlElement parent, String childName) {
    final child = parent.findElements(childName).firstOrNull;
    return child?.innerText ?? '';
  }
}
