import 'package:sqflite/sqflite.dart';

class MigrationV2 {
  static const int version = 2;

  static Future<void> run(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(ai_scan_feedback)');
    final names = columns.map((row) => row['name'] as String).toSet();

    final additions = <String, String>{
      'client_scan_id': 'TEXT',
      'selected_food_id': 'TEXT',
      'was_helpful': 'INTEGER',
      'feedback_text': 'TEXT',
      'created_at': 'TEXT',
    };
    for (final entry in additions.entries) {
      if (!names.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE ai_scan_feedback ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
    await db.execute(
      "UPDATE ai_scan_feedback SET created_at = COALESCE(created_at, confirmed_at, datetime('now'))",
    );
  }
}
