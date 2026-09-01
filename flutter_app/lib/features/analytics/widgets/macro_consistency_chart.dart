import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:jcg_fitness/app/theme.dart';

class MacroConsistencyChart extends StatelessWidget {
  final double proteinPercent;
  final double carbsPercent;
  final double fatPercent;

  const MacroConsistencyChart({
    super.key,
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = proteinPercent > 0 || carbsPercent > 0 || fatPercent > 0;

    if (!hasData) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No macro data in this range',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final total = proteinPercent + carbsPercent + fatPercent;
    final pct = total > 0 ? total : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Macro Distribution', style: theme.textTheme.titleSmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            value: proteinPercent / pct * 100,
                            title: '${proteinPercent.toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textOnAccent,
                            ),
                            radius: _sectionRadius(proteinPercent / pct * 100),
                            color: AppColors.accentPrimary,
                          ),
                          PieChartSectionData(
                            value: carbsPercent / pct * 100,
                            title: '${carbsPercent.toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textOnAccent,
                            ),
                            radius: _sectionRadius(carbsPercent / pct * 100),
                            color: AppColors.proteinColor,
                          ),
                          PieChartSectionData(
                            value: fatPercent / pct * 100,
                            title: '${fatPercent.toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textOnAccent,
                            ),
                            radius: _sectionRadius(fatPercent / pct * 100),
                            color: AppColors.carbsColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendItem(
                        color: AppColors.accentPrimary,
                        label: 'Protein',
                        value: proteinPercent.toStringAsFixed(0),
                      ),
                      const SizedBox(height: 8),
                      _LegendItem(
                        color: AppColors.proteinColor,
                        label: 'Carbs',
                        value: carbsPercent.toStringAsFixed(0),
                      ),
                      const SizedBox(height: 8),
                      _LegendItem(
                        color: AppColors.carbsColor,
                        label: 'Fat',
                        value: fatPercent.toStringAsFixed(0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _sectionRadius(double percentage) {
    if (percentage > 50) return 55;
    if (percentage > 25) return 50;
    return 45;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $value%',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
