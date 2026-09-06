import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/medicine.dart';

class DatabaseHelper {
  static const _databaseName = "medremind.db";
  static const _databaseVersion = 4; // Bumped version to force schema refresh

  static const tableMedicines = 'medicines';

  static const columnId = 'id';
  static const columnName = 'name';
  static const columnFrequency = 'frequency';
  static const columnInventoryCount = 'inventoryCount';
  static const columnScheduleTime = 'scheduleTime';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableMedicines (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnName TEXT NOT NULL,
        $columnFrequency TEXT NOT NULL,
        $columnInventoryCount INTEGER NOT NULL,
        $columnScheduleTime TEXT NOT NULL
      )
    ''');
    print('--> DB DEBUG: Table created successfully');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS $tableMedicines');
    await _onCreate(db, newVersion);
  }

  // INSERT MEDICINE
  Future<int> insertMedicine(Medicine medicine) async {
    Database db = await instance.database;
    int id = await db.insert(tableMedicines, medicine.toMap());
    print('--> DB DEBUG: Inserted record with ID: $id');
    return id;
  }

  // GET ALL MEDICINES
  Future<List<Medicine>> getAllMedicines() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableMedicines);
    print('--> DB DEBUG: Query returned ${maps.length} records');
    return List.generate(maps.length, (i) => Medicine.fromMap(maps[i]));
  }

  // UPDATE MEDICINE
  Future<int> updateMedicine(Medicine medicine) async {
    Database db = await instance.database;
    return await db.update(
      tableMedicines,
      medicine.toMap(),
      where: '$columnId = ?',
      whereArgs: [medicine.id],
    );
  }

  // DECREMENT STOCK
  Future<int> decrementStock(int id) async {
    Database db = await instance.database;
    return await db.rawUpdate('''
      UPDATE $tableMedicines 
      SET $columnInventoryCount = CASE 
        WHEN $columnInventoryCount > 0 THEN $columnInventoryCount - 1 
        ELSE 0 
      END 
      WHERE $columnId = ?
    ''', [id]);
  }

  // DELETE MEDICINE
  Future<int> deleteMedicine(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableMedicines,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
}