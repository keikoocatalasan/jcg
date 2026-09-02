import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/meal_plan_repository.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';

class MarkSkippedDialog extends ConsumerStatefulWidget {
  final String dateStr;
  final List<MealPlan> plans;

  const MarkSkippedDialog({
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
      builder: (_) => MarkSkippedDialog(dateStr: dateStr, plans: plans),
    );
  }

  @override
  ConsumerState<MarkSkippedDialog> createState() => _MarkSkippedDialogState();
}

class _MarkSkippedDialogState extends ConsumerState<MarkSkippedDialog> {
  bool _isSaving = false;

  static const _mealTypeLabels = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
  };

  Future<void> _confirm() async {
    setState(() => _isSaving = true);

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

      final db = await DatabaseProvider().database;
      final now = DateTime.now().toUtc().toIso8601String();

      for (final plan in widget.plans) {
        if (plan.statusCode != 'planned') continue;

        await db.transaction((txn) async {
          await txn.update(
            'meal_plans',
            {
              'status_code': 'skipped',
              'sync_status': 'pending',
              'updated_at': now,
            },
            where: 'meal_plan_id = ?',
            whereArgs: [plan.mealPlanId],
          );

          await txn.insert('sync_queue', {
            'sync_queue_id': UuidHelper.generateUuid(),
            'user_id': localUserId,
            'operation_id': UuidHelper.generateOperationId(),
            'entity_type_code': 'meal_plan',
            'entity_id': plan.mealPlanId,
            'operation_code': 'update',
            'payload_json': jsonEncode({
              'meal_plan_id': plan.mealPlanId,
              'status_code': 'skipped',
            }),
            'client_sequence': DateTime.now().millisecondsSinceEpoch,
            'attempt_count': 0,
            'sync_status': 'pending',
            'created_at': now,
          });
        });
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as skipped: $e')),
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
    final plannedMeals =
        widget.plans.where((p) => p.statusCode == 'planned').toList();

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
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mark Day as Skipped',
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
                    'Are you sure you want to mark this day as skipped?',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All planned meals for this day will be marked as skipped and will not be converted to meal log entries.',
                    style: theme.textTheme.bodySmall
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
                    'Affected Planned Meals (${plannedMeals.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold, color: AppColors.warning),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: plannedMeals.length,
                itemBuilder: (_, i) {
                  final plan = plannedMeals[i];
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
                            color: AppColors.warning.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.restaurant,
                              size: 18, color: AppColors.warning),
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You can still view this day in history and restore it later.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Skipped items remain in your planner history.',
                    style: theme.textTheme.bodyMedium,
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
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _confirm,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.textPrimary))
                          : const Icon(Icons.skip_next, size: 18),
                      label: const Text('Mark Day as Skipped'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.warning),
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
