import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/macro_bar.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/profile_settings/profile_provider.dart';
import 'package:jcg_fitness/features/recommendations/recommendation_provider.dart';

String _greetingForTimeOfDay() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(dashboardDataProvider);
    return Scaffold(
      body: GlassBackground(
        child: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (data) => RefreshIndicator(
            onRefresh: () => ref.refresh(dashboardDataProvider.future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                _Header(data: data),
                const _DateRow(),
                _TodayProgressCard(data: data),
                _BudgetCard(data: data),
                const _AiRecommendationCard(),
                _RecentLogsCard(data: data),
                const _QuickActionsRow(),
                const _OfflineSyncBanner(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _mealIcon(String code) {
    switch (code) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'snack':
        return Icons.cookie;
      case 'pre_workout':
      case 'post_workout':
        return Icons.fitness_center;
      default:
        return Icons.restaurant;
    }
  }
}

class _Header extends ConsumerWidget {
  final DashboardData data;
  const _Header({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final nickname = profileAsync.valueOrNull?.nickname ?? 'User';
    final greeting = _greetingForTimeOfDay();

    return InkWell(
      onTap: () => context.push('/profile'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child:
                  const Icon(Icons.person, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $nickname!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Let's crush your goals today.",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.local_fire_department,
                  size: 18,
                  color: AppColors.secondary,
                  semanticLabel: '1 day streak'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateText = '${_monthName(now.month)} ${now.day}, ${now.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.calendar_today,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            dateText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const Spacer(),
          const StatusTag.neutral(label: 'Today'),
        ],
      ),
    );
  }

  static String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

class _TodayProgressCard extends StatelessWidget {
  final DashboardData data;
  const _TodayProgressCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final remaining = (data.targetCalories - data.consumedCalories)
        .clamp(0, data.targetCalories);
    final progress = data.targetCalories > 0
        ? (data.consumedCalories / data.targetCalories).clamp(0.0, 1.0)
        : 0.0;

    final proteinPct = data.targetProtein > 0
        ? (data.consumedProtein / data.targetProtein * 100).clamp(0.0, 100.0)
        : 0.0;
    final carbsPct = data.targetCarbs > 0
        ? (data.consumedCarbs / data.targetCarbs * 100).clamp(0.0, 100.0)
        : 0.0;
    final fatsPct = data.targetFat > 0
        ? (data.consumedFat / data.targetFat * 100).clamp(0.0, 100.0)
        : 0.0;

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          backgroundColor:
                              AppColors.calorieColor.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            data.isOverCalories
                                ? AppColors.error
                                : AppColors.calorieColor,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            Formatters.formatCalories(remaining.toDouble()),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'remaining',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (data.isOverCalories) ...[
                            const SizedBox(height: 4),
                            const StatusTag.over(label: 'Over'),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calories',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${Formatters.formatCalories(data.consumedCalories.toDouble())} consumed',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Formatters.formatCalories(data.targetCalories.toDouble())} target',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).disabledColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MacroBar(
              label: 'Protein',
              current: data.consumedProtein,
              target: data.targetProtein,
              color: AppColors.proteinColor,
            ),
            const SizedBox(height: 8),
            MacroBar(
              label: 'Carbs',
              current: data.consumedCarbs,
              target: data.targetCarbs,
              color: AppColors.carbsColor,
            ),
            const SizedBox(height: 8),
            MacroBar(
              label: 'Fats',
              current: data.consumedFat,
              target: data.targetFat,
              color: AppColors.fatColor,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Protein ${Formatters.formatPercent(proteinPct)}  ·  Carbs ${Formatters.formatPercent(carbsPct)}  ·  Fats ${Formatters.formatPercent(fatsPct)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/nutrition-target'),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Targets'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentLogsCard extends StatelessWidget {
  final DashboardData data;
  const _RecentLogsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Recent Logs',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/meal-log'),
                  child: Text(
                    'View All',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (data.recentLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No meals logged today',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).disabledColor,
                        ),
                  ),
                ),
              )
            else
              ...data.recentLogs.take(5).map(
                    (log) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            DashboardScreen._mealIcon(log.mealTypeCode),
                            size: 28,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.foodNameSnapshot,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  log.mealTypeCode.replaceAll('_', ' '),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context).disabledColor,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            Formatters.formatCalories(log.caloriesSnapshot),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 8),
                          const StatusTag.ok(label: 'Logged'),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickAction(
            icon: Icons.restaurant,
            label: 'Log Meal',
            onTap: () => context.push('/add-meal-log'),
          ),
          _QuickAction(
            icon: Icons.water_drop,
            label: 'Log Water',
            onTap: () => context.push('/hydration'),
          ),
          _QuickAction(
            icon: Icons.monitor_weight,
            label: 'Log Weight',
            onTap: () => context.push('/weight'),
          ),
          _QuickAction(
            icon: Icons.camera_alt,
            label: 'Scan Food',
            onTap: () => context.push('/ai-scanner'),
          ),
          _QuickAction(
            icon: Icons.calendar_month,
            label: 'Planner',
            onTap: () => context.push('/planner'),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _OfflineSyncBanner extends ConsumerWidget {
  const _OfflineSyncBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final syncState = ref.watch(syncProvider);

    if (!isOnline) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off,
              size: 20,
              color: AppColors.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connection lost. Changes will sync when reconnected.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.warning,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    if (syncState.pendingCount > 0) {
      final plural = syncState.pendingCount == 1 ? '' : 's';
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.sync,
              size: 20,
              color: AppColors.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You have ${syncState.pendingCount} item$plural waiting to sync',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    "Changes will sync when you're back online.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/sync-status'),
              child: Text(
                'View',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_done,
            size: 20,
            color: AppColors.success,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'All changes synced',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.success,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final DashboardData data;
  const _BudgetCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final dailyBudget = data.dailyBudget;
    final spentBudget = data.spentBudget;

    // Default budget to 300 PHP if not set
    final target = dailyBudget > 0 ? dailyBudget : 300.0;
    final progress = target > 0 ? (spentBudget / target).clamp(0.0, 1.0) : 0.0;

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Food Budget',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Smart tracking enabled',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PHP ${spentBudget.toStringAsFixed(0)}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    Text(
                      'of PHP ${target.toStringAsFixed(0)} spent',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    if (data.isOverBudget) ...[
                      const SizedBox(height: 4),
                      const StatusTag.over(label: 'Over Budget'),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  data.isOverBudget ? AppColors.error : AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ECONOMICAL',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (progress > 0.4 && progress < 0.8)
                  const StatusTag.ok(label: 'Optimal')
                else
                  Text(
                    'OPTIMAL ZONE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                if (progress >= 0.8)
                  const StatusTag.over(label: 'Limit')
                else
                  Text(
                    'LIMIT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AiRecommendationCard extends ConsumerWidget {
  const _AiRecommendationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendationsAsync = ref.watch(recommendationProvider);

    return recommendationsAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final topFood = items.first;

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          child: InkWell(
            onTap: () => context.push('/recommendations'),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'AI Budget Recommendation',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Local high-protein, budget-friendly meal: ${topFood.food.foodName} - Only PHP ${topFood.food.estimatedPricePhp.toStringAsFixed(0)} per serving.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
