import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/batch_model.dart';
import '../models/image_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('camera_sync.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL,
        batchId INTEGER NOT NULL,
        status TEXT NOT NULL,
        retryCount INTEGER NOT NULL,
        FOREIGN KEY (batchId) REFERENCES batches (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<int> insertBatch(ImageBatch batch) async {
    final db = await instance.database;
    return await db.insert('batches', batch.toMap());
  }

  Future<int> insertImage(ImageModel image) async {
    final db = await instance.database;
    return await db.insert('images', image.toMap());
  }

  Future<List<ImageBatch>> getAllBatches() async {
    final db = await instance.database;
    final result = await db.query('batches', orderBy: 'createdAt DESC');
    return result.map((json) => ImageBatch.fromMap(json)).toList();
  }

  Future<List<ImageModel>> getImagesForBatch(int batchId) async {
    final db = await instance.database;
    final result = await db.query(
      'images',
      where: 'batchId = ?',
      whereArgs: [batchId],
    );
    return result.map((json) => ImageModel.fromMap(json)).toList();
  }

  Future<List<ImageModel>> getPendingImages() async {
    final db = await instance.database;
    final result = await db.query('images', where: "status != 'synced'");
    return result.map((json) => ImageModel.fromMap(json)).toList();
  }

  Future<int> updateImageStatus(
    int id,
    String status, {
    int? retryCount,
  }) async {
    final db = await instance.database;
    final Map<String, dynamic> values = {'status': status};
    if (retryCount != null) {
      values['retryCount'] = retryCount;
    }
    return await db.update('images', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateBatchStatus(int id, String status) async {
    final db = await instance.database;
    return await db.update(
      'batches',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
