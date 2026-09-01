import '../models/daily_target_snapshot.dart';
import 'base_repository.dart';

class DailyTargetSnapshotRepository
    extends BaseRepository<DailyTargetSnapshot> {
  DailyTargetSnapshotRepository(super.dbProvider);

  @override
  String get tableName => 'daily_target_snapshots';

  @override
  String get pkColumn => 'snapshot_id';

  @override
  DailyTargetSnapshot fromMap(Map<String, dynamic> map) {
    return DailyTargetSnapshot(
      snapshotId: map['snapshot_id'] as String,
      userId: map['user_id'] as String,
      nutritionTargetId: map['nutrition_target_id'] as String,
      targetDate: map['target_date'] as String,
      calorieTargetSnapshot:
          (map['calorie_target_snapshot'] as num?)?.toDouble(),
      proteinTargetGSnapshot:
          (map['protein_target_g_snapshot'] as num?)?.toDouble(),
      carbsTargetGSnapshot:
          (map['carbs_target_g_snapshot'] as num?)?.toDouble(),
      fatTargetGSnapshot: (map['fat_target_g_snapshot'] as num?)?.toDouble(),
      waterTargetMlSnapshot:
          (map['water_target_ml_snapshot'] as num?)?.toDouble(),
      dailyBudgetPhpSnapshot:
          (map['daily_budget_php_snapshot'] as num?)?.toDouble(),
      syncStatus: map['sync_status'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap(DailyTargetSnapshot entity) {
    return {
      'snapshot_id': entity.snapshotId,
      'user_id': entity.userId,
      'nutrition_target_id': entity.nutritionTargetId,
      'target_date': entity.targetDate,
      'calorie_target_snapshot': entity.calorieTargetSnapshot,
      'protein_target_g_snapshot': entity.proteinTargetGSnapshot,
      'carbs_target_g_snapshot': entity.carbsTargetGSnapshot,
      'fat_target_g_snapshot': entity.fatTargetGSnapshot,
      'water_target_ml_snapshot': entity.waterTargetMlSnapshot,
      'daily_budget_php_snapshot': entity.dailyBudgetPhpSnapshot,
      'sync_status': entity.syncStatus,
      'created_at': entity.createdAt,
    };
  }

  Future<DailyTargetSnapshot?> readByUserAndDate(
      String userId, String date) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'user_id = ? AND target_date = ?',
      whereArgs: [userId, date],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return fromMap(results.first);
  }

  Future<void> upsert(DailyTargetSnapshot snapshot) async {
    final db = await database;
    await db.execute(
      '''INSERT OR REPLACE INTO $tableName (
        snapshot_id, user_id, nutrition_target_id, target_date,
        calorie_target_snapshot, protein_target_g_snapshot, carbs_target_g_snapshot,
        fat_target_g_snapshot, water_target_ml_snapshot, daily_budget_php_snapshot,
        sync_status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        snapshot.snapshotId,
        snapshot.userId,
        snapshot.nutritionTargetId,
        snapshot.targetDate,
        snapshot.calorieTargetSnapshot,
        snapshot.proteinTargetGSnapshot,
        snapshot.carbsTargetGSnapshot,
        snapshot.fatTargetGSnapshot,
        snapshot.waterTargetMlSnapshot,
        snapshot.dailyBudgetPhpSnapshot,
        snapshot.syncStatus,
        snapshot.createdAt,
      ],
    );
  }
}
