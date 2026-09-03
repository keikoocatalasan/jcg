import 'package:sqflite/sqflite.dart';

class MigrationV5 {
  static const int version = 5;

  static Future<void> run(Database db) async {
    await _addMissingColumns(db, 'ai_scans', {
      'pipeline_version': "TEXT NOT NULL DEFAULT 'scanner-v2'",
      'composition_confidence': 'REAL',
      'needs_portion_input': 'INTEGER NOT NULL DEFAULT 1',
    });
    await _addMissingColumns(db, 'ai_scan_predictions', {
      'serving_grams': 'REAL',
    });

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_scan_components (
        component_id TEXT PRIMARY KEY,
        scan_id TEXT NOT NULL,
        component_order INTEGER NOT NULL,
        role_code TEXT NOT NULL,
        food_id TEXT,
        predicted_food_name TEXT NOT NULL,
        confidence REAL NOT NULL,
        alternative_names TEXT NOT NULL DEFAULT '[]',
        reference_grams REAL,
        grams REAL,
        portion_method TEXT NOT NULL DEFAULT 'not_provided',
        portion_confidence REAL,
        calories REAL,
        protein_g REAL,
        carbs_g REAL,
        fat_g REAL,
        estimated_cost_php REAL,
        is_confirmed INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (scan_id) REFERENCES ai_scans(scan_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_ai_scan_components_scan
      ON ai_scan_components(scan_id, component_order)
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_ai_scans_delete_children
      BEFORE DELETE ON ai_scans
      BEGIN
        DELETE FROM ai_scan_feedback WHERE scan_id = OLD.scan_id;
        DELETE FROM ai_scan_predictions WHERE scan_id = OLD.scan_id;
        DELETE FROM ai_scan_components WHERE scan_id = OLD.scan_id;
      END
    ''');
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
