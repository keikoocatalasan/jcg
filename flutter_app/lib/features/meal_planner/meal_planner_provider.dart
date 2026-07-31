import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/meal_plan_repository.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';

final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  return MealPlanRepository(DatabaseProvider());
});

final weeklyPlansProvider =
    FutureProvider.family<List<MealPlan>, String>((ref, weekStart) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final repo = ref.watch(mealPlanRepositoryProvider);
  return repo.queryByUserAndWeek(user.id, weekStart);
});

final plansForDateProvider =
    FutureProvider.family<List<MealPlan>, String>((ref, date) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final repo = ref.watch(mealPlanRepositoryProvider);
  return repo.queryByUserAndDate(user.id, date);
});
