import 'package:sqflite/sqflite.dart';

class MigrationV4 {
  static const int version = 4;

  static Future<void> run(Database db) async {
    await _addMissingColumns(db, 'foods', {
      'meal_type_codes': "TEXT NOT NULL DEFAULT ''",
    });
    await _addMissingColumns(db, 'recommendation_sessions', {
      'meal_type_code': 'TEXT',
      'fitness_goal_code': 'TEXT',
      'minimum_price_php': 'REAL',
      'maximum_price_php': 'REAL',
    });
  }

  static Future<void> _addMissingColumns(
    Database db,
    String table,
    Map<String, String> additions,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final names = columns.map((row) => row['name'] as String).toSet();
    for (final entry in additions.entries) {
      if (!names.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
  }
}
