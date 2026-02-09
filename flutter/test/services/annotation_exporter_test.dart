import 'package:flutter_test/flutter_test.dart';
import 'package:borge/models/annotation.dart';
import 'package:borge/services/annotation_exporter.dart';

void main() {
  group('AnnotationExporter', () {
    final testAnnotations = [
      Annotation(
        id: 'ann-1',
        fileId: 'file-1',
        measureNumber: 1,
        type: AnnotationType.freehand,
        data: 'M 10.0 20.0 L 30.0 40.0',
        createdAt: DateTime(2026, 1, 15, 10, 30),
        x: 0.25,
        y: 0.5,
      ),
      Annotation(
        id: 'ann-2',
        fileId: 'file-1',
        measureNumber: 3,
        type: AnnotationType.structured,
        data: '{"value": "3"}',
        createdAt: DateTime(2026, 1, 15, 11, 0),
        x: 0.7,
        y: 0.2,
        structuredKind: StructuredAnnotationKind.fingerNumber,
      ),
    ];

    group('XML serialization', () {
      test('toXmlString produces valid XML', () {
        final xml = AnnotationExporter.toXmlString(testAnnotations);

        expect(xml, contains('<?xml'));
        expect(xml, contains('<annotations'));
        expect(xml, contains('version="1"'));
        expect(xml, contains('count="2"'));
        expect(xml, contains('<annotation'));
      });

      test('toXmlString includes all annotation fields', () {
        final xml = AnnotationExporter.toXmlString(testAnnotations);

        expect(xml, contains('id="ann-1"'));
        expect(xml, contains('type="freehand"'));
        expect(xml, contains('<fileId>file-1</fileId>'));
        expect(xml, contains('<measureNumber>1</measureNumber>'));
        expect(xml, contains('<x>0.25</x>'));
        expect(xml, contains('<y>0.5</y>'));
      });

      test('toXmlString includes structured annotation kind', () {
        final xml = AnnotationExporter.toXmlString(testAnnotations);

        expect(xml, contains('id="ann-2"'));
        expect(xml, contains('type="structured"'));
        expect(xml, contains('<structuredKind>fingerNumber</structuredKind>'));
      });

      test('toXmlString wraps data in CDATA', () {
        final xml = AnnotationExporter.toXmlString(testAnnotations);
        expect(xml, contains('<![CDATA['));
      });

      test('fromXmlString parses annotations correctly', () {
        final xml = AnnotationExporter.toXmlString(testAnnotations);
        final parsed = AnnotationExporter.fromXmlString(xml);

        expect(parsed.length, 2);
        expect(parsed[0].id, 'ann-1');
        expect(parsed[0].type, AnnotationType.freehand);
        expect(parsed[0].measureNumber, 1);
        expect(parsed[0].x, 0.25);
        expect(parsed[0].y, 0.5);
      });

      test('roundtrip preserves all data', () {
        final xml = AnnotationExporter.toXmlString(testAnnotations);
        final parsed = AnnotationExporter.fromXmlString(xml);

        for (int i = 0; i < testAnnotations.length; i++) {
          expect(parsed[i].id, testAnnotations[i].id);
          expect(parsed[i].fileId, testAnnotations[i].fileId);
          expect(parsed[i].measureNumber, testAnnotations[i].measureNumber);
          expect(parsed[i].type, testAnnotations[i].type);
          expect(parsed[i].x, testAnnotations[i].x);
          expect(parsed[i].y, testAnnotations[i].y);
          expect(parsed[i].structuredKind, testAnnotations[i].structuredKind);
        }
      });

      test('fromXmlString handles empty annotation list', () {
        final xml = AnnotationExporter.toXmlString([]);
        final parsed = AnnotationExporter.fromXmlString(xml);
        expect(parsed, isEmpty);
      });

      test('fromXmlString returns empty list for invalid root', () {
        final parsed = AnnotationExporter.fromXmlString('<other></other>');
        expect(parsed, isEmpty);
      });
    });
  });
}
