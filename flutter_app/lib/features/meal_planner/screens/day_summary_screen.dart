import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/meal_plan_repository.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/meal_logging/meal_log_provider.dart';
import 'package:jcg_fitness/features/meal_logging/recent_logs_provider.dart';
import 'package:jcg_fitness/features/meal_planner/meal_planner_provider.dart';
import 'package:jcg_fitness/features/meal_planner/screens/convert_to_log_dialog.dart';
import 'package:jcg_fitness/features/meal_planner/screens/mark_skipped_dialog.dart';
import 'package:jcg_fitness/features/profile_settings/profile_provider.dart';

class DaySummaryScreen extends ConsumerStatefulWidget {
  const DaySummaryScreen({super.key});

  @override
  ConsumerState<DaySummaryScreen> createState() => _DaySummaryScreenState();
}

class _DaySummaryScreenState extends ConsumerState<DaySummaryScreen> {
  String? _dateStr;
  bool _extrasProcessed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processExtras());
  }

  void _processExtras() {
    if (_extrasProcessed) return;
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      final date = extra['date'];
      if (date is String) {
        setState(() => _dateStr = date);
      }
    }
    _extrasProcessed = true;
  }

  Future<void> _logThisDay(List<MealPlan> plans) async {
    if (_dateStr == null || plans.isEmpty) return;
    final confirmed = await ConvertToLogDialog.show(
      context,
      dateStr: _dateStr!,
      plans: plans,
    );
    if (confirmed == true && mounted) {
      ref.invalidate(plansForDateProvider(_dateStr!));
      ref.invalidate(weeklyPlansProvider);
      ref.invalidate(recentLogsProvider);
      ref.invalidate(todayMealLogsProvider);
      ref.invalidate(mealLogsForDateProvider);
      ref.invalidate(dashboardDataProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Planned meals converted to log entries')),
      );
      setState(() {});
    }
  }

  Future<void> _markDaySkipped(List<MealPlan> plans) async {
    if (_dateStr == null || plans.isEmpty) return;
    final confirmed = await MarkSkippedDialog.show(
      context,
      dateStr: _dateStr!,
      plans: plans,
    );
    if (confirmed == true && mounted) {
      ref.invalidate(plansForDateProvider(_dateStr!));
      ref.invalidate(weeklyPlansProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day marked as skipped')),
      );
      setState(() {});
    }
  }

  Future<void> _deletePlan(MealPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Meal'),
        content: Text('Delete "${plan.foodNameSnapshot}" from your plan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    try {
      final helper = LocalTransactionHelper(DatabaseProvider());
      await helper.deletePlannedMeal(plan.mealPlanId, user.id);
      if (mounted) {
        ref.invalidate(plansForDateProvider(_dateStr!));
        ref.invalidate(weeklyPlansProvider);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Meal deleted')));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dateStr == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Planned Day Summary')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final dt = DateTime.tryParse(_dateStr!);
    final dayLabel =
        dt != null ? DateFormat('EEEE, MMMM d').format(dt) : _dateStr!;

    return Scaffold(
      appBar: AppBar(title: const Text('Planned Day Summary')),
      body: _DaySummaryBody(
        dateStr: _dateStr!,
        dayLabel: dayLabel,
        onLogThisDay: _logThisDay,
        onMarkSkipped: _markDaySkipped,
        onDeletePlan: _deletePlan,
      ),
    );
  }
}

class _DaySummaryBody extends ConsumerWidget {
  final String dateStr;
  final String dayLabel;
  final Future<void> Function(List<MealPlan> plans) onLogThisDay;
  final Future<void> Function(List<MealPlan> plans) onMarkSkipped;
  final Future<void> Function(MealPlan plan) onDeletePlan;

  const _DaySummaryBody({
    required this.dateStr,
    required this.dayLabel,
    required this.onLogThisDay,
    required this.onMarkSkipped,
    required this.onDeletePlan,
  });

