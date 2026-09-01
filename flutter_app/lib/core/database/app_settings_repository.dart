import 'package:sqflite/sqflite.dart';
import 'database_provider.dart';

class AppSettingsRepository {
  final DatabaseProvider _dbProvider;

  AppSettingsRepository(this._dbProvider);

  String get tableName => 'app_settings';

  Future<Database> get database => _dbProvider.database;

  Future<String?> get(String key) async {
    final db = await database;
    final results = await db.query(
      tableName,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final db = await database;
    await db.insert(
      tableName,
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getAll() async {
    final db = await database;
    final results = await db.query(tableName);
    final map = <String, String>{};
    for (final row in results) {
      map[row['key'] as String] = row['value'] as String;
    }
    return map;
  }
}
