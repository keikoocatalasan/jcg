import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/meal_plan_repository.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/meal_logging/recent_logs_provider.dart';
import 'package:jcg_fitness/features/meal_logging/meal_log_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/meal_planner/meal_planner_provider.dart';

class ConvertToLogDialog extends ConsumerStatefulWidget {
  final String dateStr;
  final List<MealPlan> plans;

  const ConvertToLogDialog({
    super.key,
    required this.dateStr,
    required this.plans,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String dateStr,
    required List<MealPlan> plans,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConvertToLogDialog(dateStr: dateStr, plans: plans),
    );
  }

  @override
  ConsumerState<ConvertToLogDialog> createState() => _ConvertToLogDialogState();
}

class _ConvertToLogDialogState extends ConsumerState<ConvertToLogDialog> {
  bool _isConverting = false;
  bool _markCompleted = true;

  static const _mealTypeLabels = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
  };

  _NutritionTotals get _totals {
    double cal = 0, pro = 0, carb = 0, fat = 0;
    for (final p in widget.plans) {
      cal += p.caloriesSnapshot;
      pro += p.proteinGsnapshot;
      carb += p.carbsGsnapshot;
      fat += p.fatGsnapshot;
    }
    return _NutritionTotals(cal, pro, carb, fat);
  }

  Future<void> _confirm() async {
    setState(() => _isConverting = true);

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        if (mounted) Navigator.of(context).pop(false);
        return;
      }
      final localUserId = await LocalUserIdentity.resolve(
        DatabaseProvider(),
        user.id,
      );

      final helper = LocalTransactionHelper(DatabaseProvider());
      final selectedDate = DateTime.tryParse(widget.dateStr);
      final currentTime = DateTime.now();
      final loggedAt = selectedDate == null
          ? currentTime
          : DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              currentTime.hour,
              currentTime.minute,
            );

      for (final plan in widget.plans) {
        if (plan.statusCode != 'planned') continue;

        final mealLogId = UuidHelper.generateUuid();
        final mealLogData = <String, dynamic>{
          'meal_log_id': mealLogId,
          'user_id': localUserId,
          'food_id': plan.foodId,
          'meal_type_code': plan.mealTypeCode,
          'food_name_snapshot': plan.foodNameSnapshot,
          'serving_grams_snapshot': plan.servingGramsSnapshot,
          'quantity': plan.quantity,
          'calories_snapshot': plan.caloriesSnapshot,
          'protein_g_snapshot': plan.proteinGsnapshot,
          'carbs_g_snapshot': plan.carbsGsnapshot,
          'fat_g_snapshot': plan.fatGsnapshot,
          'cost_php_snapshot': plan.costPhpSnapshot,
          'logged_at': loggedAt.toUtc().toIso8601String(),
          'is_deleted': 0,
        };

        await helper.convertPlanToLog(
          mealLogData: mealLogData,
          mealPlanId: plan.mealPlanId,
          userId: localUserId,
          markPlanCompleted: _markCompleted,
        );
      }

      ref.invalidate(plansForDateProvider(widget.dateStr));
      ref.invalidate(weeklyPlansProvider);
      ref.invalidate(recentLogsProvider);
      ref.invalidate(todayMealLogsProvider);
      ref.invalidate(mealLogsForDateProvider);
      ref.invalidate(dashboardDataProvider);
      ref.read(syncProvider.notifier).startSync();

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to convert: $e')),
        );
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = DateTime.tryParse(widget.dateStr);
    final dateLabel = dt != null
        ? DateFormat('EEEE, MMMM d, yyyy').format(dt)
        : widget.dateStr;
    final totals = _totals;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.swap_horiz,
                          color: AppColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Convert to Log',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will convert your planned meals for the selected day into actual meal log entries.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.calendar_today, label: 'Selected Day'),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Text(dateLabel,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Planned Meals to Convert (${widget.plans.where((p) => p.statusCode == 'planned').length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.plans.length,
                itemBuilder: (_, i) {
                  final plan = widget.plans[i];
                  final label =
                      _mealTypeLabels[plan.mealTypeCode] ?? plan.mealTypeCode;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.restaurant,
                              size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary)),
                              Text(
                                plan.foodNameSnapshot,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Formatters.formatCalories(plan.caloriesSnapshot),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NutrientStat(
                            label: 'Calories',
                            value: Formatters.formatCalories(totals.calories),
                            color: AppColors.calorieColor),
                        _NutrientStat(
                            label: 'Protein',
                            value: Formatters.formatMacro(totals.protein),
                            color: AppColors.proteinColor),
                        _NutrientStat(
                            label: 'Carbs',
                            value: Formatters.formatMacro(totals.carbs),
                            color: AppColors.carbsColor),
                        _NutrientStat(
                            label: 'Fat',
                            value: Formatters.formatMacro(totals.fat),
                            color: AppColors.fatColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This action creates meal log records from your planned meals.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _markCompleted,
                    onChanged: (v) =>
                        setState(() => _markCompleted = v ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Mark planned items as completed after logging',
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      'You can still view plans in your history.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isConverting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isConverting ? null : _confirm,
                      icon: _isConverting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.textPrimary))
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Convert to Meal Log'),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _NutrientStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _NutrientStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label,
            style: TextStyle(fontSize: 10, color: color.withAlpha(180))),
      ],
    );
  }
}

class _NutritionTotals {
  final double calories, protein, carbs, fat;
  _NutritionTotals(this.calories, this.protein, this.carbs, this.fat);
}
