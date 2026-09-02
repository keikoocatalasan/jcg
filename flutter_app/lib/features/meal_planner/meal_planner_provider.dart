import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/database/meal_plan_repository.dart';

final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  return MealPlanRepository(DatabaseProvider());
});

final weeklyPlansProvider =
    FutureProvider.family<List<MealPlan>, String>((ref, weekStart) async {
  final userId = await ref.watch(localUserIdProvider.future);
  if (userId == null) return [];
  final repo = ref.watch(mealPlanRepositoryProvider);
  return repo.queryByUserAndWeek(userId, weekStart);
});

final plansForDateProvider =
    FutureProvider.family<List<MealPlan>, String>((ref, date) async {
  final userId = await ref.watch(localUserIdProvider.future);
  if (userId == null) return [];
  final repo = ref.watch(mealPlanRepositoryProvider);
  return repo.queryByUserAndDate(userId, date);
});
