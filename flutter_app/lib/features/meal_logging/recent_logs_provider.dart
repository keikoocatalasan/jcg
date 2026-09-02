import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/database/meal_log_repository.dart';
import 'package:jcg_fitness/core/database/water_log_repository.dart';
import 'package:jcg_fitness/core/database/weight_log_repository.dart';

enum LogEntryType { meal, water, weight }

enum LogFilter { all, meals, water, weight }

class LogEntry {
  final String id;
  final LogEntryType type;
  final String title;
  final String? subtitle;
  final String amount;
  final String amountUnit;
  final DateTime loggedAt;
  final String mealTypeCode;

  LogEntry({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.amount,
    required this.amountUnit,
    required this.loggedAt,
    this.mealTypeCode = '',
  });
}

class DaySummary {
  final int totalCalories;
  final int totalWaterMl;
  final List<LogEntry> entries;

  DaySummary({
    required this.totalCalories,
    required this.totalWaterMl,
    required this.entries,
  });
}

final recentLogsProvider = FutureProvider<Map<String, DaySummary>>((ref) async {
  final userId = await ref.watch(localUserIdProvider.future);
  if (userId == null) return {};

  final mealRepo = MealLogRepository(DatabaseProvider());
  final waterRepo = WaterLogRepository(DatabaseProvider());
  final weightRepo = WeightLogRepository(DatabaseProvider());

  final now = DateTime.now();
  final today =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final yesterday = now.subtract(const Duration(days: 1));
  final yesterdayStr =
      '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

  final todayMeals = await mealRepo.queryByUserAndDate(userId, today);
  final yesterdayMeals =
      await mealRepo.queryByUserAndDate(userId, yesterdayStr);
  final todayWater = await waterRepo.queryByUserAndDate(userId, today);
  final yesterdayWater =
      await waterRepo.queryByUserAndDate(userId, yesterdayStr);
  final todayWeight = await weightRepo.queryByUserAndDate(userId, today);
  final yesterdayWeight =
      await weightRepo.queryByUserAndDate(userId, yesterdayStr);

  final result = <String, DaySummary>{};

  result['today'] = _buildDaySummary(
    todayMeals,
    todayWater,
    todayWeight,
  );

  result['yesterday'] = _buildDaySummary(
    yesterdayMeals,
    yesterdayWater,
    yesterdayWeight,
  );

  return result;
});

DaySummary _buildDaySummary(
  List<MealLog> meals,
  List<WaterLog> waterLogs,
  List<WeightLog> weightLogs,
) {
  final entries = <LogEntry>[];
  int totalCalories = 0;
  int totalWaterMl = 0;

  for (final meal in meals) {
    totalCalories += meal.caloriesSnapshot.round();
    entries.add(LogEntry(
      id: meal.mealLogId,
      type: LogEntryType.meal,
      title: _mealTypeName(meal.mealTypeCode),
      subtitle: meal.foodNameSnapshot,
      amount: meal.caloriesSnapshot.round().toString(),
      amountUnit: 'kcal',
      loggedAt: DateTime.parse(meal.loggedAt).toLocal(),
      mealTypeCode: meal.mealTypeCode,
    ));
  }

  for (final water in waterLogs) {
    totalWaterMl += water.amountMl;
    entries.add(LogEntry(
      id: water.waterLogId,
      type: LogEntryType.water,
      title: 'Water',
      subtitle: 'Total ${(water.amountMl / 250).round()} glasses',
      amount: '${water.amountMl}',
      amountUnit: 'ml',
      loggedAt: DateTime.parse(water.loggedAt).toLocal(),
    ));
  }

  for (final weight in weightLogs) {
    entries.add(LogEntry(
      id: weight.weightLogId,
      type: LogEntryType.weight,
      title: 'Weight',
      subtitle: '${weight.weightKg} kg',
      amount: '${weight.weightKg}',
      amountUnit: 'kg',
      loggedAt: DateTime.parse(weight.loggedAt).toLocal(),
    ));
  }

  entries.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

  return DaySummary(
    totalCalories: totalCalories,
    totalWaterMl: totalWaterMl,
    entries: entries,
  );
}

String _mealTypeName(String code) {
  switch (code) {
    case 'breakfast':
      return 'Breakfast';
    case 'lunch':
      return 'Lunch';
    case 'dinner':
      return 'Dinner';
    case 'snack':
      return 'Snack';
    case 'pre_workout':
      return 'Pre-Workout';
    case 'post_workout':
      return 'Post-Workout';
    default:
      return code.replaceAll('_', ' ');
  }
}
