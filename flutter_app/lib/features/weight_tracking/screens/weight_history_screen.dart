import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/weight_log_repository.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/profile_settings/profile_provider.dart';

class WeightHistoryScreen extends ConsumerStatefulWidget {
  const WeightHistoryScreen({super.key});

  @override
  ConsumerState<WeightHistoryScreen> createState() =>
      _WeightHistoryScreenState();
}

class _WeightHistoryScreenState extends ConsumerState<WeightHistoryScreen> {
  DateTime _endDate = DateTime.now();
  late DateTime _startDate;
  int _selectedRangeDays = 30;
  List<WeightLog>? _logs;
  bool _isLoading = false;
  String? _error;

  static const _rangeOptions = <(String label, int days)>[
    ('7D', 7),
    ('30D', 30),
    ('3M', 90),
    ('6M', 180),
    ('1Y', 365),
    ('All', 3650),
  ];

  @override
  void initState() {
    super.initState();
    _startDate = _endDate.subtract(const Duration(days: 30));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = WeightLogRepository(DatabaseProvider());
      final startDate =
          '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
      final endDate =
          '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}';
      final logs =
          await repo.queryByUserAndDateRange(user.id, startDate, endDate);
      logs.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _setDateRange(int days) {
    setState(() {
      _selectedRangeDays = days;
      _endDate = DateTime.now();
      _startDate = _endDate.subtract(Duration(days: days));
    });
    _loadData();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedRangeDays = 0;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logs = _logs;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Weight Trend'),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState(theme)
              : logs == null || logs.isEmpty
                  ? _buildEmptyState(theme)
                  : _buildContent(theme, logs),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildContent(ThemeData theme, List<WeightLog> logs) {
    final currentWeight = logs.last.weightKg;
    final firstWeight = logs.first.weightKg;
    final change = currentWeight - firstWeight;
    final highest = logs.fold<double>(
        logs.first.weightKg, (max, l) => l.weightKg > max ? l.weightKg : max);
    final highestLog =
        logs.firstWhere((l) => l.weightKg == highest, orElse: () => logs.first);
    final lowest = logs.fold<double>(
        logs.first.weightKg, (min, l) => l.weightKg < min ? l.weightKg : min);
    final lowestLog =
        logs.firstWhere((l) => l.weightKg == lowest, orElse: () => logs.first);
    final totalDays = _endDate.difference(_startDate).inDays;
    final avgPerWeek = totalDays > 0 ? (change / totalDays * 7) : 0.0;

    final profile = ref.watch(profileProvider).valueOrNull;
    final goalWeight = profile?.targetWeightKg;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildCurrentWeightCard(theme, currentWeight, change, logs),
          const SizedBox(height: 16),
          _buildRangeSelector(),
          const SizedBox(height: 16),
          _buildChartSection(theme, logs, goalWeight),
          const SizedBox(height: 16),
          _buildStatsRow(theme, highest, lowest, change, avgPerWeek, highestLog,
              lowestLog),
          const SizedBox(height: 16),
          _buildMotivationBanner(theme, change, goalWeight, currentWeight),
          const SizedBox(height: 16),
          _buildLogNewWeightButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCurrentWeightCard(ThemeData theme, double currentWeight,
      double change, List<WeightLog> logs) {
    final latestDate = logs.isNotEmpty ? logs.last.loggedAt : '';
    final dt = DateTime.tryParse(latestDate);
    final dateStr = dt != null ? DateFormat('MMM d, yyyy').format(dt) : '';

    final previousDate = logs.length > 1 ? logs[logs.length - 2].loggedAt : '';
    final prevDt = DateTime.tryParse(previousDate);
    final prevDateStr =
        prevDt != null ? DateFormat('MMM d, yyyy').format(prevDt) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${currentWeight.toStringAsFixed(1)} kg',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (dateStr.isNotEmpty)
                          Text(
                            dateStr,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (change != 0)
                    change < 0
                        ? StatusTag.ok(
                            label: '-${change.abs().toStringAsFixed(1)} kg')
                        : StatusTag.over(
                            label: '+${change.abs().toStringAsFixed(1)} kg'),
                ],
              ),
              if (change != 0 && prevDateStr.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '${change < 0 ? "↓" : "↑"} ${change.abs().toStringAsFixed(1)} kg vs $prevDateStr',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<int>(
              segments: _rangeOptions.map((opt) {
                return ButtonSegment<int>(
                  value: opt.$2,
                  label: Text(opt.$1, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
              selected: {_selectedRangeDays},
              onSelectionChanged: (selected) {
                if (selected.isNotEmpty) _setDateRange(selected.first);
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primary,
                selectedForegroundColor: AppColors.textOnAccent,
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.calendar_today, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(
      ThemeData theme, List<WeightLog> logs, double? goalWeight) {
    final spots = logs.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.weightKg);
    }).toList();

    final displayWeights = logs.map((l) => l.weightKg).toList();
    final minY = displayWeights.reduce((a, b) => a < b ? a : b);
    final maxY = displayWeights.reduce((a, b) => a > b ? a : b);

    double chartMinY;
    double chartMaxY;

    if (goalWeight != null) {
      final allValues = [...displayWeights, goalWeight];
      chartMinY = allValues.reduce((a, b) => a < b ? a : b);
      chartMaxY = allValues.reduce((a, b) => a > b ? a : b);
    } else {
      chartMinY = minY;
      chartMaxY = maxY;
    }

    final yPadding = ((chartMaxY - chartMinY) * 0.2).clamp(1.0, 5.0);
    chartMinY = (chartMinY - yPadding).floorToDouble();
    chartMaxY = (chartMaxY + yPadding).ceilToDouble();

    final extraLines = <HorizontalLine>[];
    if (goalWeight != null &&
        goalWeight >= chartMinY &&
        goalWeight <= chartMaxY) {
      extraLines.add(
        HorizontalLine(
          y: goalWeight,
          color: AppColors.textSecondary,
          strokeWidth: 1,
          dashArray: [8, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.centerRight,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            labelResolver: (_) => 'Goal: ${goalWeight.toStringAsFixed(1)} kg',
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX:
                        (logs.length - 1).toDouble().clamp(0, double.infinity),
                    minY: chartMinY,
                    maxY: chartMaxY,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final index = spot.spotIndex;
                            if (index >= logs.length) return null;
                            final log = logs[index];
                            final dt = DateTime.tryParse(log.loggedAt);
                            return LineTooltipItem(
                              '${dt != null ? DateFormat('MMM d').format(dt) : ''}\n${spot.y.toStringAsFixed(1)} kg',
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
                          reservedSize: 30,
                          interval: _calcBottomInterval(logs.length),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= logs.length)
                              return const SizedBox.shrink();
                            final dt = DateTime.tryParse(logs[index].loggedAt);
                            if (dt == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('MMM d').format(dt),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(0),
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    extraLinesData: ExtraLinesData(horizontalLines: extraLines),
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
      ),
    );
  }

  Widget _buildStatsRow(
    ThemeData theme,
    double highest,
    double lowest,
    double change,
    double avgPerWeek,
    WeightLog highestLog,
    WeightLog lowestLog,
  ) {
    final highestDt = DateTime.tryParse(highestLog.loggedAt);
    final lowestDt = DateTime.tryParse(lowestLog.loggedAt);
    final highestDate =
        highestDt != null ? DateFormat('MMM d').format(highestDt) : '';
    final lowestDate =
        lowestDt != null ? DateFormat('MMM d').format(lowestDt) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  theme,
                  value: '${highest.toStringAsFixed(1)} kg',
                  label: 'Highest',
                  subLabel: highestDate,
                ),
              ),
              Container(
                  width: 1, height: 40, color: AppColors.divider.withAlpha(51)),
              Expanded(
                child: _buildStatItem(
                  theme,
                  value: '${lowest.toStringAsFixed(1)} kg',
                  label: 'Lowest',
                  subLabel: lowestDate,
                ),
              ),
              Container(
                  width: 1, height: 40, color: AppColors.divider.withAlpha(51)),
              Expanded(
                child: _buildStatItem(
                  theme,
                  value:
                      '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
                  label: 'Change',
                  subLabel:
                      '${_selectedRangeDays == 0 ? _endDate.difference(_startDate).inDays : _selectedRangeDays} Days',
                ),
              ),
              Container(
                  width: 1, height: 40, color: AppColors.divider.withAlpha(51)),
              Expanded(
                child: _buildStatItem(
                  theme,
                  value:
                      '${avgPerWeek >= 0 ? '+' : ''}${avgPerWeek.toStringAsFixed(2)} kg',
                  label: 'Avg / Week',
                  subLabel: '',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme, {
    required String value,
    required String label,
    required String subLabel,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
        if (subLabel.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            subLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildMotivationBanner(ThemeData theme, double change,
      double? goalWeight, double currentWeight) {
    String message;
    Color bgColor;
    Color textColor;
    IconData icon;

    if (goalWeight == null) {
      message =
          'Start logging your weight regularly to see your progress over time.';
      bgColor = AppColors.surfaceAlt;
      textColor = AppColors.textPrimary;
      icon = Icons.monitor_weight_outlined;
    } else {
      final distanceToGoal = currentWeight - goalWeight;
      final isMovingTowardGoal = (goalWeight < currentWeight && change < 0) ||
          (goalWeight > currentWeight && change > 0);

      if (distanceToGoal.abs() <= 1.0) {
        message = "Almost there! You're within 1 kg of your goal. Keep going!";
        bgColor = AppColors.surfaceAlt;
        textColor = AppColors.textPrimary;
        icon = Icons.emoji_events;
      } else if (isMovingTowardGoal) {
        message =
            'Great progress! You\'re on track to reach your goal. Keep it up!';
        bgColor = AppColors.surfaceAlt;
        textColor = AppColors.textPrimary;
        icon = Icons.trending_down;
      } else if (change == 0) {
        message =
            'Stay consistent with your logging. Every entry helps track your journey.';
        bgColor = AppColors.surfaceAlt;
        textColor = AppColors.textPrimary;
        icon = Icons.info_outline;
      } else {
        message =
            'You\'re moving away from your goal. Consider reviewing your nutrition plan.';
        bgColor = AppColors.surfaceAlt;
        textColor = AppColors.textPrimary;
        icon = Icons.warning_amber_outlined;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogNewWeightButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () => context.push('/weight'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnAccent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text(
            'Log New Weight',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go('/dashboard');
          case 1:
            context.go('/meal-log');
          case 2:
            context.push('/add-meal-log');
          case 3:
            context.go('/planner');
          case 4:
            context.go('/quick-actions');
        }
      },
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.restaurant_outlined),
          selectedIcon: Icon(Icons.restaurant),
          label: 'Log',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle, size: 28),
          label: '',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Planner',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'More',
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            'Unable to load weight history.',
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monitor_weight_outlined,
              size: 48, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 12),
          Text(
            'No weight data yet.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Start by logging your first weight.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push('/weight'),
            icon: const Icon(Icons.add),
            label: const Text('Log Weight'),
          ),
        ],
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
