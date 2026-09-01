import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'migration_v1.dart';
import 'migration_v2.dart';
import 'migration_v3.dart';
import 'migration_v4.dart';

class DatabaseProvider {
  static final DatabaseProvider _instance = DatabaseProvider._internal();
  factory DatabaseProvider() => _instance;
  DatabaseProvider._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'jcg_fitness.db');

    return openDatabase(
      path,
      version: MigrationV4.version,
      onCreate: (db, version) async {
        final batch = db.batch();
        await MigrationV1.run(batch);
        await batch.commit(noResult: true);
        await MigrationV2.run(db);
        await MigrationV3.run(db);
        await MigrationV4.run(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < MigrationV2.version) {
          await MigrationV2.run(db);
        }
        if (oldVersion < MigrationV3.version) {
          await MigrationV3.run(db);
        }
        if (oldVersion < MigrationV4.version) {
          await MigrationV4.run(db);
        }
      },
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA foreign_keys = ON');
        await db.rawQuery('PRAGMA journal_mode = WAL');
      },
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }

  Future<void> clearCache() async {
    final db = await database;
    await db.delete('community_cache');
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.execute('PRAGMA writable_schema = ON');
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'");
    for (final table in tables) {
      final name = table['name'] as String;
      await db.delete(name);
    }
  }
}
