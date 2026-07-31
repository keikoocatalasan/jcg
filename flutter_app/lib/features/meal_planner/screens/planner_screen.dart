import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/profile_repository.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/offline_banner.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:collection/collection.dart';
import 'package:jcg_fitness/core/database/meal_plan_repository.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/meal_planner/meal_planner_provider.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  late String _weekStart;
  double _dailyBudget = 0;
  String _fitnessGoalCode = '';
  double _weeklyBudget = 0;

  static const _dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _mealTypeOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const _mealTypeLabels = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
  };

  List<DateTime> get _weekDays {
    final start = DateTime.parse(_weekStart);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  String get _weekRangeLabel {
    final days = _weekDays;
    final startFmt = DateFormat('MMM d').format(days.first);
    final endFmt = DateFormat('MMM d, yyyy').format(days.last);
    final weekNum = _isoWeekNumber(days.first);
    return '$startFmt - $endFmt / Week $weekNum';
  }

  int _isoWeekNumber(DateTime date) {
    final jan4 = DateTime(date.year, 1, 4);
    final startOfFirstWeek = jan4.subtract(Duration(days: jan4.weekday - 1));
    final diff = date.difference(startOfFirstWeek).inDays;
    return (diff ~/ 7) + 1;
  }

  @override
  void initState() {
    super.initState();
    _weekStart = DateHelper.weekStart(DateHelper.todayDate());
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final profileRepo = ProfileRepository(DatabaseProvider());
    final profile = await profileRepo.readByUserId(user.id);
    if (profile != null && mounted) {
      setState(() {
        _dailyBudget = profile.dailyBudgetPhp ?? 0;
        _weeklyBudget = _dailyBudget * 7;
        _fitnessGoalCode = profile.fitnessGoalCode ?? '';
      });
    }
  }

  void _previousWeek() {
    setState(() {
      final start = DateTime.parse(_weekStart);
      _weekStart = DateHelper.weekStart(
        start
            .subtract(const Duration(days: 7))
            .toIso8601String()
            .split('T')
            .first,
      );
    });
  }

  void _nextWeek() {
    setState(() {
      final start = DateTime.parse(_weekStart);
      _weekStart = DateHelper.weekStart(
        start.add(const Duration(days: 7)).toIso8601String().split('T').first,
      );
    });
  }

  String _dateStr(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _goalLabel(String code) {
    switch (code) {
      case 'muscle_gain':
        return 'High Protein / Muscle Gain';
      case 'weight_loss':
        return 'Calorie Deficit / Weight Loss';
      case 'maintenance':
        return 'Balanced / Maintenance';
      case 'endurance':
        return 'Endurance / Performance';
      default:
        return 'General Fitness';
    }
  }

  _WeekStats _computeWeekStats(List<MealPlan> allPlans) {
    int daysPlanned = 0;
    double totalCost = 0;
    int totalMeals = 0;

    for (int i = 0; i < 7; i++) {
      final dateStr = _dateStr(_weekDays[i]);
      final dayPlans = allPlans.where((p) => p.plannedDate == dateStr).toList();
      if (dayPlans.isNotEmpty) daysPlanned++;
      totalMeals += dayPlans.length;
      for (final p in dayPlans) {
        totalCost += p.costPhpSnapshot;
      }
    }

    final budgetRemaining = _weeklyBudget - totalCost;

    return _WeekStats(
      daysPlanned: daysPlanned,
      budgetRemaining: budgetRemaining,
      totalMeals: totalMeals,
    );
  }

  Map<String, List<MealPlan>> _groupByDate(List<MealPlan> allPlans) {
    final map = <String, List<MealPlan>>{};
    for (final plan in allPlans) {
      map.putIfAbsent(plan.plannedDate, () => []).add(plan);
    }
    return map;
  }

  double _dayCost(List<MealPlan> dayPlans) {
    double cost = 0;
    for (final p in dayPlans) {
      cost += p.costPhpSnapshot;
    }
    return cost;
  }

  double _dayCalories(List<MealPlan> dayPlans) {
    double cal = 0;
    for (final p in dayPlans) {
      cal += p.caloriesSnapshot;
    }
    return cal;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekPlansAsync = ref.watch(weeklyPlansProvider(_weekStart));

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Planner')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: weekPlansAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allPlans) {
                final stats = _computeWeekStats(allPlans);
                final grouped = _groupByDate(allPlans);
                return _buildContent(theme, allPlans, grouped, stats);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    List<MealPlan> allPlans,
    Map<String, List<MealPlan>> grouped,
    _WeekStats stats,
  ) {
    return Column(
      children: [
        _buildWeekHeader(theme),
        _buildStatsRow(theme, stats),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: constraints.maxWidth < 760 ? 760 : constraints.maxWidth,
                height: constraints.maxHeight,
                child: _buildDayGrid(theme, grouped),
              ),
            ),
          ),
        ),
        _buildBottomButtons(theme),
      ],
    );
  }

  Widget _buildWeekHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: _previousWeek,
            color: AppColors.primary,
          ),
          Expanded(
            child: Text(
              _weekRangeLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            onPressed: _nextWeek,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme, _WeekStats stats) {
    final budgetClamped = stats.budgetRemaining.clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.3)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            _StatChip(
              icon: Icons.calendar_today,
              label: 'Days Planned',
              value: '${stats.daysPlanned}/7',
            ),
            _StatChip(
              icon: Icons.savings,
              label: 'Budget Remaining',
              value:
                  '${Formatters.formatPhp(budgetClamped)} / ${Formatters.formatPhp(_weeklyBudget)}',
            ),
            _StatChip(
              icon: Icons.flag,
              label: 'Goal Context',
              value: _goalLabel(_fitnessGoalCode),
            ),
            _StatChip(
              icon: Icons.restaurant,
              label: 'Meals Planned',
              value: '${stats.totalMeals}/28',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayGrid(ThemeData theme, Map<String, List<MealPlan>> grouped) {
    return Column(
      children: [
        _buildGridHeader(theme),
        Expanded(
          child: ListView.builder(
            itemCount: 7,
            itemBuilder: (_, dayIndex) {
              final date = _weekDays[dayIndex];
              final dateStr = _dateStr(date);
              final dayPlans = grouped[dateStr] ?? [];
              final isToday = _isToday(date);
              return _buildDayRow(theme, dayIndex, date, dayPlans, isToday);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridHeader(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Text(
                'DAY',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          ..._mealTypeOrder.map((type) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _mealTypeLabels[type]!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )),
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'COST',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 65,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'KCAL',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(
    ThemeData theme,
    int dayIndex,
    DateTime date,
    List<MealPlan> dayPlans,
    bool isToday,
  ) {
    final groupedByType = <String, MealPlan?>{};
    for (final type in _mealTypeOrder) {
      groupedByType[type] = dayPlans.isNotEmpty
          ? dayPlans.where((p) => p.mealTypeCode == type).firstOrNull
          : null;
    }

    final cost = _dayCost(dayPlans);
    final calories = _dayCalories(dayPlans);
    final dayColor = isToday ? AppColors.primary : AppColors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: isToday ? AppColors.primary.withValues(alpha: 0.08) : null,
        border: Border(
          left: isToday
              ? const BorderSide(color: AppColors.primary, width: 4)
              : BorderSide.none,
          bottom: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                children: [
                  Text(
                    _dayLabels[dayIndex],
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: dayColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d').format(date),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: dayColor,
                    ),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          ..._mealTypeOrder.map((type) {
            final plan = groupedByType[type];
            return Expanded(
              child: _buildMealCell(theme, plan, dayIndex, type),
            );
          }),
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                Formatters.formatPhp(cost),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.budgetColor,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 65,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                Formatters.formatCalories(calories),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.calorieColor,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCell(
    ThemeData theme,
    MealPlan? plan,
    int dayIndex,
    String mealType,
  ) {
    if (plan == null) {
      return InkWell(
        onTap: () => context.push('/add-planned-meal', extra: {
          'selectedDate': _dateStr(_weekDays[dayIndex]),
          'mealType': mealType,
        }),
        child: Container(
          margin: const EdgeInsets.all(3),
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.add,
              size: 16,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    final statusTag = switch (plan.statusCode) {
      'logged' => const StatusTag.ok(label: 'Logged'),
      'skipped' => const StatusTag.neutral(label: 'Skipped'),
      _ => const StatusTag.neutral(label: 'Planned'),
    };

    return InkWell(
      onTap: () => context.push('/day-summary', extra: {
        'date': plan.plannedDate,
      }),
      child: Container(
        margin: const EdgeInsets.all(3),
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              plan.foodNameSnapshot,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 9,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            Text(
              Formatters.formatCalories(plan.caloriesSnapshot),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 8,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            statusTag,
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: AppColors.divider.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.push('/add-planned-meal', extra: {
                  'selectedDate': _dateStr(
                    _weekDays.firstWhere(
                      _isToday,
                      orElse: () => _weekDays.first,
                    ),
                  ),
                }),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Planned Meal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/day-summary', extra: {
                  'date': _dateStr(DateTime.now()),
                }),
                icon: const Icon(Icons.summarize, size: 20),
                label: const Text('View Day Summary'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekStats {
  final int daysPlanned;
  final double budgetRemaining;
  final int totalMeals;

  _WeekStats({
    required this.daysPlanned,
    required this.budgetRemaining,
    required this.totalMeals,
  });
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 8,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
