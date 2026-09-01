import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/nutrition_target_repository.dart';
import 'package:jcg_fitness/core/database/water_log_repository.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';

final todayWaterProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return 0;
  final repo = WaterLogRepository(DatabaseProvider());
  final logs = await repo.queryTodayByUser(user.id);
  return logs.fold<int>(0, (sum, log) => sum + log.amountMl);
});

final waterTargetProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return 2500;
  final repo = NutritionTargetRepository(DatabaseProvider());
  final target = await repo.readActiveByUserId(user.id);
  return target?.waterTargetMl?.toInt() ?? 2500;
});

final todayWaterLogsProvider = FutureProvider<List<WaterLog>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final repo = WaterLogRepository(DatabaseProvider());
  return repo.queryTodayByUser(user.id);
});

final pastWeekWaterProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final repo = WaterLogRepository(DatabaseProvider());
  final now = DateTime.now();
  final sevenDaysAgo = now.subtract(const Duration(days: 6));
  final startDate =
      '${sevenDaysAgo.year}-${sevenDaysAgo.month.toString().padLeft(2, '0')}-${sevenDaysAgo.day.toString().padLeft(2, '0')}';
  final endDate =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final logs = await repo.queryByUserAndDateRange(user.id, startDate, endDate);

  final Map<String, int> dailyTotals = {};
  for (int i = 0; i < 7; i++) {
    final day = sevenDaysAgo.add(Duration(days: i));
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    dailyTotals[key] = 0;
  }

  for (final log in logs) {
    final date = log.loggedAt.substring(0, 10);
    if (dailyTotals.containsKey(date)) {
      dailyTotals[date] = dailyTotals[date]! + log.amountMl;
    }
  }

  return dailyTotals.entries
      .map((e) => {'date': e.key, 'total': e.value})
      .toList()
    ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
});

final hydrationHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, days) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final repo = WaterLogRepository(DatabaseProvider());
  final now = DateTime.now();
  final startDate = now.subtract(Duration(days: days - 1));
  final startStr =
      '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
  final endStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final logs = await repo.queryByUserAndDateRange(user.id, startStr, endStr);

  final Map<String, int> dailyTotals = {};
  for (int i = 0; i < days; i++) {
    final day = startDate.add(Duration(days: i));
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    dailyTotals[key] = 0;
  }

  for (final log in logs) {
    final date = log.loggedAt.substring(0, 10);
    if (dailyTotals.containsKey(date)) {
      dailyTotals[date] = dailyTotals[date]! + log.amountMl;
    }
  }

  return dailyTotals.entries
      .map((e) => {'date': e.key, 'total': e.value})
      .toList()
    ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
});

final hydrationHistoryLogsProvider =
    FutureProvider.autoDispose.family<List<WaterLog>, int>((ref, days) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final repo = WaterLogRepository(DatabaseProvider());
  final now = DateTime.now();
  final startDate = now.subtract(Duration(days: days - 1));
  final startStr =
      '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
  final endStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return repo.queryByUserAndDateRange(user.id, startStr, endStr);
});

Future<void> updateWaterTarget({
  required String userId,
  required int newTargetMl,
}) async {
  final dbProvider = DatabaseProvider();
  final targetRepo = NutritionTargetRepository(dbProvider);

  final current = await targetRepo.readActiveByUserId(userId);
  if (current == null) return;

  final updated = current.copyWith(
    waterTargetMl: newTargetMl.toDouble(),
    syncStatus: 'pending',
  );

  await targetRepo.update(updated);
}
