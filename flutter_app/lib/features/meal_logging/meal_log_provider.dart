import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/database/meal_log_repository.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';

final mealLogRepositoryProvider = Provider<MealLogRepository>((ref) {
  return MealLogRepository(ref.watch(databaseProvider));
});

final mealLogsForDateProvider =
    FutureProvider.family<List<MealLog>, String>((ref, date) async {
  final userId = await ref.watch(localUserIdProvider.future);
  if (userId == null) return [];
  final repo = ref.watch(mealLogRepositoryProvider);
  return repo.queryByUserAndDate(userId, date);
});

final todayMealLogsProvider = FutureProvider<List<MealLog>>((ref) async {
  final userId = await ref.watch(localUserIdProvider.future);
  if (userId == null) return [];
  final repo = ref.watch(mealLogRepositoryProvider);
  return repo.queryTodayByUser(userId);
});

final todayCaloriesProvider = FutureProvider<int>((ref) async {
  final logs = await ref.watch(todayMealLogsProvider.future);
  int total = 0;
  for (final log in logs) {
    total += log.caloriesSnapshot.round();
  }
  return total;
});
