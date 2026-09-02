import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jcg_fitness/core/models/profile.dart';
import 'package:jcg_fitness/features/analytics/analytics_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/profile_settings/profile_provider.dart';

class SituationalInsight {
  final String title;
  final String body;
  final String action;

  const SituationalInsight({
    required this.title,
    required this.body,
    required this.action,
  });
}

final situationalInsightProvider = FutureProvider<SituationalInsight?>((ref) async {
  final dashboard = await ref.watch(dashboardDataProvider.future);
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return null;

  final now = DateTime.now();
  final analytics = await ref.watch(
    analyticsDataProvider(
      DateRange(
        start: now.subtract(const Duration(days: 6)),
        end: now,
      ),
    ).future,
  );
  return deriveSituationalInsight(
    dashboard: dashboard,
    profile: profile,
    analytics: analytics,
  );
});

SituationalInsight deriveSituationalInsight({
  required DashboardData dashboard,
  required Profile profile,
  required AnalyticsData analytics,
}) {
  if (dashboard.isOverBudget) {
    return SituationalInsight(
      title: 'Budget check-in',
      body:
          'You are ${_php(dashboard.spentBudget - dashboard.dailyBudget)} over today\'s food budget.',
      action: 'Choose a budget-friendly recommendation next',
    );
  }
  if (dashboard.isOverCalories) {
    return SituationalInsight(
      title: 'Calorie check-in',
      body:
          'You are ${dashboard.consumedCalories - dashboard.targetCalories} kcal over today\'s target.',
      action: 'Keep the next meal lighter and protein-forward',
    );
  }
  if (dashboard.waterTargetMl > 0 &&
      dashboard.waterMl < dashboard.waterTargetMl * 0.70) {
    return SituationalInsight(
      title: 'Hydration check-in',
      body:
          'You have reached ${(dashboard.waterMl / dashboard.waterTargetMl * 100).round()}% of today\'s water goal.',
      action: 'Log a glass of water before your next meal',
    );
  }

  if (analytics.weightLogs.length >= 2 && profile.targetWeightKg != null) {
    final movingTowardTarget = _isMovingTowardTarget(
      profile.fitnessGoalCode,
      analytics.weightChange,
    );
    if (!movingTowardTarget) {
      return const SituationalInsight(
        title: 'Trend check-in',
        body: 'Your recent weight trend is not yet moving toward your target.',
        action: 'Review your logged meals and adjust the next recommendation',
      );
    }
  }

  if (analytics.averageCalorieAdherencePercent >= 80 &&
      analytics.averageHydrationAdherencePercent >= 70) {
    return const SituationalInsight(
      title: 'You are on track',
      body: 'Your recent calorie and hydration logs are supporting your goal.',
      action: 'Keep the streak going with a balanced next meal',
    );
  }

  return const SituationalInsight(
    title: 'Next best step',
    body: 'Start with one balanced, affordable meal that fits your goal.',
    action: 'View recommendations matched to your current numbers',
  );
}

bool _isMovingTowardTarget(String? goalCode, double weightChange) {
  switch (goalCode) {
    case 'cutting':
    case 'lose_weight':
      return weightChange < 0;
    case 'bulking':
    case 'gain_weight':
    case 'lean':
      return weightChange > 0;
    default:
      return weightChange.abs() < 1.5;
  }
}

String _php(double value) => value.toStringAsFixed(0);
