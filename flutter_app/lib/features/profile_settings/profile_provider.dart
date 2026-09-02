import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/models/profile.dart';
import 'package:jcg_fitness/core/database/weight_log_repository.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_engine.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart'
    show profileRepositoryProvider;

final profileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.readByUserId(user.id);
});

class ProfileUpdate {
  final String? nickname;
  final String? fitnessGoalCode;
  final String? activityLevelCode;
  final int? age;
  final double? heightCm;
  final double? currentWeightKg;
  final double? targetWeightKg;
  final double? dailyBudgetPhp;

  const ProfileUpdate({
    this.nickname,
    this.fitnessGoalCode,
    this.activityLevelCode,
    this.age,
    this.heightCm,
    this.currentWeightKg,
    this.targetWeightKg,
    this.dailyBudgetPhp,
  });
}

final updateProfileProvider =
    FutureProvider.family<void, ProfileUpdate>((ref, update) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) throw Exception('No authenticated user');

  final profileRepo = ref.watch(profileRepositoryProvider);
  final profile = await profileRepo.readByUserId(user.id);
  if (profile == null) throw Exception('Profile not found');
  final localUserId = profile.userId;

  final now = DateHelper.nowUtc();
  final db = await DatabaseProvider().database;
  final sequence = DateTime.now().millisecondsSinceEpoch;
  final operationId = UuidHelper.generateUuid();

  final updateMap = <String, dynamic>{
    'sync_status': 'pending',
    'updated_at': now,
  };
  if (update.nickname != null) updateMap['nickname'] = update.nickname;
  if (update.fitnessGoalCode != null)
    updateMap['fitness_goal_code'] = update.fitnessGoalCode;
  if (update.activityLevelCode != null)
    updateMap['activity_level_code'] = update.activityLevelCode;
  if (update.age != null) updateMap['age'] = update.age;
  if (update.heightCm != null) updateMap['height_cm'] = update.heightCm;
  if (update.currentWeightKg != null)
    updateMap['current_weight_kg'] = update.currentWeightKg;
  if (update.targetWeightKg != null)
    updateMap['target_weight_kg'] = update.targetWeightKg;
  if (update.dailyBudgetPhp != null)
    updateMap['daily_budget_php'] = update.dailyBudgetPhp;

  final weightChanged = update.currentWeightKg != null &&
      update.currentWeightKg != profile.currentWeightKg;
  final nutritionInputsChanged = weightChanged ||
      update.fitnessGoalCode != null ||
      update.activityLevelCode != null ||
      update.age != null ||
      update.heightCm != null;

  await db.transaction((txn) async {
    await txn.update(
      'profiles',
      updateMap,
      where: 'auth_user_id = ?',
      whereArgs: [user.id],
    );
    await txn.insert('sync_queue', {
      'sync_queue_id': UuidHelper.generateUuid(),
      'user_id': localUserId,
      'operation_id': operationId,
      'entity_type_code': 'profile',
      'entity_id': localUserId,
      'operation_code': 'update',
      'payload_json': jsonEncode(updateMap),
      'changed_fields_json': updateMap.keys.join(','),
      'client_sequence': sequence,
      'attempt_count': 0,
      'sync_status': 'pending',
      'created_at': now,
    });
  });

  if (nutritionInputsChanged &&
      weightChanged &&
      update.currentWeightKg != null) {
    final sexCode = profile.sexCode ?? 'male';
    final age = update.age ?? profile.age ?? 25;
    final heightCm = update.heightCm ?? profile.heightCm ?? 170;
    final activityLevelCode =
        update.activityLevelCode ?? profile.activityLevelCode ?? 'moderate';
    final fitnessGoalCode =
        update.fitnessGoalCode ?? profile.fitnessGoalCode ?? 'maintenance';
    final weightKg = update.currentWeightKg!;

    final result = NutritionEngine.calculateAll(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      sexCode: sexCode,
      activityLevelCode: activityLevelCode,
      fitnessGoalCode: fitnessGoalCode,
    );

    final weightLogId = UuidHelper.generateUuid();
    final targetId = UuidHelper.generateUuid();
    final snapshotId = UuidHelper.generateUuid();

    final helper = LocalTransactionHelper(DatabaseProvider());
    await helper.saveWeightLogAndRecalculate(
      weightLogData: {
        'weight_log_id': weightLogId,
        'user_id': localUserId,
        'weight_kg': weightKg,
        'logged_at': now,
      },
      newTargetData: {
        'target_id': targetId,
        'formula_version_code': 'mifflin_stjeor',
        'fitness_goal_code': fitnessGoalCode,
        'source_weight_log_id': weightLogId,
        'bmr': result.bmr,
        'tdee': result.tdee,
        'calorie_target': result.calorieTarget.toDouble(),
        'protein_target_g': result.proteinG,
        'carbs_target_g': result.carbsG,
        'fat_target_g': result.fatG,
        'water_target_ml': result.waterTargetMl.toDouble(),
        'effective_from': DateHelper.todayDate(),
      },
      dailySnapshotData: {
        'snapshot_id': snapshotId,
        'nutrition_target_id': targetId,
        'target_date': DateHelper.todayDate(),
        'calorie_target_snapshot': result.calorieTarget.toDouble(),
        'protein_target_g_snapshot': result.proteinG,
        'carbs_target_g_snapshot': result.carbsG,
        'fat_target_g_snapshot': result.fatG,
        'water_target_ml_snapshot': result.waterTargetMl.toDouble(),
        'daily_budget_php_snapshot':
            update.dailyBudgetPhp ?? profile.dailyBudgetPhp,
      },
    );
  } else if (nutritionInputsChanged) {
    final latestWeight =
        await WeightLogRepository(DatabaseProvider()).readLatest(localUserId);
    final weightKg = latestWeight?.weightKg ?? profile.currentWeightKg;
    final sexCode = profile.sexCode ?? 'male';
    final age = update.age ?? profile.age ?? 25;
    final heightCm = update.heightCm ?? profile.heightCm ?? 170;
    final activityLevelCode =
        update.activityLevelCode ?? profile.activityLevelCode ?? 'moderate';
    final fitnessGoalCode =
        update.fitnessGoalCode ?? profile.fitnessGoalCode ?? 'maintenance';

    if (weightKg != null) {
      final result = NutritionEngine.calculateAll(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        sexCode: sexCode,
        activityLevelCode: activityLevelCode,
        fitnessGoalCode: fitnessGoalCode,
      );
      final today = DateHelper.todayDate();
      final targetId = UuidHelper.generateUuid();
      final snapshotId = UuidHelper.generateUuid();
      await LocalTransactionHelper(DatabaseProvider())
          .recalculateNutritionTarget(
        userId: localUserId,
        newTargetData: {
          'target_id': targetId,
          'formula_version_code': 'mifflin_stjeor',
          'fitness_goal_code': fitnessGoalCode,
          'source_weight_log_id': latestWeight?.weightLogId,
          'bmr': result.bmr,
          'tdee': result.tdee,
          'calorie_target': result.calorieTarget.toDouble(),
          'protein_target_g': result.proteinG,
          'carbs_target_g': result.carbsG,
          'fat_target_g': result.fatG,
          'water_target_ml': result.waterTargetMl.toDouble(),
          'effective_from': today,
        },
        dailySnapshotData: {
          'snapshot_id': snapshotId,
          'nutrition_target_id': targetId,
          'target_date': today,
          'calorie_target_snapshot': result.calorieTarget.toDouble(),
          'protein_target_g_snapshot': result.proteinG,
          'carbs_target_g_snapshot': result.carbsG,
          'fat_target_g_snapshot': result.fatG,
          'water_target_ml_snapshot': result.waterTargetMl.toDouble(),
          'daily_budget_php_snapshot':
              update.dailyBudgetPhp ?? profile.dailyBudgetPhp,
        },
      );
    }
  }
});
