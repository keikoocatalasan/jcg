import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/meal_log_repository.dart';
import 'package:jcg_fitness/core/database/weight_log_repository.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/features/analytics/analytics_provider.dart';
import 'package:jcg_fitness/features/analytics/widgets/calorie_adherence_card.dart';
import 'package:jcg_fitness/features/analytics/widgets/macro_consistency_chart.dart';
import 'package:jcg_fitness/features/analytics/widgets/spending_chart.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  DateTime _endDate = DateTime.now();
  late DateTime _startDate;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _startDate = _endDate.subtract(const Duration(days: 7));
  }

  DateRange get _currentRange => DateRange(start: _startDate, end: _endDate);

  void _setDateRange(DateTime start, DateTime end) {
    setState(() {
      _startDate = start;
      _endDate = end;
    });
  }

  void _showDateRangeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DateRangeBottomSheet(
        currentStart: _startDate,
        currentEnd: _endDate,
        onApply: (range) {
          _setDateRange(range.start, range.end);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(analyticsDataProvider(_currentRange));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showDateRangeSheet,
            tooltip: 'Select date range',
          ),
        ],
      ),
      body: GlassBackground(
        child: Column(
          children: [
            GestureDetector(
              onTap: _showDateRangeSheet,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _buildTab(0, 'Overview'),
                  _buildTab(1, 'Calories'),
                  _buildTab(2, 'Macros'),
                  _buildTab(3, 'Nutrients'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: dataAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Failed to load analytics: $e',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                data: (data) {
                  if (!data.hasData) {
                    return ListView(
                      padding: const EdgeInsets.only(top: 32),
                      children: [
                        Icon(Icons.analytics_outlined,
                            size: 64, color: theme.disabledColor),
                        const SizedBox(height: 16),
                        Text(
                          'No data in selected range',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Log meals, water, and weight to see analytics',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(
                      analyticsDataProvider(_currentRange).future,
                    ),
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 32),
                      children: [
                        if (_selectedTab == 0) _OverviewTab(data: data),
                        if (_selectedTab == 1) ...[
                          SpendingChart(dailyData: data.dailyData),
                          CalorieAdherenceCard(dailyData: data.dailyData),
                        ],
                        if (_selectedTab == 2) ...[
                          MacroConsistencyChart(
                            proteinPercent: data.averageMacroProteinPercent,
                            carbsPercent: data.averageMacroCarbsPercent,
                            fatPercent: data.averageMacroFatPercent,
                          ),
                        ],
                        if (_selectedTab == 3) ...[
                          _SummaryCards(data: data),
                          SpendingChart(dailyData: data.dailyData),
                          _WeightTrendChart(
                            weightLogs: data.weightLogs,
                            weightChange: data.weightChange,
                            startWeight: data.startWeight,
                            endWeight: data.endWeight,
                          ),
                          MacroConsistencyChart(
                            proteinPercent: data.averageMacroProteinPercent,
                            carbsPercent: data.averageMacroCarbsPercent,
                            fatPercent: data.averageMacroFatPercent,
                          ),
                          CalorieAdherenceCard(dailyData: data.dailyData),
                          _HydrationConsistencyCard(dailyData: data.dailyData),
                          _BudgetAdherenceCard(dailyData: data.dailyData),
                          _PreviousLogsCard(recentLogs: data.recentLogs),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.textPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isSelected ? AppColors.surface : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateRangeBottomSheet extends StatefulWidget {
  final DateTime currentStart;
  final DateTime currentEnd;
  final ValueChanged<DateTimeRange> onApply;

  const _DateRangeBottomSheet({
    required this.currentStart,
    required this.currentEnd,
    required this.onApply,
  });

  @override
  State<_DateRangeBottomSheet> createState() => _DateRangeBottomSheetState();
}

class _DateRangeBottomSheetState extends State<_DateRangeBottomSheet> {
  late DateTime _tempStart;
  late DateTime _tempEnd;
  late String _selectedOption;

  @override
  void initState() {
    super.initState();
    _tempStart = widget.currentStart;
    _tempEnd = widget.currentEnd;
    _selectedOption = _determineCurrentOption();
  }

  String _determineCurrentOption() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfDay =
        DateTime(_tempStart.year, _tempStart.month, _tempStart.day);
    final endOfDay = DateTime(_tempEnd.year, _tempEnd.month, _tempEnd.day);

    if (startOfDay == today && endOfDay == today) return 'Today';
    if (startOfDay == today.subtract(const Duration(days: 1)) &&
        endOfDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }

    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    if (startOfDay == weekStart && endOfDay == weekEnd) return 'This Week';

    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = lastWeekStart.add(const Duration(days: 6));
    if (startOfDay == lastWeekStart && endOfDay == lastWeekEnd) {
      return 'Last Week';
    }

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    if (startOfDay == monthStart && endOfDay == monthEnd) return 'This Month';

    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0);
    if (startOfDay == lastMonthStart && endOfDay == lastMonthEnd) {
      return 'Last Month';
    }

    return 'Custom Range';
  }

  void _applyPreset(String label, DateTime start, DateTime end) {
    setState(() {
      _selectedOption = label;
      _tempStart = start;
      _tempEnd = end;
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _tempStart, end: _tempEnd),
    );
    if (picked != null) {
      setState(() {
        _tempStart = picked.start;
        _tempEnd = picked.end;
        _selectedOption = 'Custom Range';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final presets = <({String label, DateTime start, DateTime end})>[
      (
        label: 'Today',
        start: today,
        end: today,
      ),
      (
        label: 'Yesterday',
        start: today.subtract(const Duration(days: 1)),
        end: today.subtract(const Duration(days: 1)),
      ),
      (
        label: 'This Week',
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today
            .subtract(Duration(days: today.weekday - 1))
            .add(const Duration(days: 6)),
      ),
      (
        label: 'Last Week',
        start: today.subtract(Duration(days: today.weekday + 6)),
        end: today.subtract(Duration(days: today.weekday)),
      ),
      (
        label: 'This Month',
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      ),
      (
        label: 'Last Month',
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month, 0),
      ),
    ];

    return GlassContainer(
      level: GlassSurfaceLevel.modal,
      liveBlur: true,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Date Range',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...presets.map(
            (preset) => RadioListTile<String>(
              title: Text(preset.label, style: theme.textTheme.bodyMedium),
              value: preset.label,
              groupValue: _selectedOption,
              onChanged: (_) =>
                  _applyPreset(preset.label, preset.start, preset.end),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          ListTile(
            leading:
                Icon(Icons.calendar_month, color: theme.colorScheme.primary),
            title: Text('Custom Range', style: theme.textTheme.bodyMedium),
            onTap: _pickCustomRange,
            contentPadding: EdgeInsets.zero,
            dense: true,
            trailing: _selectedOption == 'Custom Range'
                ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
                : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(
                      DateTimeRange(start: _tempStart, end: _tempEnd),
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final AnalyticsData data;
  const _OverviewTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totalConsumed =
        data.dailyData.fold<double>(0, (s, d) => s + d.totalCalories);
    final daysWithTarget = data.dailyData
        .where((d) => d.calorieTarget != null && d.calorieTarget! > 0)
        .toList();
    final calorieGoal = daysWithTarget.isNotEmpty
        ? (daysWithTarget.fold<double>(0, (s, d) => s + d.calorieTarget!) /
                daysWithTarget.length *
                data.dailyData.length)
            .round()
        : 2000;
    final calorieProgress =
        calorieGoal > 0 ? (totalConsumed / calorieGoal).clamp(0.0, 1.0) : 0.0;

    final totalProtein =
        data.dailyData.fold<double>(0, (s, d) => s + d.totalProtein);
    final proteinGoal = daysWithTarget.isNotEmpty
        ? (daysWithTarget.fold<double>(
                    0, (s, d) => s + (d.proteinTarget ?? 0)) /
                daysWithTarget.length *
                data.dailyData.length)
            .round()
        : 120;
    final proteinProgress =
        proteinGoal > 0 ? (totalProtein / proteinGoal).clamp(0.0, 1.0) : 0.0;

    final totalCarbs =
        data.dailyData.fold<double>(0, (s, d) => s + d.totalCarbs);
    final carbsGoal = daysWithTarget.isNotEmpty
        ? (daysWithTarget.fold<double>(0, (s, d) => s + (d.carbsTarget ?? 0)) /
                daysWithTarget.length *
                data.dailyData.length)
            .round()
        : 250;
    final carbsProgress =
        carbsGoal > 0 ? (totalCarbs / carbsGoal).clamp(0.0, 1.0) : 0.0;

    final totalFat = data.dailyData.fold<double>(0, (s, d) => s + d.totalFat);
    final fatGoal = daysWithTarget.isNotEmpty
        ? (daysWithTarget.fold<double>(0, (s, d) => s + (d.fatTarget ?? 0)) /
                daysWithTarget.length *
                data.dailyData.length)
            .round()
        : 70;
    final fatProgress =
        fatGoal > 0 ? (totalFat / fatGoal).clamp(0.0, 1.0) : 0.0;

    final remaining = (calorieGoal - totalConsumed).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calorie Summary', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            Formatters.formatCalories(totalConsumed),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'consumed',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Goal target: ${Formatters.formatCalories(calorieGoal.toDouble())}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: calorieProgress,
                      minHeight: 10,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(calorieProgress * 100).round()}% of goal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Macro Progress', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  _MacroBar(
                    label: 'Protein',
                    consumed: totalProtein.round(),
                    goal: proteinGoal,
                    progress: proteinProgress,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 10),
                  _MacroBar(
                    label: 'Carbs',
                    consumed: totalCarbs.round(),
                    goal: carbsGoal,
                    progress: carbsProgress,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 10),
                  _MacroBar(
                    label: 'Fat',
                    consumed: totalFat.round(),
                    goal: fatGoal,
                    progress: fatProgress,
                    color: AppColors.borderStrong,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    remaining >= 0 ? Icons.check_circle : Icons.warning,
                    color: AppColors.textPrimary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      remaining >= 0
                          ? 'Great job! You\'re $remaining calories under your goal. Keep it up to reach your goal.'
                          : 'You\'re ${-remaining} calories over your goal. Try to balance your intake.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final int consumed;
  final int goal;
  final double progress;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.consumed,
    required this.goal,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            Text(
              '$consumed/${goal}g (${(progress * 100).round()}%)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final AnalyticsData data;
  const _SummaryCards({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              icon: Icons.shopping_cart_outlined,
              label: 'Spent',
              value: Formatters.formatPhp(data.totalSpending),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              icon: Icons.local_fire_department_outlined,
              label: 'Avg Cal',
              value: Formatters.formatCalories(data.averageDailyCalories),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              icon: Icons.monitor_weight_outlined,
              label: 'Weight',
              value: data.startWeight != null && data.endWeight != null
                  ? '${data.weightChange >= 0 ? '+' : ''}${data.weightChange.toStringAsFixed(1)}'
                  : '--',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 24, color: AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightTrendChart extends StatelessWidget {
  final List<WeightLog> weightLogs;
  final double weightChange;
  final double? startWeight;
  final double? endWeight;

  const _WeightTrendChart({
    required this.weightLogs,
    required this.weightChange,
    this.startWeight,
    this.endWeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final weightDays = <String, ({String date, double weight})>{};
    for (final wl in weightLogs) {
      final date =
          wl.loggedAt.length >= 10 ? wl.loggedAt.substring(0, 10) : wl.loggedAt;
      weightDays[date] = (date: date, weight: wl.weightKg);
    }
    final sorted = weightDays.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sorted.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.monitor_weight_outlined,
                    size: 40, color: theme.disabledColor),
                const SizedBox(height: 8),
                Text(
                  'No weight data in this range',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final spots = sorted.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.weight);
    }).toList();

    final minY = sorted.fold<double>(
      sorted.first.weight,
      (min, d) => d.weight < min ? d.weight : min,
    );
    final maxY = sorted.fold<double>(
      sorted.first.weight,
      (max, d) => d.weight > max ? d.weight : max,
    );

    final padding = ((maxY - minY) * 0.15).clamp(0.5, 10.0);
    final chartMinY = (minY - padding).floorToDouble();
    final chartMaxY = (maxY + padding).ceilToDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Weight Trend', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (startWeight != null && endWeight != null)
                  Text(
                    '${weightChange >= 0 ? '+' : ''}${weightChange.toStringAsFixed(1)} kg',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX:
                      (sorted.length - 1).toDouble().clamp(0, double.infinity),
                  minY: chartMinY,
                  maxY: chartMaxY,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.spotIndex;
                          if (index >= sorted.length) return null;
                          final day = sorted[index];
                          final dt = DateTime.tryParse(day.date);
                          return LineTooltipItem(
                            '${dt != null ? DateFormat('MMM d').format(dt) : day.date}\n${Formatters.formatWeight(day.weight)}',
                            const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: _calcBottomInterval(sorted.length),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= sorted.length) {
                            return const SizedBox.shrink();
                          }
                          final dt = DateTime.tryParse(sorted[index].date);
                          if (dt == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('M/d').format(dt),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.divider.withAlpha(51),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: AppColors.textPrimary,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: spots.length <= 30,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: AppColors.textPrimary,
                            strokeWidth: 1.5,
                            strokeColor: AppColors.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calcBottomInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 30) return 5;
    if (count <= 90) return 14;
    return 30;
  }
}

class _HydrationConsistencyCard extends StatelessWidget {
  final List<DailyAnalytics> dailyData;
  const _HydrationConsistencyCard({required this.dailyData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysWithTarget = dailyData
        .where((d) => d.waterTargetMl != null && d.waterTargetMl! > 0)
        .toList();

    if (daysWithTarget.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No hydration target data in this range',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Hydration Consistency',
                    style: theme.textTheme.titleSmall),
                const Spacer(),
                const Icon(Icons.water_drop,
                    size: 20, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 12),
            ...daysWithTarget.map((day) {
              final dt = DateTime.tryParse(day.date);
              final label =
                  dt != null ? DateFormat('MMM d').format(dt) : day.date;
              final progress =
                  (day.totalWaterMl / day.waterTargetMl!).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${Formatters.formatWater(day.totalWaterMl)} / ${Formatters.formatWater(day.waterTargetMl!.round())}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _BudgetAdherenceCard extends StatelessWidget {
  final List<DailyAnalytics> dailyData;
  const _BudgetAdherenceCard({required this.dailyData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysWithTarget = dailyData
        .where((d) => d.budgetPhp != null && d.budgetPhp! > 0)
        .toList();

    if (daysWithTarget.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No budget data in this range',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Budget Adherence', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            ...daysWithTarget.map((day) {
              final dt = DateTime.tryParse(day.date);
              final label =
                  dt != null ? DateFormat('MMM d').format(dt) : day.date;
              final progress =
                  (day.totalSpending / day.budgetPhp!).clamp(0.0, 1.0);
              final isOver = day.totalSpending > day.budgetPhp!;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${Formatters.formatPhp(day.totalSpending)} / ${Formatters.formatPhp(day.budgetPhp!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: isOver ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PreviousLogsCard extends StatelessWidget {
  final List<MealLog> recentLogs;
  const _PreviousLogsCard({required this.recentLogs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Meals', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (recentLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No meals logged in this range',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                ),
              )
            else
              ...recentLogs.map(
                (log) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.foodNameSnapshot,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${log.mealTypeCode.replaceAll('_', ' ')} · ${_formatLogDate(log.loggedAt)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.disabledColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.formatCalories(log.caloriesSnapshot),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatLogDate(String loggedAt) {
    final dt = DateTime.tryParse(loggedAt);
    if (dt == null) return loggedAt;
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}
