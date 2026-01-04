import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:borge/services/song_repository.dart';

void main() {
  group('SongRepository', () {
    late SongRepository repository;
    late Directory tempDir;

    setUp(() async {
      repository = SongRepository();
      tempDir = await Directory.systemTemp.createTemp('borge_repo_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loadFromDirectory returns empty list for empty directory', () async {
      final songs = await repository.loadFromDirectory(tempDir.path);
      expect(songs, isEmpty);
    });

    test('groups files by directory into songs', () async {
      final song1Dir = Directory('${tempDir.path}/Song One');
      final song2Dir = Directory('${tempDir.path}/Song Two');
      await song1Dir.create();
      await song2Dir.create();

      await File('${song1Dir.path}/page1.pdf').writeAsString('test');
      await File('${song1Dir.path}/page2.pdf').writeAsString('test');
      await File('${song2Dir.path}/sheet.pdf').writeAsString('test');

      final songs = await repository.loadFromDirectory(tempDir.path);

      expect(songs.length, 2);
      final songNames = songs.map((s) => s.name).toSet();
      expect(songNames, containsAll(['Song One', 'Song Two']));
    });

    test('assigns sequential page numbers', () async {
      final songDir = Directory('${tempDir.path}/MySong');
      await songDir.create();

      await File('${songDir.path}/page1.pdf').writeAsString('test');
      await File('${songDir.path}/page2.pdf').writeAsString('test');
      await File('${songDir.path}/page3.pdf').writeAsString('test');

      final songs = await repository.loadFromDirectory(tempDir.path);

      expect(songs.length, 1);
      expect(songs.first.pageCount, 3);
      expect(songs.first.pages[0].pageNumber, 1);
      expect(songs.first.pages[1].pageNumber, 2);
      expect(songs.first.pages[2].pageNumber, 3);
    });

    test('sorts pages naturally by filename', () async {
      final songDir = Directory('${tempDir.path}/MySong');
      await songDir.create();

      await File('${songDir.path}/page10.pdf').writeAsString('test');
      await File('${songDir.path}/page2.pdf').writeAsString('test');
      await File('${songDir.path}/page1.pdf').writeAsString('test');

      final songs = await repository.loadFromDirectory(tempDir.path);
      final pageFiles =
          songs.first.pages.map((p) => p.path.split('/').last).toList();

      expect(pageFiles, ['page1.pdf', 'page2.pdf', 'page10.pdf']);
    });

    test('generates stable IDs from directory path', () async {
      final songDir = Directory('${tempDir.path}/TestSong');
      await songDir.create();
      await File('${songDir.path}/page.pdf').writeAsString('test');

      final songs1 = await repository.loadFromDirectory(tempDir.path);
      final songs2 = await repository.loadFromDirectory(tempDir.path);

      expect(songs1.first.id, songs2.first.id);
    });

    test('getSongById returns correct song', () async {
      final songDir = Directory('${tempDir.path}/FindMe');
      await songDir.create();
      await File('${songDir.path}/page.pdf').writeAsString('test');

      await repository.loadFromDirectory(tempDir.path);
      final song = repository.songs.first;

      expect(repository.getSongById(song.id), isNotNull);
      expect(repository.getSongById(song.id)!.name, 'FindMe');
    });

    test('getSongById returns null for unknown ID', () async {
      await repository.loadFromDirectory(tempDir.path);
      expect(repository.getSongById('nonexistent'), isNull);
    });

    test('toJson produces valid JSON structure', () async {
      final songDir = Directory('${tempDir.path}/JsonSong');
      await songDir.create();
      await File('${songDir.path}/p1.pdf').writeAsString('test');
      await File('${songDir.path}/p2.pdf').writeAsString('test');

      await repository.loadFromDirectory(tempDir.path);
      final json = repository.toJson();

      expect(json['songs'], isA<List>());
      expect((json['songs'] as List).length, 1);

      final songJson = (json['songs'] as List).first as Map<String, dynamic>;
      expect(songJson['name'], 'JsonSong');
      expect(songJson['pages'], isA<List>());
      expect((songJson['pages'] as List).length, 2);
    });

    test('toJsonString produces valid JSON string', () async {
      final songDir = Directory('${tempDir.path}/StringSong');
      await songDir.create();
      await File('${songDir.path}/page.pdf').writeAsString('test');

      await repository.loadFromDirectory(tempDir.path);
      final jsonString = repository.toJsonString();

      final decoded = jsonDecode(jsonString);
      expect(decoded['songs'], isA<List>());
    });

    test('loadFromDirectorySync works', () async {
      final songDir = Directory('${tempDir.path}/SyncSong');
      await songDir.create();
      await File('${songDir.path}/page.pdf').writeAsString('test');

      final songs = repository.loadFromDirectorySync(tempDir.path);

      expect(songs.length, 1);
      expect(songs.first.name, 'SyncSong');
    });

    test('songs list is unmodifiable', () async {
      final songDir = Directory('${tempDir.path}/TestSong');
      await songDir.create();
      await File('${songDir.path}/page.pdf').writeAsString('test');

      await repository.loadFromDirectory(tempDir.path);
      final song = repository.songs.first;
      expect(() => repository.songs.add(song), throwsUnsupportedError);
    });

    test('handles mixed file types in same directory', () async {
      final songDir = Directory('${tempDir.path}/MixedSong');
      await songDir.create();

      await File('${songDir.path}/page1.pdf').writeAsString('test');
      await File('${songDir.path}/page2.png').writeAsString('test');
      await File('${songDir.path}/page3.svg').writeAsString('test');

      final songs = await repository.loadFromDirectory(tempDir.path);

      expect(songs.first.pageCount, 3);
      final extensions = songs.first.pages.map((p) => p.extension).toSet();
      expect(extensions, containsAll(['.pdf', '.png', '.svg']));
    });
  });
}
