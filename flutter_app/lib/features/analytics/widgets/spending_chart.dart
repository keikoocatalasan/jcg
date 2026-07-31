import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/features/analytics/analytics_provider.dart';

class SpendingChart extends StatelessWidget {
  final List<DailyAnalytics> dailyData;

  const SpendingChart({super.key, required this.dailyData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysWithSpending =
        dailyData.where((d) => d.totalSpending > 0).toList();

    if (daysWithSpending.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No spending data in this range',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final maxSpending = daysWithSpending.fold<double>(
      0,
      (max, d) => d.totalSpending > max ? d.totalSpending : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending', style: theme.textTheme.titleSmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxSpending * 1.2)
                      .ceilToDouble()
                      .clamp(50, double.infinity),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final day = daysWithSpending[groupIndex];
                        final dt = DateTime.tryParse(day.date);
                        return BarTooltipItem(
                          '${dt != null ? DateFormat('MMM d').format(dt) : day.date}\n${Formatters.formatPhp(day.totalSpending)}',
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
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= daysWithSpending.length) {
                            return const SizedBox.shrink();
                          }
                          final dt =
                              DateTime.tryParse(daysWithSpending[index].date);
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
                        interval: _calcBottomInterval(daysWithSpending.length),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            '₱${value.toInt()}',
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
                  barGroups: daysWithSpending.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.totalSpending,
                          color: AppColors.textPrimary,
                          width: _barWidth(daysWithSpending.length),
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
    );
  }

  double _barWidth(int count) {
    if (count <= 7) return 20;
    if (count <= 14) return 12;
    if (count <= 30) return 6;
    return 4;
  }

  double _calcBottomInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 30) return 5;
    return 7;
  }
}
