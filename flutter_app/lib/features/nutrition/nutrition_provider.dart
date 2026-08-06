import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/daily_target_snapshot_repository.dart';
import 'package:jcg_fitness/core/database/nutrition_target_repository.dart';
import 'package:jcg_fitness/core/database/profile_repository.dart';
import 'package:jcg_fitness/core/database/weight_log_repository.dart';
import 'package:jcg_fitness/core/models/daily_target_snapshot.dart';
import 'package:jcg_fitness/core/models/nutrition_target.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_engine.dart';

final databaseProvider = Provider<DatabaseProvider>((ref) {
  return DatabaseProvider();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(databaseProvider));
});

final weightLogRepositoryProvider = Provider<WeightLogRepository>((ref) {
  return WeightLogRepository(ref.watch(databaseProvider));
});

final nutritionTargetRepositoryProvider =
    Provider<NutritionTargetRepository>((ref) {
  return NutritionTargetRepository(ref.watch(databaseProvider));
});

final dailyTargetSnapshotRepositoryProvider =
    Provider<DailyTargetSnapshotRepository>((ref) {
  return DailyTargetSnapshotRepository(ref.watch(databaseProvider));
});

final nutritionTargetProvider =
    FutureProvider<NutritionTargetResult?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final profileRepo = ref.watch(profileRepositoryProvider);
  final weightRepo = ref.watch(weightLogRepositoryProvider);
  final targetRepo = ref.watch(nutritionTargetRepositoryProvider);
  final snapshotRepo = ref.watch(dailyTargetSnapshotRepositoryProvider);

  final profile = await profileRepo.readByUserId(user.id);
  if (profile == null) return null;

  final sexCode = profile.sexCode;
  final age = profile.age;
  final heightCm = profile.heightCm;
  final weightKg = profile.currentWeightKg;
  final activityLevelCode = profile.activityLevelCode;
  final fitnessGoalCode = profile.fitnessGoalCode;

  if (sexCode == null ||
      age == null ||
      heightCm == null ||
      weightKg == null ||
      activityLevelCode == null ||
      fitnessGoalCode == null) {
    return null;
  }

  final latestWeight = await weightRepo.readLatest(user.id);
  final effectiveWeightKg = latestWeight?.weightKg ?? weightKg;

  final existingTarget = await targetRepo.readActiveByUserId(user.id);
  if (existingTarget != null &&
      existingTarget.bmr != null &&
      existingTarget.tdee != null &&
      existingTarget.calorieTarget != null &&
      existingTarget.proteinTargetG != null &&
      existingTarget.carbsTargetG != null &&
      existingTarget.fatTargetG != null &&
      existingTarget.waterTargetMl != null) {
    return NutritionTargetResult(
      bmr: existingTarget.bmr!,
      tdee: existingTarget.tdee!,
      calorieTarget: existingTarget.calorieTarget!.round(),
      proteinG: existingTarget.proteinTargetG!,
      carbsG: existingTarget.carbsTargetG!,
      fatG: existingTarget.fatTargetG!,
      waterTargetMl: existingTarget.waterTargetMl!.round(),
    );
  }

  final result = NutritionEngine.calculateAll(
    weightKg: effectiveWeightKg,
    heightCm: heightCm,
    age: age,
    sexCode: sexCode,
    activityLevelCode: activityLevelCode,
    fitnessGoalCode: fitnessGoalCode,
  );

  final now = DateHelper.nowUtc();
  final targetId = UuidHelper.generateUuid();
  final weightLogId = latestWeight?.weightLogId;

  await targetRepo.deactivateOldTargets(user.id);

  await targetRepo.insert(NutritionTarget(
    targetId: targetId,
    userId: user.id,
    formulaVersionCode: 'mifflin_stjeor',
    fitnessGoalCode: fitnessGoalCode,
    sourceWeightLogId: weightLogId,
    bmr: result.bmr,
    tdee: result.tdee,
    calorieTarget: result.calorieTarget.toDouble(),
    proteinTargetG: result.proteinG,
    carbsTargetG: result.carbsG,
    fatTargetG: result.fatG,
    waterTargetMl: result.waterTargetMl.toDouble(),
    effectiveFrom: DateHelper.todayDate(),
    isActive: true,
    syncStatus: 'pending',
    createdAt: now,
  ));

  await snapshotRepo.upsert(DailyTargetSnapshot(
    snapshotId: UuidHelper.generateUuid(),
    userId: user.id,
    nutritionTargetId: targetId,
    targetDate: DateHelper.todayDate(),
    calorieTargetSnapshot: result.calorieTarget.toDouble(),
    proteinTargetGSnapshot: result.proteinG,
    carbsTargetGSnapshot: result.carbsG,
    fatTargetGSnapshot: result.fatG,
    waterTargetMlSnapshot: result.waterTargetMl.toDouble(),
    dailyBudgetPhpSnapshot: profile.dailyBudgetPhp,
    syncStatus: 'pending',
    createdAt: now,
  ));

  return result;
});
