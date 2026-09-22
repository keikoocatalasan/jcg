import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/body_metrics/bmi_calculator.dart';

class BmiSummaryCard extends StatelessWidget {
  const BmiSummaryCard({
    super.key,
    required this.result,
    this.isLoading = false,
    this.hasError = false,
  });

  final BmiResult? result;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adultCategory = result?.adultCategory;
    final measurementDate = result?.measuredAt == null
        ? null
        : DateTime.tryParse(result!.measuredAt!)?.toLocal();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_weight_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Body Mass Index (BMI)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isLoading && result == null)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasError)
              Text(
                'BMI is temporarily unavailable. Your weight tracking is unaffected.',
                style: theme.textTheme.bodyMedium,
              )
            else if (result == null)
              Text(
                isLoading
                    ? 'Calculating from your measurements…'
                    : 'Add your height and weight to calculate BMI.',
                style: theme.textTheme.bodyMedium,
              )
            else ...[
              Text(
                '${result!.bmi.toStringAsFixed(1)} kg/m²',
                key: const Key('current_bmi_value'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              if (adultCategory != null)
                Text(
                  'Adult reference category: ${adultCategory.label}',
                  key: const Key('adult_bmi_category'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  'Adult categories are for ages 20+. BMI-for-age interpretation is not included in this version.',
                  key: const Key('bmi_youth_note'),
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: 4),
              Text(
                measurementDate == null
                    ? 'Based on your profile measurements'
                    : 'Weight recorded ${DateFormat('MMM d, yyyy').format(measurementDate)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'BMI is a screening estimate, not a diagnosis. It does not distinguish muscle, fat, and bone mass.',
              key: const Key('bmi_disclaimer'),
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
