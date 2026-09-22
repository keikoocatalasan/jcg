import 'package:sqflite/sqflite.dart';

class MigrationV6 {
  static const int version = 6;

  static Future<void> run(Database db) async {
    await _addMissingColumns(db, 'foods', {
      'verification_status': 'TEXT',
      'verified_at': 'TEXT',
      'nutrition_source_type': 'TEXT',
      'nutrition_source_name': 'TEXT',
      'source_checked_at': 'TEXT',
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
