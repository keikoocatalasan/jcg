import 'package:sqflite/sqflite.dart';

class MigrationV3 {
  static const int version = 3;

  static Future<void> run(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(foods)');
    final names = columns.map((row) => row['name'] as String).toSet();
    if (!names.contains('description')) {
      await db.execute('ALTER TABLE foods ADD COLUMN description TEXT');
    }
  }
}
