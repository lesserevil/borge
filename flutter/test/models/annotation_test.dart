import 'package:flutter_test/flutter_test.dart';
import 'package:borge/models/annotation.dart';

void main() {
  group('Annotation', () {
    final testAnnotation = Annotation(
      id: 'test-id-1',
      fileId: 'file-123',
      measureNumber: 5,
      type: AnnotationType.freehand,
      data: 'M 10.0 20.0 L 30.0 40.0 L 50.0 60.0',
      createdAt: DateTime(2026, 1, 15, 10, 30),
      x: 0.5,
      y: 0.3,
    );

    final testStructuredAnnotation = Annotation(
      id: 'test-id-2',
      fileId: 'file-123',
      measureNumber: 8,
      type: AnnotationType.structured,
      data: '{"value": "3"}',
      createdAt: DateTime(2026, 1, 15, 11, 0),
      x: 0.7,
      y: 0.2,
      structuredKind: StructuredAnnotationKind.fingerNumber,
    );

    test('creates freehand annotation with required fields', () {
      expect(testAnnotation.id, 'test-id-1');
      expect(testAnnotation.fileId, 'file-123');
      expect(testAnnotation.measureNumber, 5);
      expect(testAnnotation.type, AnnotationType.freehand);
      expect(testAnnotation.data, 'M 10.0 20.0 L 30.0 40.0 L 50.0 60.0');
      expect(testAnnotation.x, 0.5);
      expect(testAnnotation.y, 0.3);
      expect(testAnnotation.structuredKind, isNull);
    });

    test('creates structured annotation with kind', () {
      expect(testStructuredAnnotation.type, AnnotationType.structured);
      expect(
        testStructuredAnnotation.structuredKind,
        StructuredAnnotationKind.fingerNumber,
      );
      expect(testStructuredAnnotation.data, '{"value": "3"}');
    });

    group('JSON serialization', () {
      test('toJson produces correct map for freehand', () {
        final json = testAnnotation.toJson();

        expect(json['id'], 'test-id-1');
        expect(json['fileId'], 'file-123');
        expect(json['measureNumber'], 5);
        expect(json['type'], 'freehand');
        expect(json['data'], 'M 10.0 20.0 L 30.0 40.0 L 50.0 60.0');
        expect(json['x'], 0.5);
        expect(json['y'], 0.3);
        expect(json.containsKey('structuredKind'), isFalse);
      });

      test('toJson includes structuredKind for structured annotations', () {
        final json = testStructuredAnnotation.toJson();

        expect(json['type'], 'structured');
        expect(json['structuredKind'], 'fingerNumber');
      });

      test('fromJson creates correct freehand annotation', () {
        final json = {
          'id': 'from-json-id',
          'fileId': 'file-456',
          'measureNumber': 10,
          'type': 'freehand',
          'data': 'M 0.0 0.0 L 100.0 100.0',
          'createdAt': '2026-02-01T12:00:00.000',
          'x': 0.25,
          'y': 0.75,
        };

        final annotation = Annotation.fromJson(json);

        expect(annotation.id, 'from-json-id');
        expect(annotation.fileId, 'file-456');
        expect(annotation.measureNumber, 10);
        expect(annotation.type, AnnotationType.freehand);
        expect(annotation.x, 0.25);
        expect(annotation.y, 0.75);
        expect(annotation.structuredKind, isNull);
      });

      test('fromJson creates correct structured annotation', () {
        final json = {
          'id': 'structured-id',
          'fileId': 'file-789',
          'measureNumber': 3,
          'type': 'structured',
          'data': '{"value": "mf"}',
          'createdAt': '2026-02-01T12:00:00.000',
          'x': 0.5,
          'y': 0.5,
          'structuredKind': 'dynamicMark',
        };

        final annotation = Annotation.fromJson(json);

        expect(annotation.type, AnnotationType.structured);
        expect(annotation.structuredKind, StructuredAnnotationKind.dynamicMark);
      });

      test('roundtrip preserves data', () {
        final json = testAnnotation.toJson();
        final restored = Annotation.fromJson(json);

        expect(restored.id, testAnnotation.id);
        expect(restored.fileId, testAnnotation.fileId);
        expect(restored.measureNumber, testAnnotation.measureNumber);
        expect(restored.type, testAnnotation.type);
        expect(restored.data, testAnnotation.data);
        expect(restored.x, testAnnotation.x);
        expect(restored.y, testAnnotation.y);
        expect(restored.structuredKind, testAnnotation.structuredKind);
      });

      test('structured roundtrip preserves kind', () {
        final json = testStructuredAnnotation.toJson();
        final restored = Annotation.fromJson(json);

        expect(
          restored.structuredKind,
          testStructuredAnnotation.structuredKind,
        );
      });

      test('fromJson handles integer x/y values', () {
        final json = {
          'id': 'int-test',
          'fileId': 'file-1',
          'measureNumber': 1,
          'type': 'freehand',
          'data': '',
          'createdAt': '2026-01-01T00:00:00.000',
          'x': 1,
          'y': 0,
        };

        final annotation = Annotation.fromJson(json);
        expect(annotation.x, 1.0);
        expect(annotation.y, 0.0);
      });
    });

    group('equality', () {
      test('annotations with same id are equal', () {
        final other = Annotation(
          id: 'test-id-1',
          fileId: 'different-file',
          measureNumber: 99,
          type: AnnotationType.structured,
          data: 'different data',
          createdAt: DateTime.now(),
          x: 0.0,
          y: 0.0,
        );

        expect(testAnnotation, equals(other));
        expect(testAnnotation.hashCode, equals(other.hashCode));
      });

      test('annotations with different id are not equal', () {
        expect(testAnnotation, isNot(equals(testStructuredAnnotation)));
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final copy = testAnnotation.copyWith(
          measureNumber: 10,
          data: 'new path data',
        );

        expect(copy.id, testAnnotation.id);
        expect(copy.fileId, testAnnotation.fileId);
        expect(copy.measureNumber, 10);
        expect(copy.data, 'new path data');
        expect(copy.type, testAnnotation.type);
      });

      test('preserves original when no fields specified', () {
        final copy = testAnnotation.copyWith();

        expect(copy.id, testAnnotation.id);
        expect(copy.measureNumber, testAnnotation.measureNumber);
        expect(copy.data, testAnnotation.data);
      });
    });

    test('toString returns readable representation', () {
      final str = testAnnotation.toString();
      expect(str, contains('test-id-1'));
      expect(str, contains('5'));
      expect(str, contains('freehand'));
    });
  });

  group('AnnotationType', () {
    test('has freehand and structured values', () {
      expect(AnnotationType.values, contains(AnnotationType.freehand));
      expect(AnnotationType.values, contains(AnnotationType.structured));
      expect(AnnotationType.values.length, 2);
    });
  });

  group('StructuredAnnotationKind', () {
    test('has all expected values', () {
      expect(
        StructuredAnnotationKind.values,
        contains(StructuredAnnotationKind.fingerNumber),
      );
      expect(
        StructuredAnnotationKind.values,
        contains(StructuredAnnotationKind.dynamicMark),
      );
      expect(
        StructuredAnnotationKind.values,
        contains(StructuredAnnotationKind.bowing),
      );
      expect(
        StructuredAnnotationKind.values,
        contains(StructuredAnnotationKind.articulation),
      );
      expect(StructuredAnnotationKind.values.length, 4);
    });
  });
}
