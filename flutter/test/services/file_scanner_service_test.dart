import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:borge/services/file_scanner_service.dart';

void main() {
  group('FileScannerService', () {
    late FileScannerService service;
    late Directory tempDir;

    setUp(() async {
      service = FileScannerService();
      tempDir = await Directory.systemTemp.createTemp('borge_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('scanDirectory returns empty list for empty directory', () async {
      final files = await service.scanDirectory(tempDir.path);
      expect(files, isEmpty);
    });

    test('scanDirectory finds PDF files', () async {
      await File('${tempDir.path}/song.pdf').writeAsString('test');

      final files = await service.scanDirectory(tempDir.path);

      expect(files.length, 1);
      expect(files.first.name, 'song.pdf');
      expect(files.first.extension, '.pdf');
    });

    test('scanDirectory finds PNG files', () async {
      await File('${tempDir.path}/page.png').writeAsString('test');

      final files = await service.scanDirectory(tempDir.path);

      expect(files.length, 1);
      expect(files.first.extension, '.png');
    });

    test('scanDirectory finds SVG files', () async {
      await File('${tempDir.path}/sheet.svg').writeAsString('test');

      final files = await service.scanDirectory(tempDir.path);

      expect(files.length, 1);
      expect(files.first.extension, '.svg');
    });

    test('scanDirectory finds MusicXML files', () async {
      await File('${tempDir.path}/score.musicxml').writeAsString('test');

      final files = await service.scanDirectory(tempDir.path);

      expect(files.length, 1);
      expect(files.first.extension, '.musicxml');
    });

    test('scanDirectory ignores unsupported file types', () async {
      await File('${tempDir.path}/song.pdf').writeAsString('test');
      await File('${tempDir.path}/readme.txt').writeAsString('test');
      await File('${tempDir.path}/image.jpg').writeAsString('test');
      await File('${tempDir.path}/doc.docx').writeAsString('test');

      final files = await service.scanDirectory(tempDir.path);

      expect(files.length, 1);
      expect(files.first.name, 'song.pdf');
    });

    test('scanDirectory finds files recursively', () async {
      final subDir = Directory('${tempDir.path}/subdir');
      await subDir.create();
      await File('${tempDir.path}/root.pdf').writeAsString('test');
      await File('${subDir.path}/nested.pdf').writeAsString('test');

      final files = await service.scanDirectory(tempDir.path);

      expect(files.length, 2);
      final names = files.map((f) => f.name).toSet();
      expect(names, containsAll(['root.pdf', 'nested.pdf']));
    });

    test('scanDirectory returns sorted results', () async {
      await File('${tempDir.path}/zebra.pdf').writeAsString('test');
      await File('${tempDir.path}/alpha.pdf').writeAsString('test');
      await File('${tempDir.path}/middle.pdf').writeAsString('test');

      final files = await service.scanDirectory(tempDir.path);

      expect(files.length, 3);
      expect(files[0].name, 'alpha.pdf');
      expect(files[1].name, 'middle.pdf');
      expect(files[2].name, 'zebra.pdf');
    });

    test('scanDirectory captures file size', () async {
      final content = 'x' * 100;
      await File('${tempDir.path}/sized.pdf').writeAsString(content);

      final files = await service.scanDirectory(tempDir.path);

      expect(files.first.sizeBytes, 100);
    });

    test('scanDirectory throws for non-existent directory', () async {
      expect(
        () => service.scanDirectory('/nonexistent/path/12345'),
        throwsA(isA<FileScanException>()),
      );
    });

    test('scanDirectorySync works synchronously', () async {
      await File('${tempDir.path}/sync.pdf').writeAsString('test');

      final files = service.scanDirectorySync(tempDir.path);

      expect(files.length, 1);
      expect(files.first.name, 'sync.pdf');
    });

    test('scanDirectorySync throws for non-existent directory', () {
      expect(
        () => service.scanDirectorySync('/nonexistent/path/12345'),
        throwsA(isA<FileScanException>()),
      );
    });

    test('handles uppercase extensions', () async {
      await File('${tempDir.path}/upper.PDF').writeAsString('test');
      await File('${tempDir.path}/mixed.Pdf').writeAsString('test');

      final files = await service.scanDirectory(tempDir.path);

      expect(files.length, 2);
      expect(files.every((f) => f.extension == '.pdf'), true);
    });
  });
}
