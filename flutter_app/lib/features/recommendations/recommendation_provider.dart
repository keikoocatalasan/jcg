import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/database/recommendation_session_repository.dart';
import 'package:jcg_fitness/core/database/recommendation_item_repository.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';
import 'package:jcg_fitness/features/recommendations/recommendation_engine.dart';

final recommendationProvider = FutureProvider<List<ScoredFood>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  final profileRepo = ref.watch(profileRepositoryProvider);
  final profile = await profileRepo.readByUserId(user.id);
  if (profile == null) return [];

  final dashboardData = await ref.watch(dashboardDataProvider.future);

  final foodRepo = FoodRepository(DatabaseProvider());
  final officialFoods = await foodRepo.readActiveOfficial();
  final localFoods = await foodRepo.readByOwner(user.id);
  final allFoods = [...officialFoods, ...localFoods];

  final allergies = (profile.allergies ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final restrictions = (profile.dietaryRestrictions ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final remainingBudget =
      (dashboardData.dailyBudget - dashboardData.spentBudget)
          .clamp(0.0, double.infinity);
  final remainingCalories =
      (dashboardData.targetCalories - dashboardData.consumedCalories)
          .clamp(0, dashboardData.targetCalories);
  final remainingProtein =
      (dashboardData.targetProtein - dashboardData.consumedProtein)
          .clamp(0.0, double.infinity);
  final remainingCarbs =
      (dashboardData.targetCarbs - dashboardData.consumedCarbs)
          .clamp(0.0, double.infinity);
  final remainingFat = (dashboardData.targetFat - dashboardData.consumedFat)
      .clamp(0.0, double.infinity);

  final results = RecommendationEngine.generate(
    remainingBudget: remainingBudget,
    remainingCalories: remainingCalories,
    remainingProtein: remainingProtein,
    remainingCarbs: remainingCarbs,
    remainingFat: remainingFat,
    fitnessGoalCode: profile.fitnessGoalCode ?? 'maintenance',
    mealTypeCode: null,
    allergies: allergies,
    dietaryRestrictions: restrictions,
    availableFoods: allFoods,
  );

  await _persistSession(
    userId: user.id,
    results: results,
    remainingBudget: remainingBudget,
    remainingCalories: remainingCalories,
    remainingProtein: remainingProtein,
    remainingCarbs: remainingCarbs,
    remainingFat: remainingFat,
  );

  return results;
});

Future<void> _persistSession({
  required String userId,
  required List<ScoredFood> results,
  required double remainingBudget,
  required int remainingCalories,
  required double remainingProtein,
  required double remainingCarbs,
  required double remainingFat,
}) async {
  final dbProvider = DatabaseProvider();
  final sessionRepo = RecommendationSessionRepository(dbProvider);
  final itemRepo = RecommendationItemRepository(dbProvider);

  final now = DateHelper.nowUtc();
  final sessionId = UuidHelper.generateUuid();

  final session = RecommendationSession(
    sessionId: sessionId,
    userId: userId,
    remainingBudgetPhp: remainingBudget,
    remainingCalories: remainingCalories,
    remainingProteinG: remainingProtein,
    remainingCarbsG: remainingCarbs,
    remainingFatG: remainingFat,
    syncStatus: 'synced',
    generatedAt: now,
  );

  await sessionRepo.insert(session);

  for (var i = 0; i < results.length; i++) {
    final scored = results[i];
    final item = RecommendationItem(
      recommendationItemId: UuidHelper.generateUuid(),
      sessionId: sessionId,
      foodId: scored.food.foodId,
      linkedMealLogId: null,
      linkedMealPlanId: null,
      rankNumber: i + 1,
      finalScore: scored.finalScore,
      affordabilityScore: scored.affordabilityScore,
      proteinFitScore: scored.proteinFitScore,
      calorieFitScore: scored.calorieFitScore,
      macroBalanceScore: scored.macroBalanceScore,
      goalMatchScore: scored.goalMatchScore,
      mealTypeScore: scored.mealTypeScore,
      overBudgetPenalty: scored.overBudgetPenalty,
      reasonText: scored.reasonText,
      wasAccepted: false,
      acceptedAt: null,
      syncStatus: 'synced',
    );
    await itemRepo.insert(item);
  }
}
