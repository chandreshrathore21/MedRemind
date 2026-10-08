import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medicine.dart';
import '../models/otc_medicine.dart';

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

    return await openDatabase(
      path,
      version: 6, // Bumped version for schema upgrades
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dosage TEXT DEFAULT '',
        frequency TEXT NOT NULL,
        inventoryCount INTEGER NOT NULL,
        scheduleTime TEXT NOT NULL,
        scheduledTime TEXT,
        skippedCount INTEGER NOT NULL DEFAULT 0,
        isAlarm INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE otc_inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        category TEXT NOT NULL,
        expiryDate TEXT
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
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS otc_inventory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          category TEXT NOT NULL,
          expiryDate TEXT
        )
      ''');
    }
    if (oldVersion < 6) {
      // Safely add missing dosage and scheduledTime columns to existing user databases
      try {
        await db.execute(
          "ALTER TABLE medicines ADD COLUMN dosage TEXT DEFAULT ''",
        );
      } catch (e) {
        // Ignore if column already exists
      }
      try {
        await db.execute(
          'ALTER TABLE medicines ADD COLUMN scheduledTime TEXT',
        );
      } catch (e) {
        // Ignore if column already exists
      }
    }
  }

  // --- Scheduled Medicines CRUD Operations ---

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

  // --- OTC Inventory CRUD Operations ---

  Future<int> insertOtcMedicine(OtcMedicine med) async {
    final db = await instance.database;
    return await db.insert('otc_inventory', med.toMap());
  }

  Future<List<OtcMedicine>> getAllOtcMedicines() async {
    final db = await instance.database;
    final result = await db.query('otc_inventory');
    return result.map((json) => OtcMedicine.fromMap(json)).toList();
  }

  Future<int> updateOtcMedicine(OtcMedicine med) async {
    final db = await instance.database;
    return await db.update(
      'otc_inventory',
      med.toMap(),
      where: 'id = ?',
      whereArgs: [med.id],
    );
  }

  Future<int> deleteOtcMedicine(int id) async {
    final db = await instance.database;
    return await db.delete(
      'otc_inventory',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Close database connection gracefully when disposing app resources
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}