import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jcg_fitness/app/constants.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/database/profile_repository.dart';
import 'package:jcg_fitness/core/database/weight_log_repository.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/meal_logging/recent_logs_provider.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_engine.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';
import 'package:jcg_fitness/features/weight_tracking/weight_provider.dart';
import 'package:jcg_fitness/features/weight_tracking/weight_log_timeline.dart';

class EditWeightLogScreen extends ConsumerStatefulWidget {
  final String weightLogId;

  const EditWeightLogScreen({super.key, required this.weightLogId});

  @override
  ConsumerState<EditWeightLogScreen> createState() =>
      _EditWeightLogScreenState();
}

class _EditWeightLogScreenState extends ConsumerState<EditWeightLogScreen> {
  final _weightController = TextEditingController();
  DateTime _loggedAt = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadLog() async {
    try {
      final user = await ref.read(authStateProvider.future);
      if (user == null) throw StateError('You must be logged in.');
      final localUserId = await LocalUserIdentity.resolve(
        DatabaseProvider(),
        user.id,
      );
      final log = await WeightLogRepository(DatabaseProvider())
          .readByIdForUser(widget.weightLogId, localUserId);
      if (log == null) {
        throw StateError('This weight entry is no longer available.');
      }
      if (!mounted) return;
      setState(() {
        _weightController.text = log.weightKg.toStringAsFixed(1);
        _loggedAt =
            DateTime.tryParse(log.loggedAt)?.toLocal() ?? DateTime.now();
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _loggedAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _loggedAt.hour,
        _loggedAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _loggedAt = DateTime(
        _loggedAt.year,
        _loggedAt.month,
        _loggedAt.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  Future<void> _save() async {
    final weightKg = double.tryParse(_weightController.text.trim());
    if (weightKg == null ||
        weightKg < AppConstants.minWeightKg ||
        weightKg > AppConstants.maxWeightKg) {
      _showMessage(
        'Enter a weight from ${AppConstants.minWeightKg.toStringAsFixed(0)} to '
        '${AppConstants.maxWeightKg.toStringAsFixed(0)} kg.',
      );
      return;
    }
    if (_loggedAt.isAfter(DateTime.now())) {
      _showMessage('Weight entries cannot be in the future.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = await ref.read(authStateProvider.future);
      if (user == null) throw StateError('You must be logged in.');
      final localUserId = await LocalUserIdentity.resolve(
        DatabaseProvider(),
        user.id,
      );
      final weightRepo = WeightLogRepository(DatabaseProvider());
      final latest = await weightRepo.readLatest(localUserId);
      final existingLogs = await weightRepo.queryByUser(localUserId);
      final editedLog = existingLogs.firstWhere(
        (log) => log.weightLogId == widget.weightLogId,
        orElse: () =>
            throw StateError('This weight entry is no longer available.'),
      );
      final editedLoggedAt = _loggedAt.toUtc().toIso8601String();
      final latestAfterEdit = selectLatestWeightAfterEdit(
        logs: existingLogs,
        editedLog: editedLog,
        editedWeightKg: weightKg,
        editedLoggedAt: editedLoggedAt,
      );
      final latestChanged =
          latest?.weightLogId != latestAfterEdit.weightLogId ||
              latest?.weightKg != latestAfterEdit.weightKg ||
              latest?.loggedAt != latestAfterEdit.loggedAt;

      Map<String, dynamic>? profileUpdate;
      Map<String, dynamic>? newTarget;
      Map<String, dynamic>? dailySnapshot;

      if (latestChanged) {
        final profile =
            await ProfileRepository(DatabaseProvider()).readByUserId(user.id);
        if (profile != null &&
            profile.sexCode != null &&
            profile.age != null &&
            profile.heightCm != null &&
            profile.activityLevelCode != null &&
            profile.fitnessGoalCode != null) {
          final result = NutritionEngine.calculateAll(
            weightKg: latestAfterEdit.weightKg,
            heightCm: profile.heightCm!,
            age: profile.age!,
            sexCode: profile.sexCode!,
            activityLevelCode: profile.activityLevelCode!,
            fitnessGoalCode: profile.fitnessGoalCode!,
          );
          final targetId = UuidHelper.generateUuid();
          final snapshotId = UuidHelper.generateUuid();
          profileUpdate = {'current_weight_kg': latestAfterEdit.weightKg};
          newTarget = {
            'target_id': targetId,
            'formula_version_code': 'mifflin_stjeor',
            'fitness_goal_code': profile.fitnessGoalCode,
            'source_weight_log_id': latestAfterEdit.weightLogId,
            'bmr': result.bmr,
            'tdee': result.tdee,
            'calorie_target': result.calorieTarget,
            'protein_target_g': result.proteinG,
            'carbs_target_g': result.carbsG,
            'fat_target_g': result.fatG,
            'water_target_ml': result.waterTargetMl,
            'effective_from': DateHelper.todayDate(),
            'effective_to': null,
          };
          dailySnapshot = {
            'snapshot_id': snapshotId,
            'nutrition_target_id': targetId,
            'target_date': DateHelper.todayDate(),
            'calorie_target_snapshot': result.calorieTarget,
            'protein_target_g_snapshot': result.proteinG,
            'carbs_target_g_snapshot': result.carbsG,
            'fat_target_g_snapshot': result.fatG,
            'water_target_ml_snapshot': result.waterTargetMl,
            'daily_budget_php_snapshot': profile.dailyBudgetPhp ?? 0,
          };
        }
      }

      await LocalTransactionHelper(DatabaseProvider())
          .updateWeightLogAndRecalculate(
        weightLogData: {
          'weight_log_id': widget.weightLogId,
          'user_id': localUserId,
          'weight_kg': weightKg,
          'logged_at': _loggedAt.toUtc().toIso8601String(),
        },
        profileUpdateData: profileUpdate,
        newTargetData: newTarget,
        dailySnapshotData: dailySnapshot,
      );

      ref.invalidate(latestWeightProvider);
      ref.invalidate(weightHistoryProvider);
      ref.invalidate(nutritionTargetProvider);
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(recentLogsProvider);
      ref.read(syncProvider.notifier).startSync();

      if (!mounted) return;
      _showMessage('Weight entry updated.', success: true);
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showMessage('Could not update weight entry: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Weight Entry'),
        actions: [
          TextButton(
            onPressed: _isLoading || _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: GlassBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _loadLog)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Update the value or the time for this specific entry.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextField(
                                controller: _weightController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Weight',
                                  suffixText: 'kg',
                                  prefixIcon:
                                      Icon(Icons.monitor_weight_outlined),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DateButton(
                                      icon: Icons.calendar_today_outlined,
                                      label: DateHelper.formatDate(
                                        _loggedAt.toIso8601String(),
                                      ),
                                      onTap: _pickDate,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _DateButton(
                                      icon: Icons.access_time_outlined,
                                      label: DateHelper.formatTime(
                                        _loggedAt.toIso8601String(),
                                      ),
                                      onTap: _pickTime,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: const Icon(Icons.check),
                        label: const Text('Save changes'),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DateButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monitor_weight_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
