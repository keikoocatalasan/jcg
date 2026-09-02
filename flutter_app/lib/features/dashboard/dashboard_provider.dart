import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/meal_log_repository.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/database/water_log_repository.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/meal_logging/meal_log_provider.dart'
    show mealLogRepositoryProvider;
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';

final waterLogRepositoryProvider = Provider<WaterLogRepository>((ref) {
  return WaterLogRepository(ref.watch(databaseProvider));
});

class DashboardData {
  final int consumedCalories;
  final int targetCalories;
  final double consumedProtein;
  final double targetProtein;
  final double consumedCarbs;
  final double targetCarbs;
  final double consumedFat;
  final double targetFat;
  final double spentBudget;
  final double dailyBudget;
  final int waterMl;
  final int waterTargetMl;
  final double? latestWeight;
  final List<MealLog> recentLogs;
  final bool isOverBudget;
  final bool isOverCalories;
  final bool hasTarget;

  const DashboardData({
    required this.consumedCalories,
    required this.targetCalories,
    required this.consumedProtein,
    required this.targetProtein,
    required this.consumedCarbs,
    required this.targetCarbs,
    required this.consumedFat,
    required this.targetFat,
    required this.spentBudget,
    required this.dailyBudget,
    required this.waterMl,
    required this.waterTargetMl,
    this.latestWeight,
    required this.recentLogs,
    required this.isOverBudget,
    required this.isOverCalories,
    required this.hasTarget,
  });
}

final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) {
    return const DashboardData(
      consumedCalories: 0,
      targetCalories: 0,
      consumedProtein: 0,
      targetProtein: 0,
      consumedCarbs: 0,
      targetCarbs: 0,
      consumedFat: 0,
      targetFat: 0,
      spentBudget: 0,
      dailyBudget: 0,
      waterMl: 0,
      waterTargetMl: 0,
      recentLogs: [],
      isOverBudget: false,
      isOverCalories: false,
      hasTarget: false,
    );
  }
  final userId = await ref.watch(localUserIdProvider.future) ?? authUser.id;

  final mealRepo = ref.watch(mealLogRepositoryProvider);
  final waterRepo = ref.watch(waterLogRepositoryProvider);
  final weightRepo = ref.watch(weightLogRepositoryProvider);
  final targetRepo = ref.watch(nutritionTargetRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);

  final today = DateHelper.todayDate();

  final meals = await mealRepo.queryByUserAndDate(userId, today);
  final waterLogs = await waterRepo.queryByUserAndDate(userId, today);
  final latestWeight = await weightRepo.readLatest(userId);
  final target = await targetRepo.readActiveByUserId(userId);
  final profile = await profileRepo.readByUserId(authUser.id);

  final consumedCalories =
      meals.fold<int>(0, (sum, m) => sum + m.caloriesSnapshot.round());
  final consumedProtein =
      meals.fold<double>(0, (sum, m) => sum + m.proteinGsnapshot);
  final consumedCarbs =
      meals.fold<double>(0, (sum, m) => sum + m.carbsGsnapshot);
  final consumedFat = meals.fold<double>(0, (sum, m) => sum + m.fatGsnapshot);

  final spentBudget =
      meals.fold<double>(0, (sum, m) => sum + m.costPhpSnapshot);

  final waterMl = waterLogs.fold<int>(0, (sum, w) => sum + w.amountMl);

  final hasTarget = target != null && target.calorieTarget != null;
  final targetCalories = target?.calorieTarget?.round() ?? 0;
  final targetProtein = target?.proteinTargetG ?? 0;
  final targetCarbs = target?.carbsTargetG ?? 0;
  final targetFat = target?.fatTargetG ?? 0;
  final waterTargetMl = target?.waterTargetMl?.round() ?? 0;
  final dailyBudget = profile?.dailyBudgetPhp ?? 0;

  meals.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
  final recentLogs = meals.take(5).toList();

  return DashboardData(
    consumedCalories: consumedCalories,
    targetCalories: targetCalories,
    consumedProtein: consumedProtein,
    targetProtein: targetProtein,
    consumedCarbs: consumedCarbs,
    targetCarbs: targetCarbs,
    consumedFat: consumedFat,
    targetFat: targetFat,
    spentBudget: spentBudget,
    dailyBudget: dailyBudget,
    waterMl: waterMl,
    waterTargetMl: waterTargetMl,
    latestWeight: latestWeight?.weightKg,
    recentLogs: recentLogs,
    isOverBudget: dailyBudget > 0 && spentBudget > dailyBudget,
    isOverCalories: targetCalories > 0 && consumedCalories > targetCalories,
    hasTarget: hasTarget,
  );
});