  static const _mealTypeLabels = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
  };
  static const _mealTypeIcons = {
    'breakfast': Icons.wb_sunny_outlined,
    'lunch': Icons.wb_cloudy_outlined,
    'dinner': Icons.nightlight_outlined,
    'snack': Icons.cookie_outlined,
  };
  static const _mealTypeOrder = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansForDateProvider(dateStr));

    return plansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load planned meals',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.error)),
            const SizedBox(height: 8),
            Text('Please check your connection and try again.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: () => ref.invalidate(plansForDateProvider(dateStr)),
                child: const Text('Retry')),
          ],
        ),
      ),
      data: (plans) {
        if (plans.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restaurant_menu,
                    size: 64, color: AppColors.textSecondary.withAlpha(100)),
                const SizedBox(height: 16),
                Text('No meals planned for this day',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('Start by adding your first meal.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.push('/add-planned-meal',
                      extra: {'selectedDate': dateStr}),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Your First Meal'),
                ),
              ],
            ),
          );
        }

        final totals = _computeTotals(plans);
        final profile = ref.watch(profileProvider).valueOrNull;
        final dailyBudget = profile?.dailyBudgetPhp ?? 300.0;
        final goalLabel = _goalLabel(profile?.fitnessGoalCode);
        final dashboard = ref.watch(dashboardDataProvider).valueOrNull;
        final isOverBudget = totals.cost > dailyBudget;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDayHeader(context, dailyBudget, goalLabel),
            const SizedBox(height: 12),
            _buildNutritionSummary(context, totals, dashboard),
            const SizedBox(height: 12),
            _buildCostSummary(
                context, totals, dailyBudget, isOverBudget, plans),
            const SizedBox(height: 16),
            Text(
              'Planned Meals',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._buildMealGroups(context, plans),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context
                  .push('/add-planned-meal', extra: {'selectedDate': dateStr}),
              icon: const Icon(Icons.add),
              label: const Text('Add Another Meal'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onLogThisDay(plans),
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Log This Day (Convert Planned Meals to Log)'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onMarkSkipped(plans),
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: const Text('Mark Day as Skipped'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/planner'),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Plan'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDayHeader(
    BuildContext context,
    double budget,
    String goalLabel,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_today,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dayLabel,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Goal: $goalLabel',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Daily Budget',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
                Text(Formatters.formatPhp(budget),
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _goalLabel(String? code) {
    switch (code) {
      case 'cutting':
        return 'Lose Weight';
      case 'bulking':
        return 'Build Muscle';
      case 'lean':
        return 'Lean Gain';
      case 'gain_weight':
        return 'Gain Weight';
      case 'maintenance':
        return 'Maintain Weight';
      default:
        return 'General Fitness';
    }
  }

  Widget _buildNutritionSummary(
    BuildContext context,
    _DayTotals totals,
    DashboardData? target,
  ) {
    int percent(double value, double targetValue) =>
        targetValue > 0 ? (value / targetValue * 100).round() : 0;

    final calPercent = percent(
      totals.calories,
      target?.targetCalories.toDouble() ?? 0,
    );
    final proteinPercent = percent(totals.protein, target?.targetProtein ?? 0);
    final carbsPercent = percent(totals.carbs, target?.targetCarbs ?? 0);
    final fatPercent = percent(totals.fat, target?.targetFat ?? 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NutrientColumn(
                label: 'Total Calories',
                value: '${totals.calories.round()}',
                unit: 'kcal',
                sub: '$calPercent% of target'),
            _NutrientColumn(
                label: 'Protein',
                value: '${totals.protein.round()}',
                unit: 'g',
                sub: '$proteinPercent% of target'),
            _NutrientColumn(
                label: 'Carbs',
                value: '${totals.carbs.round()}',
                unit: 'g',
                sub: '$carbsPercent% of target'),
            _NutrientColumn(
                label: 'Fat',
                value: '${totals.fat.round()}',
                unit: 'g',
                sub: '$fatPercent% of target'),
          ],
        ),
      ),
    );
  }

  Widget _buildCostSummary(BuildContext context, _DayTotals totals,
      double budget, bool isOverBudget, List<MealPlan> plans) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text('Estimated Cost',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
                Text(Formatters.formatPhp(totals.cost),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            Column(
              children: [
                Text('Meals Planned',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('${plans.length}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            Column(
              children: [
                Text('Budget Status',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
                isOverBudget
                    ? const StatusTag.over(label: 'Over Budget')
                    : const StatusTag.ok(label: 'Within Budget'),
                if (isOverBudget)
                  Text(
                    '+${Formatters.formatPhp(totals.cost - budget)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMealGroups(BuildContext context, List<MealPlan> plans) {
    final grouped = <String, List<MealPlan>>{};
    for (final type in _mealTypeOrder) {
      final meals = plans.where((p) => p.mealTypeCode == type).toList();
      if (meals.isNotEmpty) grouped[type] = meals;
    }

    return grouped.entries.expand((entry) {
      final label = _mealTypeLabels[entry.key] ?? entry.key;
      final icon = _mealTypeIcons[entry.key] ?? Icons.restaurant;
      final meals = entry.value;

      return [
        ...meals.map((plan) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                title: Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.foodNameSnapshot,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      '${Formatters.formatCalories(plan.caloriesSnapshot)}  P ${plan.proteinGsnapshot.round()}g  C ${plan.carbsGsnapshot.round()}g  F ${plan.fatGsnapshot.round()}g',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Formatters.formatPhp(plan.costPhpSnapshot),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (value) {
                        if (value == 'delete') onDeletePlan(plan);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 18, color: AppColors.error),
                                SizedBox(width: 8),
                                Text('Delete')
                              ],
                            )),
                      ],
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            )),
      ];
    }).toList();
  }

  _DayTotals _computeTotals(List<MealPlan> plans) {
    double cal = 0, pro = 0, carb = 0, fat = 0, cost = 0;
    for (final p in plans) {
      cal += p.caloriesSnapshot;
      pro += p.proteinGsnapshot;
      carb += p.carbsGsnapshot;
      fat += p.fatGsnapshot;
      cost += p.costPhpSnapshot;
    }
    return _DayTotals(cal, pro, carb, fat, cost);
  }
}

class _NutrientColumn extends StatelessWidget {
  final String label, value, unit, sub;
  const _NutrientColumn(
      {required this.label,
      required this.value,
      required this.unit,
      required this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.textPrimary)),
        Text(unit,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        Text(sub,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _DayTotals {
  final double calories, protein, carbs, fat, cost;
  _DayTotals(this.calories, this.protein, this.carbs, this.fat, this.cost);
}
