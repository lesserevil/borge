import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/annotation.dart';

/// Service for persisting annotations in a local SQLite database.
class AnnotationRepository {
  static const _dbName = 'borge_annotations.db';
  static const _tableName = 'annotations';
  static const _dbVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);

    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        fileId TEXT NOT NULL,
        measureNumber INTEGER NOT NULL,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        structuredKind TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_annotations_fileId ON $_tableName (fileId)
    ''');

    await db.execute('''
      CREATE INDEX idx_annotations_measure ON $_tableName (fileId, measureNumber)
    ''');
  }

  /// Insert a new annotation.
  Future<void> insert(Annotation annotation) async {
    final db = await database;
    await db.insert(
      _tableName,
      annotation.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple annotations in a batch.
  Future<void> insertAll(List<Annotation> annotations) async {
    final db = await database;
    final batch = db.batch();
    for (final ann in annotations) {
      batch.insert(
        _tableName,
        ann.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get all annotations for a specific file.
  Future<List<Annotation>> getByFileId(String fileId) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'fileId = ?',
      whereArgs: [fileId],
      orderBy: 'createdAt ASC',
    );
    return maps.map((m) => Annotation.fromJson(m)).toList();
  }

  /// Get all annotations for a specific file and measure.
  Future<List<Annotation>> getByFileAndMeasure(
    String fileId,
    int measureNumber,
  ) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'fileId = ? AND measureNumber = ?',
      whereArgs: [fileId, measureNumber],
      orderBy: 'createdAt ASC',
    );
    return maps.map((m) => Annotation.fromJson(m)).toList();
  }

  /// Delete a specific annotation by ID.
  Future<void> delete(String id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all annotations for a specific file.
  Future<void> deleteByFileId(String fileId) async {
    final db = await database;
    await db.delete(_tableName, where: 'fileId = ?', whereArgs: [fileId]);
  }

  /// Delete all annotations for a specific file and measure.
  Future<void> deleteByFileAndMeasure(String fileId, int measureNumber) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'fileId = ? AND measureNumber = ?',
      whereArgs: [fileId, measureNumber],
    );
  }

  /// Update an existing annotation.
  Future<void> update(Annotation annotation) async {
    final db = await database;
    await db.update(
      _tableName,
      annotation.toJson(),
      where: 'id = ?',
      whereArgs: [annotation.id],
    );
  }

  /// Update annotation data (svgPath, x, y) for an existing annotation.
  Future<void> updateData(String id, String data, double x, double y) async {
    final db = await database;
    await db.update(
      _tableName,
      {'data': data, 'x': x, 'y': y},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Count annotations for a specific file.
  Future<int> countByFileId(String fileId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE fileId = ?',
      [fileId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
