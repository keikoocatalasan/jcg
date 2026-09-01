import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/widgets/section_header.dart';
import 'package:jcg_fitness/features/onboarding/onboarding_controller.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_engine.dart';

String _goalLabel(String code) {
  switch (code) {
    case 'cutting':
      return 'Lose Weight';
    case 'bulking':
      return 'Build Muscle';
    case 'maintenance':
      return 'Stay Active';
    case 'lean':
    case 'lean_bulk':
      return 'Improve Health';
    case 'gain_weight':
      return 'Other / Custom';
    default:
      return code;
  }
}

String _activityLabel(String code) {
  switch (code) {
    case 'sedentary':
      return 'Sedentary';
    case 'light':
      return 'Light (1\u20133 days/week)';
    case 'moderate':
      return 'Moderate (3\u20135 days/week)';
    case 'active':
      return 'Active (6\u20137 days/week)';
    case 'very_active':
      return 'Very Active';
    default:
      return code;
  }
}

String _sexLabel(String code) => code == 'male' ? 'Male' : 'Female';

String _allergyLabel(String code) {
  switch (code) {
    case 'peanut':
      return 'Peanuts';
    case 'tree_nut':
      return 'Tree Nuts';
    case 'milk':
      return 'Dairy';
    case 'egg':
      return 'Eggs';
    case 'fish':
      return 'Fish';
    case 'shellfish':
      return 'Shellfish';
    case 'soy':
      return 'Soy';
    case 'wheat':
      return 'Wheat';
    case 'gluten':
      return 'Gluten';
    case 'sesame':
      return 'Sesame';
    default:
      return code;
  }
}

class OnboardingReviewScreen extends ConsumerStatefulWidget {
  const OnboardingReviewScreen({super.key});

  @override
  ConsumerState<OnboardingReviewScreen> createState() =>
      _OnboardingReviewScreenState();
}

class _OnboardingReviewScreenState
    extends ConsumerState<OnboardingReviewScreen> {
  void _submit() async {
    final notifier = ref.read(onboardingControllerProvider.notifier);
    await notifier.submitOnboarding();
    final updated = ref.read(onboardingControllerProvider);
    if (updated.isSubmitting == false && updated.error == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome! Your profile is set up.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);

    final normalizedGoal =
        state.fitnessGoalCode == 'lean_bulk' ? 'lean' : state.fitnessGoalCode;
    final target = NutritionEngine.calculateAll(
      weightKg: state.currentWeightKg,
      heightCm: state.heightCm,
      age: state.age,
      sexCode: state.sexCode,
      activityLevelCode: state.activityLevelCode,
      fitnessGoalCode: normalizedGoal,
    );
    final calories = target.calorieTarget;
    final protein = target.proteinG.round();
    final fats = target.fatG.round();
    final carbs = target.carbsG.round();

    final allergyLabels = state.allergies.map(_allergyLabel).toList();
    final restrictionLabels = state.dietaryRestrictions.map((c) {
      switch (c) {
        case 'vegetarian':
          return 'Vegetarian';
        case 'vegan':
          return 'Vegan';
        case 'lactose_intolerant':
          return 'Lactose Intolerant';
        case 'gluten_free':
          return 'Gluten Free';
        case 'low_carb':
          return 'Low Carb';
        case 'low_sodium':
          return 'Low Sodium';
        case 'diabetic':
          return 'Diabetic';
        case 'halal':
          return 'Halal';
        case 'no_pork':
          return 'No Pork';
        case 'no_beef':
          return 'No Beef';
        default:
          return c;
      }
    }).toList();

    final allAllergies = [...allergyLabels, ...restrictionLabels];
    final allergyText =
        allAllergies.isEmpty ? 'None selected' : allAllergies.join(', ');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/onboarding/budget'),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                  const Expanded(
                    child: SectionHeader(number: 7, title: 'review'),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/dashboard'),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Review Your Information',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.checklist_rtl,
                              size: 40, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please review your details below.\nYou can edit anything before we finish setup.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 24),
                    _ReviewCard(
                      icon: Icons.person_outline,
                      label: 'Nickname',
                      value:
                          state.nickname.isEmpty ? 'Not set' : state.nickname,
                      onEdit: () => context.go('/onboarding'),
                    ),
                    _ReviewCard(
                      icon: Icons.flag_outlined,
                      label: 'Goal',
                      value: _goalLabel(state.fitnessGoalCode),
                      onEdit: () => context.go('/onboarding/goal'),
                    ),
                    _ReviewCard(
                      icon: Icons.verified_outlined,
                      label: 'Health Disclaimer',
                      value: state.disclaimerAccepted
                          ? 'Accepted'
                          : 'Not accepted',
                      onEdit: () => context.go('/onboarding/disclaimer'),
                    ),
                    _ReviewCard(
                      icon: Icons.healing_outlined,
                      label: 'Allergies & Restrictions',
                      value: allergyText,
                      onEdit: () => context.go('/onboarding/allergies'),
                    ),
                    _ReviewCard(
                      icon: Icons.bar_chart_outlined,
                      label: 'User Stats',
                      value:
                          '${_sexLabel(state.sexCode)} \u2022 ${state.age} years old\n${state.heightCm.toStringAsFixed(0)} cm \u2022 ${state.currentWeightKg.toStringAsFixed(1)} kg\nActivity: ${_activityLabel(state.activityLevelCode)}',
                      onEdit: () => context.go('/onboarding/stats'),
                    ),
                    _ReviewCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Daily Budget',
                      value:
                          '\u20b1${state.dailyBudgetPhp.toStringAsFixed(0)}/day',
                      onEdit: () => context.go('/onboarding/budget'),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.divider.withAlpha(128)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Your Daily Targets',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Estimated',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.info_outline,
                                  size: 16, color: AppColors.textSecondary),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _TargetBox(
                                  icon: Icons.local_fire_department_outlined,
                                  label: 'Calories',
                                  value: '$calories',
                                  unit: 'kcal',
                                  color: AppColors.calorieColor),
                              const SizedBox(width: 8),
                              _TargetBox(
                                  icon: Icons.egg_outlined,
                                  label: 'Protein',
                                  value: '$protein',
                                  unit: 'g',
                                  color: AppColors.proteinColor),
                              const SizedBox(width: 8),
                              _TargetBox(
                                  icon: Icons.grain_outlined,
                                  label: 'Carbs',
                                  value: '$carbs',
                                  unit: 'g',
                                  color: AppColors.carbsColor),
                              const SizedBox(width: 8),
                              _TargetBox(
                                  icon: Icons.water_drop_outlined,
                                  label: 'Fats',
                                  value: '$fats',
                                  unit: 'g',
                                  color: AppColors.fatColor),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 16, color: AppColors.primary),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'These targets are personalized based on your info and goal.\nYou can adjust them later in Settings.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: AppColors.error.withAlpha(77)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(state.error!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: state.isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: state.isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.textPrimary),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Confirm & Finish Setup',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  SizedBox(width: 8),
                                  Icon(Icons.check_circle_outline, size: 20),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => context.go('/onboarding/budget'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Back',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                    top: BorderSide(color: AppColors.divider.withAlpha(128))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (i) {
                  final isActive = i == 6;
                  return Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color:
                              isActive ? AppColors.primary : AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.divider),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      if (i < 6)
                        Container(
                            width: 12, height: 2, color: AppColors.divider),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _ReviewCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withAlpha(128)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('Edit',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _TargetBox(
      {required this.icon,
      required this.label,
      required this.value,
      required this.unit,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(51)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            Text(unit, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
