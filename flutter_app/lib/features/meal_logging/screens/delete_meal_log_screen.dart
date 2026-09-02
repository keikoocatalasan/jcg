import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';

class DeleteMealLogScreen extends ConsumerStatefulWidget {
  final String mealLogId;
  final String mealType;
  final DateTime loggedAt;
  final int totalCalories;
  final int totalProtein;
  final int totalCarbs;
  final int totalFat;
  final List<FoodItem> foods;

  const DeleteMealLogScreen({
    super.key,
    required this.mealLogId,
    required this.mealType,
    required this.loggedAt,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.foods,
  });

  @override
  ConsumerState<DeleteMealLogScreen> createState() =>
      _DeleteMealLogScreenState();
}

class _DeleteMealLogScreenState extends ConsumerState<DeleteMealLogScreen> {
  bool _isDeleting = false;
  String? _selectedReason;

  static const _reasons = [
    'Duplicate entry',
    'Wrong food or portion',
    'Logged by mistake',
    'Changed meal plan',
    'Testing or sample data',
    'Other',
  ];

  String get _mealTypeDisplay {
    switch (widget.mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      default:
        return widget.mealType.replaceAll('_', ' ');
    }
  }

  IconData get _mealTypeIcon {
    switch (widget.mealType) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }

  Future<void> _delete() async {
    setState(() => _isDeleting = true);

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in')),
          );
        }
        return;
      }

      final localUserId = await LocalUserIdentity.resolve(
        DatabaseProvider(),
        user.id,
      );
      final helper = LocalTransactionHelper(DatabaseProvider());
      await helper.deleteMealLog(widget.mealLogId, localUserId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle,
                    color: AppColors.textPrimary, size: 18),
                SizedBox(width: 8),
                Text('Meal log deleted successfully'),
              ],
            ),
            backgroundColor: AppColors.error,
          ),
        );
        context.pop();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Delete Meal Log'),
      ),
      body: GlassBackground(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _WarningBanner(),
            const SizedBox(height: 16),
            _MealPreviewCard(
              mealTypeDisplay: _mealTypeDisplay,
              mealTypeIcon: _mealTypeIcon,
              loggedAt: widget.loggedAt,
              totalCalories: widget.totalCalories,
            ),
            const SizedBox(height: 16),
            _FoodsList(foods: widget.foods),
            const SizedBox(height: 16),
            _NutritionSummary(
              totalCalories: widget.totalCalories,
              totalProtein: widget.totalProtein,
              totalCarbs: widget.totalCarbs,
              totalFat: widget.totalFat,
            ),
            const SizedBox(height: 16),
            const _ConsequencesSection(),
            const SizedBox(height: 16),
            _ReasonDropdown(
              selectedReason: _selectedReason,
              reasons: _reasons,
              onChanged: (v) => setState(() => _selectedReason = v),
            ),
            const SizedBox(height: 16),
            _WarningCard(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isDeleting ? null : _delete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppSupportingColors.ink,
                      ),
                      child: _isDeleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppSupportingColors.ink,
                              ),
                            )
                          : const Text('Delete Meal Log'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed:
                          _isDeleting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FoodItem {
  final String name;
  final int calories;
  final int quantity;
  final String serving;
  final IconData icon;

  const FoodItem({
    required this.name,
    required this.calories,
    required this.quantity,
    required this.serving,
    required this.icon,
  });
}

class _WarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_outline,
                color: AppColors.error, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete this meal log?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This action cannot be undone.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealPreviewCard extends StatelessWidget {
  final String mealTypeDisplay;
  final IconData mealTypeIcon;
  final DateTime loggedAt;
  final int totalCalories;

  const _MealPreviewCard({
    required this.mealTypeDisplay,
    required this.mealTypeIcon,
    required this.loggedAt,
    required this.totalCalories,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(mealTypeIcon, color: AppColors.secondary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mealTypeDisplay,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${loggedAt.month.toString().padLeft(2, '0')}/${loggedAt.day.toString().padLeft(2, '0')}/${loggedAt.year} at ${TimeOfDay.fromDateTime(loggedAt).format(context)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.calorieColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  Formatters.formatCalories(totalCalories.toDouble()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.calorieColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodsList extends StatelessWidget {
  final List<FoodItem> foods;

  const _FoodsList({required this.foods});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foods in this meal',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...foods.map((food) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(food.icon,
                              size: 20, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              Text(
                                food.serving,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'x${food.quantity}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          Formatters.formatCalories(food.calories.toDouble()),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutritionSummary extends StatelessWidget {
  final int totalCalories;
  final int totalProtein;
  final int totalCarbs;
  final int totalFat;

  const _NutritionSummary({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nutrition Summary',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SummaryCard(
                    label: 'Calories',
                    value: '${totalCalories.round()}',
                    unit: 'kcal',
                    color: AppColors.calorieColor,
                    icon: Icons.local_fire_department,
                  ),
                  _SummaryCard(
                    label: 'Protein',
                    value: '$totalProtein',
                    unit: 'g',
                    color: AppColors.proteinColor,
                    icon: Icons.fitness_center,
                  ),
                  _SummaryCard(
                    label: 'Carbs',
                    value: '$totalCarbs',
                    unit: 'g',
                    color: AppColors.carbsColor,
                    icon: Icons.grain,
                  ),
                  _SummaryCard(
                    label: 'Fat',
                    value: '$totalFat',
                    unit: 'g',
                    color: AppColors.fatColor,
                    icon: Icons.opacity,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            unit,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

class _ConsequencesSection extends StatelessWidget {
  const _ConsequencesSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What will happen?',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              const _ConsequenceTile(
                icon: Icons.delete_outline,
                color: AppColors.error,
                title: 'All foods will be removed',
                subtitle:
                    'All food items logged in this meal will be permanently deleted.',
              ),
              const _ConsequenceTile(
                icon: Icons.trending_down,
                color: AppColors.warning,
                title: 'Daily totals will be reduced',
                subtitle:
                    'Calories, macros, and other nutrients for today will be recalculated.',
              ),
              const _ConsequenceTile(
                icon: Icons.sync_disabled,
                color: AppColors.textSecondary,
                title: 'Synced data will be removed',
                subtitle:
                    'If already synced, the meal will be removed from the cloud on next sync.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsequenceTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _ConsequenceTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonDropdown extends StatelessWidget {
  final String? selectedReason;
  final List<String> reasons;
  final ValueChanged<String?> onChanged;

  const _ReasonDropdown({
    required this.selectedReason,
    required this.reasons,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            initialValue: selectedReason,
            decoration: const InputDecoration(
              labelText: 'Tell us why (optional)',
              prefixIcon: Icon(Icons.feedback_outlined),
            ),
            items: reasons
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, size: 18, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Deleted items are not recoverable. Please review before confirming.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
