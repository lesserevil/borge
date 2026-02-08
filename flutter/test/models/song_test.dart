import 'package:flutter_test/flutter_test.dart';
import 'package:borge/models/song.dart';
import 'package:borge/models/page.dart';

void main() {
  group('Song', () {
    test('creates with required fields', () {
      final song = Song(
        id: 'abc123',
        name: 'Test Song',
        pages: [
          const Page(
            pageNumber: 1,
            path: '/p1.musicxml',
            extension: '.musicxml',
          ),
          const Page(
            pageNumber: 2,
            path: '/p2.musicxml',
            extension: '.musicxml',
          ),
        ],
      );

      expect(song.id, 'abc123');
      expect(song.name, 'Test Song');
      expect(song.pageCount, 2);
      expect(song.hasPages, true);
    });

    test('getPage returns correct page for valid number', () {
      final song = Song(
        id: 'test',
        name: 'Test',
        pages: [
          const Page(
            pageNumber: 1,
            path: '/p1.musicxml',
            extension: '.musicxml',
          ),
          const Page(
            pageNumber: 2,
            path: '/p2.musicxml',
            extension: '.musicxml',
          ),
          const Page(
            pageNumber: 3,
            path: '/p3.musicxml',
            extension: '.musicxml',
          ),
        ],
      );

      expect(song.getPage(1)?.path, '/p1.musicxml');
      expect(song.getPage(2)?.path, '/p2.musicxml');
      expect(song.getPage(3)?.path, '/p3.musicxml');
    });

    test('getPage returns null for invalid page numbers', () {
      final song = Song(
        id: 'test',
        name: 'Test',
        pages: [
          const Page(
            pageNumber: 1,
            path: '/p1.musicxml',
            extension: '.musicxml',
          ),
        ],
      );

      expect(song.getPage(0), null);
      expect(song.getPage(-1), null);
      expect(song.getPage(2), null);
      expect(song.getPage(100), null);
    });

    test('empty song has no pages', () {
      final song = Song(id: 'empty', name: 'Empty Song', pages: []);

      expect(song.pageCount, 0);
      expect(song.hasPages, false);
    });

    group('JSON serialization', () {
      test('toJson creates correct structure', () {
        final song = Song(
          id: 'song1',
          name: 'My Song',
          pages: [
            const Page(
              pageNumber: 1,
              path: '/p1.musicxml',
              extension: '.musicxml',
            ),
          ],
          directoryPath: '/music/my-song',
        );

        final json = song.toJson();

        expect(json['id'], 'song1');
        expect(json['name'], 'My Song');
        expect(json['pages'], isA<List>());
        expect((json['pages'] as List).length, 1);
        expect(json['directoryPath'], '/music/my-song');
      });

      test('toJson omits null directoryPath', () {
        final song = Song(id: 'song1', name: 'My Song', pages: []);

        final json = song.toJson();

        expect(json.containsKey('directoryPath'), false);
      });

      test('fromJson creates correct object', () {
        final json = {
          'id': 'song1',
          'name': 'My Song',
          'pages': [
            {'page': 1, 'path': '/p1.musicxml', 'extension': '.musicxml'},
            {'page': 2, 'path': '/p2.musicxml', 'extension': '.musicxml'},
          ],
          'directoryPath': '/music',
        };

        final song = Song.fromJson(json);

        expect(song.id, 'song1');
        expect(song.name, 'My Song');
        expect(song.pageCount, 2);
        expect(song.directoryPath, '/music');
      });

      test('roundtrip preserves data', () {
        final original = Song(
          id: 'roundtrip',
          name: 'Roundtrip Song',
          pages: [
            const Page(
              pageNumber: 1,
              path: '/a.musicxml',
              extension: '.musicxml',
            ),
            const Page(
              pageNumber: 2,
              path: '/b.musicxml',
              extension: '.musicxml',
            ),
          ],
          directoryPath: '/test',
        );

        final restored = Song.fromJson(original.toJson());

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.pageCount, original.pageCount);
        expect(restored.directoryPath, original.directoryPath);
      });
    });

    test('equality is based on id', () {
      final song1 = Song(id: 'same', name: 'Song 1', pages: []);
      final song2 = Song(id: 'same', name: 'Song 2', pages: []);
      final song3 = Song(id: 'different', name: 'Song 1', pages: []);

      expect(song1 == song2, true);
      expect(song1 == song3, false);
      expect(song1.hashCode, song2.hashCode);
    });
  });

  group('Page', () {
    test('creates with required fields', () {
      const page = Page(
        pageNumber: 5,
        path: '/music/song/page5.musicxml',
        extension: '.musicxml',
      );

      expect(page.pageNumber, 5);
      expect(page.path, '/music/song/page5.musicxml');
      expect(page.extension, '.musicxml');
    });

    group('JSON serialization', () {
      test('toJson creates correct structure', () {
        const page = Page(
          pageNumber: 3,
          path: '/test.musicxml',
          extension: '.musicxml',
        );

        final json = page.toJson();

        expect(json['page'], 3);
        expect(json['path'], '/test.musicxml');
        expect(json['extension'], '.musicxml');
      });

      test('fromJson creates correct object', () {
        final json = {
          'page': 7,
          'path': '/page7.musicxml',
          'extension': '.musicxml',
        };

        final page = Page.fromJson(json);

        expect(page.pageNumber, 7);
        expect(page.path, '/page7.musicxml');
        expect(page.extension, '.musicxml');
      });
    });

    test('equality is based on pageNumber and path', () {
      const page1 = Page(
        pageNumber: 1,
        path: '/a.musicxml',
        extension: '.musicxml',
      );
      const page2 = Page(
        pageNumber: 1,
        path: '/a.musicxml',
        extension: '.musicxml',
      );
      const page3 = Page(
        pageNumber: 2,
        path: '/a.musicxml',
        extension: '.musicxml',
      );
      const page4 = Page(
        pageNumber: 1,
        path: '/b.musicxml',
        extension: '.musicxml',
      );

      expect(page1 == page2, true);
      expect(page1 == page3, false);
      expect(page1 == page4, false);
    });
  });
}
