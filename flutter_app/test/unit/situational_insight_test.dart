import 'package:flutter_test/flutter_test.dart';

import 'package:jcg_fitness/core/database/weight_log_repository.dart';
import 'package:jcg_fitness/core/models/profile.dart';
import 'package:jcg_fitness/features/analytics/analytics_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/recommendations/situational_insight_provider.dart';

void main() {
  final profile = Profile(
    userId: 'app-user',
    authUserId: 'auth-user',
    nickname: 'Test',
    fitnessGoalCode: 'cutting',
    targetWeightKg: 65,
  );

  AnalyticsData analytics({List<WeightLog> weights = const []}) =>
      AnalyticsData(
        dailyData: const [],
        totalSpending: 0,
        averageDailyCalories: 0,
        weightChange: weights.length >= 2
            ? weights.last.weightKg - weights.first.weightKg
            : 0,
        averageMacroProteinPercent: 0,
        averageMacroCarbsPercent: 0,
        averageMacroFatPercent: 0,
        averageCalorieAdherencePercent: 0,
        averageHydrationAdherencePercent: 0,
        averageBudgetAdherencePercent: 0,
        recentLogs: const [],
        weightLogs: weights,
      );

  DashboardData dashboard({
    bool overBudget = false,
    bool overCalories = false,
    int water = 1500,
    int waterTarget = 2500,
  }) =>
      DashboardData(
        consumedCalories: overCalories ? 2300 : 1500,
        targetCalories: 2000,
        consumedProtein: 70,
        targetProtein: 100,
        consumedCarbs: 120,
        targetCarbs: 220,
        consumedFat: 40,
        targetFat: 65,
        spentBudget: overBudget ? 350 : 150,
        dailyBudget: 300,
        waterMl: water,
        waterTargetMl: waterTarget,
        recentLogs: const [],
        isOverBudget: overBudget,
        isOverCalories: overCalories,
        hasTarget: true,
      );

  test('prioritizes an over-budget insight', () {
    final result = deriveSituationalInsight(
      dashboard: dashboard(overBudget: true),
      profile: profile,
      analytics: analytics(),
    );
    expect(result.title, 'Budget check-in');
    expect(result.body, contains('50'));
  });

  test('prioritizes an over-calorie insight before hydration', () {
    final result = deriveSituationalInsight(
      dashboard: dashboard(overCalories: true, water: 500),
      profile: profile,
      analytics: analytics(),
    );
    expect(result.title, 'Calorie check-in');
    expect(result.body, contains('300'));
  });

  test('reports hydration when other metrics are within range', () {
    final result = deriveSituationalInsight(
      dashboard: dashboard(water: 1000),
      profile: profile,
      analytics: analytics(),
    );
    expect(result.title, 'Hydration check-in');
    expect(result.body, contains('40%'));
  });
}
