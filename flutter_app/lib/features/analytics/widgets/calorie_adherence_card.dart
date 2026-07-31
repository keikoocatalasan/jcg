import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/features/analytics/analytics_provider.dart';

class CalorieAdherenceCard extends StatelessWidget {
  final List<DailyAnalytics> dailyData;

  const CalorieAdherenceCard({super.key, required this.dailyData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysWithTarget = dailyData
        .where((d) => d.calorieTarget != null && d.calorieTarget! > 0)
        .toList();

    if (daysWithTarget.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No calorie target data in this range',
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
            Text('Calorie Adherence', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            ...daysWithTarget.map((day) {
              final dt = DateTime.tryParse(day.date);
              final label =
                  dt != null ? DateFormat('MMM d').format(dt) : day.date;
              final progress =
                  (day.totalCalories / day.calorieTarget!).clamp(0.0, 1.0);
              final isOver = day.totalCalories > day.calorieTarget!;

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
                          '${Formatters.formatCalories(day.totalCalories)} / ${Formatters.formatCalories(day.calorieTarget!)}',
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
