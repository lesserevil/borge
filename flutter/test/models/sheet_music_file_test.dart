import 'package:flutter_test/flutter_test.dart';
import 'package:borge/models/sheet_music_file.dart';

void main() {
  group('SheetMusicFile', () {
    test('creates from file info correctly', () {
      final now = DateTime.now();
      final file = SheetMusicFile.fromFileInfo(
        path: '/music/song.musicxml',
        name: 'song.musicxml',
        sizeBytes: 1024,
        lastModified: now,
      );

      expect(file.name, 'song.musicxml');
      expect(file.path, '/music/song.musicxml');
      expect(file.sizeBytes, 1024);
      expect(file.lastModified, now);
      expect(file.extension, '.musicxml');
    });

    test('handles uppercase extensions', () {
      final file = SheetMusicFile.fromFileInfo(
        path: '/music/song.MUSICXML',
        name: 'song.MUSICXML',
        sizeBytes: 1024,
        lastModified: DateTime.now(),
      );

      expect(file.extension, '.musicxml');
    });

    test('handles files without extension', () {
      final file = SheetMusicFile.fromFileInfo(
        path: '/music/song',
        name: 'song',
        sizeBytes: 1024,
        lastModified: DateTime.now(),
      );

      expect(file.extension, '');
    });

    group('isSupportedExtension', () {
      test('returns true for musicxml', () {
        expect(SheetMusicFile.isSupportedExtension('.musicxml'), true);
      });

      test('returns true for xml', () {
        expect(SheetMusicFile.isSupportedExtension('.xml'), true);
      });

      test('returns true for mxl', () {
        expect(SheetMusicFile.isSupportedExtension('.mxl'), true);
      });

      test('returns true for uppercase extensions', () {
        expect(SheetMusicFile.isSupportedExtension('.MUSICXML'), true);
        expect(SheetMusicFile.isSupportedExtension('.XML'), true);
      });

      test('returns false for unsupported extensions', () {
        expect(SheetMusicFile.isSupportedExtension('.pdf'), false);
        expect(SheetMusicFile.isSupportedExtension('.png'), false);
        expect(SheetMusicFile.isSupportedExtension('.svg'), false);
        expect(SheetMusicFile.isSupportedExtension('.txt'), false);
        expect(SheetMusicFile.isSupportedExtension('.jpg'), false);
        expect(SheetMusicFile.isSupportedExtension('.doc'), false);
      });
    });

    group('JSON serialization', () {
      test('toJson creates correct map', () {
        final now = DateTime(2024, 1, 15, 10, 30, 0);
        final file = SheetMusicFile(
          name: 'song.musicxml',
          path: '/music/song.musicxml',
          sizeBytes: 2048,
          lastModified: now,
          extension: '.musicxml',
        );

        final json = file.toJson();

        expect(json['name'], 'song.musicxml');
        expect(json['path'], '/music/song.musicxml');
        expect(json['sizeBytes'], 2048);
        expect(json['lastModified'], '2024-01-15T10:30:00.000');
        expect(json['extension'], '.musicxml');
      });

      test('fromJson creates correct object', () {
        final json = {
          'name': 'song.musicxml',
          'path': '/music/song.musicxml',
          'sizeBytes': 2048,
          'lastModified': '2024-01-15T10:30:00.000',
          'extension': '.musicxml',
        };

        final file = SheetMusicFile.fromJson(json);

        expect(file.name, 'song.musicxml');
        expect(file.path, '/music/song.musicxml');
        expect(file.sizeBytes, 2048);
        expect(file.lastModified, DateTime(2024, 1, 15, 10, 30, 0));
        expect(file.extension, '.musicxml');
      });

      test('roundtrip preserves data', () {
        final original = SheetMusicFile(
          name: 'test.musicxml',
          path: '/path/to/test.musicxml',
          sizeBytes: 4096,
          lastModified: DateTime(2024, 6, 1, 12, 0, 0),
          extension: '.musicxml',
        );

        final restored = SheetMusicFile.fromJson(original.toJson());

        expect(restored.name, original.name);
        expect(restored.path, original.path);
        expect(restored.sizeBytes, original.sizeBytes);
        expect(restored.lastModified, original.lastModified);
        expect(restored.extension, original.extension);
      });
    });

    test('equality is based on path', () {
      final file1 = SheetMusicFile(
        name: 'song.musicxml',
        path: '/music/song.musicxml',
        sizeBytes: 1024,
        lastModified: DateTime.now(),
        extension: '.musicxml',
      );

      final file2 = SheetMusicFile(
        name: 'song.musicxml',
        path: '/music/song.musicxml',
        sizeBytes: 2048,
        lastModified: DateTime.now().add(const Duration(days: 1)),
        extension: '.musicxml',
      );

      final file3 = SheetMusicFile(
        name: 'other.musicxml',
        path: '/music/other.musicxml',
        sizeBytes: 1024,
        lastModified: DateTime.now(),
        extension: '.musicxml',
      );

      expect(file1 == file2, true);
      expect(file1 == file3, false);
      expect(file1.hashCode, file2.hashCode);
    });
  });
}
