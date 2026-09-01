import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/meal_log_repository.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';

final mealLogRepositoryProvider = Provider<MealLogRepository>((ref) {
  return MealLogRepository(ref.watch(databaseProvider));
});

final mealLogsForDateProvider =
    FutureProvider.family<List<MealLog>, String>((ref, date) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final repo = ref.watch(mealLogRepositoryProvider);
  return repo.queryByUserAndDate(user.id, date);
});

final todayMealLogsProvider = FutureProvider<List<MealLog>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final repo = ref.watch(mealLogRepositoryProvider);
  return repo.queryTodayByUser(user.id);
});

final todayCaloriesProvider = FutureProvider<int>((ref) async {
  final logs = await ref.watch(todayMealLogsProvider.future);
  int total = 0;
  for (final log in logs) {
    total += log.caloriesSnapshot.round();
  }
  return total;
});
