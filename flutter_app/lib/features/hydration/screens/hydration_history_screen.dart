import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/water_log_repository.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/features/hydration/hydration_provider.dart';

class HydrationHistoryScreen extends ConsumerStatefulWidget {
  const HydrationHistoryScreen({super.key});

  @override
  ConsumerState<HydrationHistoryScreen> createState() =>
      _HydrationHistoryScreenState();
}

class _HydrationHistoryScreenState
    extends ConsumerState<HydrationHistoryScreen> {
  int _selectedRangeDays = 7;
  bool _useLiters = true;

  static const _rangeOptions = <(String label, int days)>[
    ('7 Days', 7),
    ('30 Days', 30),
    ('3 Months', 90),
    ('1 Year', 365),
  ];

  String _formatVolume(int ml) {
    if (_useLiters) {
      return '${(ml / 1000).toStringAsFixed(1)} L';
    }
    return '$ml ml';
  }

  String _formatVolumeDouble(double ml) {
    if (_useLiters) {
      return '${(ml / 1000).toStringAsFixed(1)} L';
    }
    return '${ml.round()} ml';
  }

  @override
  Widget build(BuildContext context) {
    final historyData = ref.watch(hydrationHistoryProvider(_selectedRangeDays));
    final historyLogs =
        ref.watch(hydrationHistoryLogsProvider(_selectedRangeDays));
    final waterTarget = ref.watch(waterTargetProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Hydration History'),
      ),
      body: historyData.when(
        data: (data) {
          if (data.isEmpty) {
            return _buildEmptyState(theme);
          }
          return _buildContent(theme, data, historyLogs, waterTarget);
        },
        error: (err, _) => _buildErrorState(theme, err.toString()),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    List<Map<String, dynamic>> data,
    AsyncValue<List<WaterLog>> historyLogs,
    AsyncValue<int> waterTarget,
  ) {
    final target = waterTarget.valueOrNull ?? 2500;
    final totalMl = data.fold<int>(0, (sum, d) => sum + (d['total'] as int));
    final avgDaily = data.isNotEmpty ? totalMl / data.length : 0.0;
    final goalDays = data.where((d) => (d['total'] as int) >= target).length;
    final bestDay = data.fold<int>(
        0, (max, d) => (d['total'] as int) > max ? (d['total'] as int) : max);
    final goalPercent =
        target > 0 ? ((avgDaily / target) * 100).clamp(0, 100).round() : 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Review your water intake over time.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          _buildSegmentedButtons(),
          const SizedBox(height: 16),
          _buildSummaryCard(theme, avgDaily, target, goalPercent),
          const SizedBox(height: 16),
          _buildChartSection(theme, data),
          const SizedBox(height: 16),
          _buildStatsRow(theme, totalMl, avgDaily, goalDays, bestDay),
          const SizedBox(height: 16),
          _buildHistoryList(theme, historyLogs),
          const SizedBox(height: 12),
          _buildOfflineBanner(theme),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSegmentedButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<int>(
        segments: _rangeOptions.map((opt) {
          return ButtonSegment<int>(
            value: opt.$2,
            label: Text(opt.$1, style: const TextStyle(fontSize: 12)),
          );
        }).toList(),
        selected: {_selectedRangeDays},
        onSelectionChanged: (selected) {
          if (selected.isNotEmpty)
            setState(() => _selectedRangeDays = selected.first);
        },
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.primary,
          selectedForegroundColor: AppColors.textOnAccent,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      ThemeData theme, double avgDaily, int target, int goalPercent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Average Daily Intake',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline,
                            size: 14, color: AppColors.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatVolumeDouble(avgDaily),
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'of ${_formatVolume(target)} goal',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.trending_up,
                              size: 14, color: AppColors.textPrimary),
                          const SizedBox(width: 4),
                          Text(
                            '12% vs last $_selectedRangeDays days',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: goalPercent / 100,
                        strokeWidth: 8,
                        backgroundColor: AppColors.primary.withAlpha(30),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$goalPercent%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Goal Met',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection(ThemeData theme, List<Map<String, dynamic>> data) {
    final maxY = data.fold<double>(
        0,
        (max, d) =>
            (d['total'] as int) > max ? (d['total'] as int).toDouble() : max);
    final ceilingY = ((maxY / 500).ceil() * 500).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daily Intake Chart',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: true,
                          label: Text('L', style: TextStyle(fontSize: 12))),
                      ButtonSegment(
                          value: false,
                          label: Text('ml', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {_useLiters},
                    onSelectionChanged: (selected) {
                      if (selected.isNotEmpty)
                        setState(() => _useLiters = selected.first);
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppColors.primary,
                      selectedForegroundColor: AppColors.textOnAccent,
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textSecondary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: ceilingY == 0 ? 1000 : ceilingY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final dayData = data[groupIndex];
                          final total = dayData['total'] as int;
                          final dateStr = dayData['date'] as String;
                          final dt = DateTime.tryParse(dateStr);
                          final label = dt != null
                              ? DateFormat('MMM d').format(dt)
                              : dateStr;
                          return BarTooltipItem(
                            '$label\n${_formatVolume(total)}',
                            const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= data.length)
                              return const SizedBox.shrink();
                            final dayData = data[index];
                            final dateStr = dayData['date'] as String;
                            final dt = DateTime.tryParse(dateStr);
                            final dayName =
                                dt != null ? DateFormat('E').format(dt) : '';
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                dayName.length >= 3
                                    ? dayName.substring(0, 3)
                                    : dayName,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            );
                          },
                          reservedSize: 28,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox.shrink();
                            return Text(
                              _formatVolume(value.toInt()),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: ceilingY == 0 ? 500 : ceilingY / 4,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppColors.divider.withAlpha(51),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: data.asMap().entries.map((entry) {
                      final index = entry.key;
                      final total = (entry.value['total'] as int).toDouble();
                      final isToday = index == data.length - 1;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: total,
                            color: isToday
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            width: _selectedRangeDays <= 7
                                ? 24
                                : _selectedRangeDays <= 30
                                    ? 8
                                    : 4,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
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
      ThemeData theme, int total, double avg, int goalDays, int bestDay) {
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
                    theme, Icons.water_drop, _formatVolume(total), 'Total'),
              ),
              Container(
                  width: 1, height: 40, color: AppColors.divider.withAlpha(51)),
              Expanded(
                child: _buildStatItem(theme, Icons.calendar_today,
                    _formatVolumeDouble(avg), 'Average'),
              ),
              Container(
                  width: 1, height: 40, color: AppColors.divider.withAlpha(51)),
              Expanded(
                child: _buildStatItem(theme, Icons.check_circle_outline,
                    '$goalDays / $_selectedRangeDays', 'Goal Days'),
              ),
              Container(
                  width: 1, height: 40, color: AppColors.divider.withAlpha(51)),
              Expanded(
                child: _buildStatItem(theme, Icons.emoji_events_outlined,
                    _formatVolume(bestDay), 'Best Day'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
      ThemeData theme, IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHistoryList(
      ThemeData theme, AsyncValue<List<WaterLog>> historyLogs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: historyLogs.when(
        data: (logs) {
          if (logs.isEmpty) return const SizedBox.shrink();

          final Map<String, int> dailyTotals = {};
          for (final log in logs) {
            final date = log.loggedAt.substring(0, 10);
            dailyTotals[date] = (dailyTotals[date] ?? 0) + log.amountMl;
          }

          final sortedDates = dailyTotals.keys.toList()
            ..sort((a, b) => b.compareTo(a));
          final waterTarget = ref.read(waterTargetProvider).valueOrNull ?? 2500;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'History List',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...sortedDates.map((dateStr) {
                final total = dailyTotals[dateStr]!;
                final dt = DateTime.tryParse(dateStr);
                final percent =
                    waterTarget > 0 ? (total / waterTarget * 100).round() : 0;
                String status;
                if (percent >= 100) {
                  status = 'Goal Met';
                } else if (percent >= 80) {
                  status = 'On Track';
                } else {
                  status = 'Low';
                }

                final isToday =
                    dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());
                final dayLabel = isToday
                    ? 'Today'
                    : dt != null
                        ? DateFormat('EEEE').format(dt)
                        : dateStr;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.water_drop,
                          color: AppColors.textPrimary, size: 20),
                    ),
                    title: Text(
                      dayLabel,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: dt != null
                        ? Text(
                            DateFormat('MMM d, yyyy').format(dt),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatVolume(total),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        percent >= 100
                            ? StatusTag.ok(label: status)
                            : percent >= 80
                                ? StatusTag.ok(label: status)
                                : StatusTag.neutral(label: status),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
        error: (err, _) => const SizedBox.shrink(),
        loading: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildOfflineBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Data is synced when you are back online.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
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
          Icon(Icons.water_drop_outlined,
              size: 48, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 12),
          Text(
            'No hydration data yet.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Start logging water to see your history.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.water_drop_outlined),
            label: const Text('Log Water'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            'Unable to load history.',
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () =>
                ref.invalidate(hydrationHistoryProvider(_selectedRangeDays)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
