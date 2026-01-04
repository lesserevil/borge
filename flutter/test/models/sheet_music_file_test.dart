import 'package:flutter_test/flutter_test.dart';
import 'package:borge/models/sheet_music_file.dart';

void main() {
  group('SheetMusicFile', () {
    test('creates from file info correctly', () {
      final now = DateTime.now();
      final file = SheetMusicFile.fromFileInfo(
        path: '/music/song.pdf',
        name: 'song.pdf',
        sizeBytes: 1024,
        lastModified: now,
      );

      expect(file.name, 'song.pdf');
      expect(file.path, '/music/song.pdf');
      expect(file.sizeBytes, 1024);
      expect(file.lastModified, now);
      expect(file.extension, '.pdf');
    });

    test('handles uppercase extensions', () {
      final file = SheetMusicFile.fromFileInfo(
        path: '/music/song.PDF',
        name: 'song.PDF',
        sizeBytes: 1024,
        lastModified: DateTime.now(),
      );

      expect(file.extension, '.pdf');
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
      test('returns true for pdf', () {
        expect(SheetMusicFile.isSupportedExtension('.pdf'), true);
      });

      test('returns true for png', () {
        expect(SheetMusicFile.isSupportedExtension('.png'), true);
      });

      test('returns true for svg', () {
        expect(SheetMusicFile.isSupportedExtension('.svg'), true);
      });

      test('returns true for musicxml', () {
        expect(SheetMusicFile.isSupportedExtension('.musicxml'), true);
      });

      test('returns true for uppercase extensions', () {
        expect(SheetMusicFile.isSupportedExtension('.PDF'), true);
        expect(SheetMusicFile.isSupportedExtension('.PNG'), true);
      });

      test('returns false for unsupported extensions', () {
        expect(SheetMusicFile.isSupportedExtension('.txt'), false);
        expect(SheetMusicFile.isSupportedExtension('.jpg'), false);
        expect(SheetMusicFile.isSupportedExtension('.doc'), false);
      });
    });

    group('JSON serialization', () {
      test('toJson creates correct map', () {
        final now = DateTime(2024, 1, 15, 10, 30, 0);
        final file = SheetMusicFile(
          name: 'song.pdf',
          path: '/music/song.pdf',
          sizeBytes: 2048,
          lastModified: now,
          extension: '.pdf',
        );

        final json = file.toJson();

        expect(json['name'], 'song.pdf');
        expect(json['path'], '/music/song.pdf');
        expect(json['sizeBytes'], 2048);
        expect(json['lastModified'], '2024-01-15T10:30:00.000');
        expect(json['extension'], '.pdf');
      });

      test('fromJson creates correct object', () {
        final json = {
          'name': 'song.pdf',
          'path': '/music/song.pdf',
          'sizeBytes': 2048,
          'lastModified': '2024-01-15T10:30:00.000',
          'extension': '.pdf',
        };

        final file = SheetMusicFile.fromJson(json);

        expect(file.name, 'song.pdf');
        expect(file.path, '/music/song.pdf');
        expect(file.sizeBytes, 2048);
        expect(file.lastModified, DateTime(2024, 1, 15, 10, 30, 0));
        expect(file.extension, '.pdf');
      });

      test('roundtrip preserves data', () {
        final original = SheetMusicFile(
          name: 'test.png',
          path: '/path/to/test.png',
          sizeBytes: 4096,
          lastModified: DateTime(2024, 6, 1, 12, 0, 0),
          extension: '.png',
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
        name: 'song.pdf',
        path: '/music/song.pdf',
        sizeBytes: 1024,
        lastModified: DateTime.now(),
        extension: '.pdf',
      );

      final file2 = SheetMusicFile(
        name: 'song.pdf',
        path: '/music/song.pdf',
        sizeBytes: 2048,
        lastModified: DateTime.now().add(const Duration(days: 1)),
        extension: '.pdf',
      );

      final file3 = SheetMusicFile(
        name: 'other.pdf',
        path: '/music/other.pdf',
        sizeBytes: 1024,
        lastModified: DateTime.now(),
        extension: '.pdf',
      );

      expect(file1 == file2, true);
      expect(file1 == file3, false);
      expect(file1.hashCode, file2.hashCode);
    });
  });
}
