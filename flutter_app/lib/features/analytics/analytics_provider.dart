import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/daily_target_snapshot_repository.dart';
import 'package:jcg_fitness/core/database/meal_log_repository.dart';
import 'package:jcg_fitness/core/database/water_log_repository.dart';
import 'package:jcg_fitness/core/database/weight_log_repository.dart';
import 'package:jcg_fitness/core/models/daily_target_snapshot.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';

class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange({required this.start, required this.end});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

class DailyAnalytics {
  final String date;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalSpending;
  final int totalWaterMl;
  final double? calorieTarget;
  final double? proteinTarget;
  final double? carbsTarget;
  final double? fatTarget;
  final double? waterTargetMl;
  final double? budgetPhp;

  const DailyAnalytics({
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalSpending,
    required this.totalWaterMl,
    this.calorieTarget,
    this.proteinTarget,
    this.carbsTarget,
    this.fatTarget,
    this.waterTargetMl,
    this.budgetPhp,
  });
}

class AnalyticsData {
  final List<DailyAnalytics> dailyData;
  final double totalSpending;
  final double averageDailyCalories;
  final double weightChange;
  final double? startWeight;
  final double? endWeight;
  final double averageMacroProteinPercent;
  final double averageMacroCarbsPercent;
  final double averageMacroFatPercent;
  final double averageCalorieAdherencePercent;
  final double averageHydrationAdherencePercent;
  final double averageBudgetAdherencePercent;
  final List<MealLog> recentLogs;
  final List<WeightLog> weightLogs;

  const AnalyticsData({
    required this.dailyData,
    required this.totalSpending,
    required this.averageDailyCalories,
    required this.weightChange,
    this.startWeight,
    this.endWeight,
    required this.averageMacroProteinPercent,
    required this.averageMacroCarbsPercent,
    required this.averageMacroFatPercent,
    required this.averageCalorieAdherencePercent,
    required this.averageHydrationAdherencePercent,
    required this.averageBudgetAdherencePercent,
    required this.recentLogs,
    required this.weightLogs,
  });

  bool get hasData => dailyData.isNotEmpty;
}

final analyticsMealLogRepositoryProvider = Provider<MealLogRepository>((ref) {
  return MealLogRepository(ref.watch(databaseProvider));
});

final analyticsWaterLogRepositoryProvider = Provider<WaterLogRepository>((ref) {
  return WaterLogRepository(ref.watch(databaseProvider));
});

final analyticsWeightLogRepositoryProvider =
    Provider<WeightLogRepository>((ref) {
  return WeightLogRepository(ref.watch(databaseProvider));
});

final analyticsSnapshotRepositoryProvider =
    Provider<DailyTargetSnapshotRepository>((ref) {
  return DailyTargetSnapshotRepository(ref.watch(databaseProvider));
});

