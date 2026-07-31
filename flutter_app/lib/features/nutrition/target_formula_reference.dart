import 'package:flutter/material.dart';
import 'package:jcg_fitness/app/theme.dart';

class TargetFormulaReference extends StatelessWidget {
  const TargetFormulaReference({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target Formula Reference',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const _FormulaSection(
              title: 'Basal Metabolic Rate (Mifflin-St Jeor)',
              formulas: [
                'Male: BMR = 10W + 6.25H − 5A + 5',
                'Female: BMR = 10W + 6.25H − 5A − 161',
              ],
              legend: 'W = weight (kg), H = height (cm), A = age (years)',
            ),
            const Divider(height: 32),
            const _FormulaSection(
              title: 'Total Daily Energy Expenditure',
              formulas: [
                'TDEE = BMR × Activity Multiplier',
              ],
              legend: 'Sedentary 1.20 | Light 1.375 | Moderate 1.55\n'
                  'Active 1.725 | Very Active 1.90',
            ),
            const Divider(height: 32),
            const _FormulaSection(
              title: 'Goal Calorie Adjustment',
              formulas: [
                'Target Calories = TDEE + Adjustment',
              ],
              legend: 'Cutting −400 | Maintenance 0 | Bulking +400\n'
                  'Lean +200 | Gain Weight +500',
            ),
            const Divider(height: 32),
            const _FormulaSection(
              title: 'Macronutrient Distribution',
              formulas: [
                'Protein (g)  = (Calories × P%) ÷ 4',
                'Carbs   (g)  = (Calories × C%) ÷ 4',
                'Fat     (g)  = (Calories × F%) ÷ 9',
              ],
              legend: 'Cutting:        30P / 45C / 25F\n'
                  'Maintenance: 25P / 50C / 25F\n'
                  'Bulking:       30P / 50C / 20F\n'
                  'Lean:           30P / 45C / 25F\n'
                  'Gain Weight: 25P / 55C / 20F',
            ),
            const Divider(height: 32),
            const _FormulaSection(
              title: 'Hydration Target',
              formulas: [
                'Water (mL) = W × 35   (rounded to nearest 100)',
              ],
              legend: 'W = weight (kg)',
            ),
          ],
        ),
      ),
    );
  }
}

class _FormulaSection extends StatelessWidget {
  final String title;
  final List<String> formulas;
  final String legend;

  const _FormulaSection({
    required this.title,
    required this.formulas,
    required this.legend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...formulas.map(
          (f) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    f,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            legend,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
