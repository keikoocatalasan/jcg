import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';

class NutritionTargetScreen extends ConsumerWidget {
  const NutritionTargetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetAsync = ref.watch(nutritionTargetProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition Targets')),
      body: targetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load targets: $e'),
            ],
          ),
        ),
        data: (result) {
          if (result == null) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline,
                      size: 48, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('No nutrition targets calculated yet.'),
                  SizedBox(height: 8),
                  Text(
                      'Complete onboarding or log your weight to generate targets.'),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader(title: 'Energy'),
              _TargetRow(
                icon: Icons.local_fire_department,
                color: AppColors.calorieColor,
                label: 'BMR',
                value: '${result.bmr.round()} kcal',
              ),
              _TargetRow(
                icon: Icons.bolt,
                color: AppColors.primary,
                label: 'TDEE',
                value: '${result.tdee.round()} kcal',
              ),
              _TargetRow(
                icon: Icons.flag,
                color: AppColors.success,
                label: 'Calorie Target',
                value: '${result.calorieTarget.round()} kcal',
              ),
              const SizedBox(height: 16),
              _SectionHeader(title: 'Macros'),
              _TargetRow(
                icon: Icons.egg_alt,
                color: AppColors.proteinColor,
                label: 'Protein',
                value: '${result.proteinG.round()}g',
              ),
              _TargetRow(
                icon: Icons.grain,
                color: AppColors.carbsColor,
                label: 'Carbs',
                value: '${result.carbsG.round()}g',
              ),
              _TargetRow(
                icon: Icons.water_drop,
                color: AppColors.fatColor,
                label: 'Fat',
                value: '${result.fatG.round()}g',
              ),
              const SizedBox(height: 16),
              _SectionHeader(title: 'Hydration'),
              _TargetRow(
                icon: Icons.water,
                color: Colors.blue,
                label: 'Water Target',
                value: Formatters.formatWater(result.waterTargetMl.toInt()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _TargetRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
