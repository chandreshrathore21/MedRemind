import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medicine.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('medicines.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Bump version to 3 to trigger migration for isAlarm column
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        frequency TEXT NOT NULL,
        inventoryCount INTEGER NOT NULL,
        scheduleTime TEXT NOT NULL,
        skippedCount INTEGER NOT NULL DEFAULT 0,
        isAlarm INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE medicines ADD COLUMN skippedCount INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE medicines ADD COLUMN isAlarm INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<int> insertMedicine(Medicine medicine) async {
    final db = await instance.database;
    return await db.insert('medicines', medicine.toMap());
  }

  Future<List<Medicine>> getAllMedicines() async {
    final db = await instance.database;
    final result = await db.query('medicines');
    return result.map((json) => Medicine.fromMap(json)).toList();
  }

  Future<int> updateMedicine(Medicine medicine) async {
    final db = await instance.database;
    return await db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<int> deleteMedicine(int id) async {
    final db = await instance.database;
    return await db.delete(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}