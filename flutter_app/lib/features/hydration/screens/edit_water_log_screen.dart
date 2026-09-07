import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jcg_fitness/app/constants.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/database/water_log_repository.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/core/validators/validators.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/hydration/hydration_provider.dart';
import 'package:jcg_fitness/features/meal_logging/recent_logs_provider.dart';

class EditWaterLogScreen extends ConsumerStatefulWidget {
  final String waterLogId;

  const EditWaterLogScreen({super.key, required this.waterLogId});

  @override
  ConsumerState<EditWaterLogScreen> createState() => _EditWaterLogScreenState();
}

class _EditWaterLogScreenState extends ConsumerState<EditWaterLogScreen> {
  final _amountController = TextEditingController();
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
    _amountController.dispose();
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
      final log = await WaterLogRepository(DatabaseProvider())
          .readByIdForUser(widget.waterLogId, localUserId);
      if (log == null) {
        throw StateError('This water entry is no longer available.');
      }
      if (!mounted) return;
      setState(() {
        _amountController.text = log.amountMl.toString();
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
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || !Validators.isValidWaterAmount(amount)) {
      _showMessage(
        'Enter an amount from ${AppConstants.minWaterMlPerEntry} to '
        '${AppConstants.maxWaterMlPerEntry} ml.',
      );
      return;
    }
    if (_loggedAt.isAfter(DateTime.now())) {
      _showMessage('Water entries cannot be in the future.');
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
      await LocalTransactionHelper(DatabaseProvider()).updateWaterLog({
        'water_log_id': widget.waterLogId,
        'user_id': localUserId,
        'amount_ml': amount,
        'logged_at': _loggedAt.toUtc().toIso8601String(),
      });

      ref.invalidate(todayWaterProvider);
      ref.invalidate(todayWaterLogsProvider);
      ref.invalidate(pastWeekWaterProvider);
      ref.invalidate(hydrationHistoryProvider);
      ref.invalidate(hydrationHistoryLogsProvider);
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(recentLogsProvider);
      ref.read(syncProvider.notifier).startSync();

      if (!mounted) return;
      _showMessage('Water entry updated.', success: true);
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showMessage('Could not update water entry: $error');
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
        title: const Text('Edit Water Entry'),
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
                        'Update the amount or the time for this specific entry.',
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
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  suffixText: 'ml',
                                  prefixIcon: Icon(Icons.water_drop_outlined),
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
            const Icon(Icons.water_drop_outlined,
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