final analyticsDataProvider =
    FutureProvider.family<AnalyticsData, DateRange>((ref, range) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return const AnalyticsData(
      dailyData: [],
      totalSpending: 0,
      averageDailyCalories: 0,
      weightChange: 0,
      averageMacroProteinPercent: 0,
      averageMacroCarbsPercent: 0,
      averageMacroFatPercent: 0,
      averageCalorieAdherencePercent: 0,
      averageHydrationAdherencePercent: 0,
      averageBudgetAdherencePercent: 0,
      recentLogs: [],
      weightLogs: [],
    );
  }

  final mealRepo = ref.watch(analyticsMealLogRepositoryProvider);
  final waterRepo = ref.watch(analyticsWaterLogRepositoryProvider);
  final weightRepo = ref.watch(analyticsWeightLogRepositoryProvider);
  final snapshotRepo = ref.watch(analyticsSnapshotRepositoryProvider);

  final startStr =
      '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}';
  final endStr =
      '${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}';

  final meals =
      await mealRepo.queryByUserAndDateRange(user.id, startStr, endStr);
  final waterLogs =
      await waterRepo.queryByUserAndDateRange(user.id, startStr, endStr);
  final weightLogs =
      await weightRepo.queryByUserAndDateRange(user.id, startStr, endStr);

  final dates = <String>[];
  var current = DateTime(range.start.year, range.start.month, range.start.day);
  final endDate = DateTime(range.end.year, range.end.month, range.end.day);
  while (!current.isAfter(endDate)) {
    dates.add(
      '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}',
    );
    current = current.add(const Duration(days: 1));
  }

  final mealsByDate = <String, List<MealLog>>{};
  for (final meal in meals) {
    final date = meal.loggedAt.length >= 10
        ? meal.loggedAt.substring(0, 10)
        : meal.loggedAt;
    mealsByDate.putIfAbsent(date, () => []).add(meal);
  }

  final waterByDate = <String, List<WaterLog>>{};
  for (final wl in waterLogs) {
    final date =
        wl.loggedAt.length >= 10 ? wl.loggedAt.substring(0, 10) : wl.loggedAt;
    waterByDate.putIfAbsent(date, () => []).add(wl);
  }

  final weightByDate = <String, List<WeightLog>>{};
  for (final wl in weightLogs) {
    final date =
        wl.loggedAt.length >= 10 ? wl.loggedAt.substring(0, 10) : wl.loggedAt;
    weightByDate.putIfAbsent(date, () => []).add(wl);
    weightByDate[date]!.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
  }

  final snapshotsByDate = <String, DailyTargetSnapshot>{};
  for (final date in dates) {
    final snap = await snapshotRepo.readByUserAndDate(user.id, date);
    if (snap != null) {
      snapshotsByDate[date] = snap;
    }
  }

  final dailyData = <DailyAnalytics>[];
  for (final date in dates) {
    final dayMeals = mealsByDate[date] ?? [];
    final dayWater = waterByDate[date] ?? [];
    final snapshot = snapshotsByDate[date];

    dailyData.add(DailyAnalytics(
      date: date,
      totalCalories: dayMeals.fold<double>(0, (s, m) => s + m.caloriesSnapshot),
      totalProtein: dayMeals.fold<double>(0, (s, m) => s + m.proteinGsnapshot),
      totalCarbs: dayMeals.fold<double>(0, (s, m) => s + m.carbsGsnapshot),
      totalFat: dayMeals.fold<double>(0, (s, m) => s + m.fatGsnapshot),
      totalSpending: dayMeals.fold<double>(0, (s, m) => s + m.costPhpSnapshot),
      totalWaterMl: dayWater.fold<int>(0, (s, w) => s + w.amountMl),
      calorieTarget: snapshot?.calorieTargetSnapshot,
      proteinTarget: snapshot?.proteinTargetGSnapshot,
      carbsTarget: snapshot?.carbsTargetGSnapshot,
      fatTarget: snapshot?.fatTargetGSnapshot,
      waterTargetMl: snapshot?.waterTargetMlSnapshot,
      budgetPhp: snapshot?.dailyBudgetPhpSnapshot,
    ));
  }

  final sortedWeightDates = weightByDate.keys.toList()..sort();
  final startWeight = sortedWeightDates.isNotEmpty
      ? weightByDate[sortedWeightDates.first]!.first.weightKg
      : null;
  final endWeightVal = sortedWeightDates.isNotEmpty
      ? weightByDate[sortedWeightDates.last]!.first.weightKg
      : null;
  final weightChange = startWeight != null && endWeightVal != null
      ? endWeightVal - startWeight
      : 0.0;

  final totalSpending =
      dailyData.fold<double>(0, (s, d) => s + d.totalSpending);

  final daysWithCalories = dailyData.where((d) => d.totalCalories > 0).length;
  final avgCalories = daysWithCalories > 0
      ? dailyData.fold<double>(0, (s, d) => s + d.totalCalories) /
          daysWithCalories
      : 0.0;

  final totalProteinCals =
      dailyData.fold<double>(0, (s, d) => s + d.totalProtein * 4);
  final totalCarbsCals =
      dailyData.fold<double>(0, (s, d) => s + d.totalCarbs * 4);
  final totalFatCals = dailyData.fold<double>(0, (s, d) => s + d.totalFat * 9);
  final totalMacroCals = totalProteinCals + totalCarbsCals + totalFatCals;
  final avgProteinPct =
      totalMacroCals > 0 ? (totalProteinCals / totalMacroCals * 100) : 0.0;
  final avgCarbsPct =
      totalMacroCals > 0 ? (totalCarbsCals / totalMacroCals * 100) : 0.0;
  final avgFatPct =
      totalMacroCals > 0 ? (totalFatCals / totalMacroCals * 100) : 0.0;

  final calDays = dailyData
      .where((d) => d.calorieTarget != null && d.calorieTarget! > 0)
      .length;
  final avgCalAdherence = calDays > 0
      ? (dailyData
              .where((d) => d.calorieTarget != null && d.calorieTarget! > 0)
              .fold<double>(
                  0,
                  (s, d) =>
                      s +
                      (d.totalCalories / d.calorieTarget! * 100)
                          .clamp(0, 100)) /
          calDays)
      : 0.0;

  final hydDays = dailyData
      .where((d) => d.waterTargetMl != null && d.waterTargetMl! > 0)
      .length;
  final avgHydAdherence = hydDays > 0
      ? (dailyData
              .where((d) => d.waterTargetMl != null && d.waterTargetMl! > 0)
              .fold<double>(
                  0,
                  (s, d) =>
                      s +
                      (d.totalWaterMl / d.waterTargetMl! * 100).clamp(0, 100)) /
          hydDays)
      : 0.0;

  final budDays =
      dailyData.where((d) => d.budgetPhp != null && d.budgetPhp! > 0).length;
  final avgBudAdherence = budDays > 0
      ? (dailyData
              .where((d) => d.budgetPhp != null && d.budgetPhp! > 0)
              .fold<double>(
                  0,
                  (s, d) =>
                      s +
                      (d.totalSpending / d.budgetPhp! * 100).clamp(0, 100)) /
          budDays)
      : 0.0;

  meals.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
  final recentLogs = meals.take(20).toList();

  return AnalyticsData(
    dailyData: dailyData,
    totalSpending: totalSpending,
    averageDailyCalories: avgCalories,
    weightChange: weightChange,
    startWeight: startWeight,
    endWeight: endWeightVal,
    averageMacroProteinPercent: avgProteinPct,
    averageMacroCarbsPercent: avgCarbsPct,
    averageMacroFatPercent: avgFatPct,
    averageCalorieAdherencePercent: avgCalAdherence,
    averageHydrationAdherencePercent: avgHydAdherence,
    averageBudgetAdherencePercent: avgBudAdherence,
    recentLogs: recentLogs,
    weightLogs: weightLogs,
  );
});
