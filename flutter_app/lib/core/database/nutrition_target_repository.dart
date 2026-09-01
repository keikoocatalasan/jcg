import '../models/nutrition_target.dart';
import 'base_repository.dart';

class NutritionTargetRepository extends BaseRepository<NutritionTarget> {
  NutritionTargetRepository(super.dbProvider);

  @override
  String get tableName => 'nutrition_targets';

  @override
  String get pkColumn => 'target_id';

  @override
  NutritionTarget fromMap(Map<String, dynamic> map) {
    return NutritionTarget(
      targetId: map['target_id'] as String,
      userId: map['user_id'] as String,
      formulaVersionCode: map['formula_version_code'] as String?,
      fitnessGoalCode: map['fitness_goal_code'] as String?,
      sourceWeightLogId: map['source_weight_log_id'] as String?,
      bmr: (map['bmr'] as num?)?.toDouble(),
      tdee: (map['tdee'] as num?)?.toDouble(),
      calorieTarget: (map['calorie_target'] as num?)?.toDouble(),
      proteinTargetG: (map['protein_target_g'] as num?)?.toDouble(),
      carbsTargetG: (map['carbs_target_g'] as num?)?.toDouble(),
      fatTargetG: (map['fat_target_g'] as num?)?.toDouble(),
      waterTargetMl: (map['water_target_ml'] as num?)?.toDouble(),
      dailyBudgetPhp: (map['daily_budget_php'] as num?)?.toDouble(),
      effectiveFrom: map['effective_from'] as String?,
      effectiveTo: map['effective_to'] as String?,
      isActive: (map['is_active'] as int) == 1,
      syncStatus: map['sync_status'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap(NutritionTarget entity) {
    return {
      'target_id': entity.targetId,
      'user_id': entity.userId,
      'formula_version_code': entity.formulaVersionCode,
      'fitness_goal_code': entity.fitnessGoalCode,
      'source_weight_log_id': entity.sourceWeightLogId,
      'bmr': entity.bmr,
      'tdee': entity.tdee,
      'calorie_target': entity.calorieTarget,
      'protein_target_g': entity.proteinTargetG,
      'carbs_target_g': entity.carbsTargetG,
      'fat_target_g': entity.fatTargetG,
      'water_target_ml': entity.waterTargetMl,
      'daily_budget_php': entity.dailyBudgetPhp,
      'effective_from': entity.effectiveFrom,
      'effective_to': entity.effectiveTo,
      'is_active': entity.isActive ? 1 : 0,
      'sync_status': entity.syncStatus,
      'created_at': entity.createdAt,
    };
  }

  Future<NutritionTarget?> readActiveByUserId(String userId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return fromMap(results.first);
  }

  Future<int> deactivateOldTargets(String userId) async {
    final db = await database;
    return db.update(
      tableName,
      {'is_active': 0},
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
    );
  }
}
