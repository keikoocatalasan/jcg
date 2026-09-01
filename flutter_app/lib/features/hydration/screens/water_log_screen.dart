import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/constants.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/water_log_repository.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/meal_logging/recent_logs_provider.dart';
import 'package:jcg_fitness/features/hydration/hydration_provider.dart';

class WaterLogScreen extends ConsumerStatefulWidget {
  const WaterLogScreen({super.key});

  @override
  ConsumerState<WaterLogScreen> createState() => _WaterLogScreenState();
}

class _WaterLogScreenState extends ConsumerState<WaterLogScreen> {
  bool _isSaving = false;

  static const _presetIcons = [
    Icons.water_drop_outlined,
    Icons.water_drop_outlined,
    Icons.local_drink_outlined,
    Icons.local_drink_outlined,
  ];

  Future<void> _logWater(int amountMl) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final now = DateHelper.nowUtc();
      final helper = LocalTransactionHelper(DatabaseProvider());
      await helper.createWaterLog({
        'water_log_id': UuidHelper.generateUuid(),
        'user_id': user.id,
        'amount_ml': amountMl,
        'logged_at': now,
      });

      ref.invalidate(todayWaterProvider);
      ref.invalidate(todayWaterLogsProvider);
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(recentLogsProvider);
      ref.read(syncProvider.notifier).startSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                    '${Formatters.formatWater(amountMl)} added to your water log!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log water: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteWaterLog(WaterLog log) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    try {
      final helper = LocalTransactionHelper(DatabaseProvider());
      await helper.deleteWaterLog(log.waterLogId, user.id);

      ref.invalidate(todayWaterProvider);
      ref.invalidate(todayWaterLogsProvider);
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(recentLogsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  void _showEditGoalDialog() {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final currentTarget = ref.read(waterTargetProvider).valueOrNull ?? 2500;
    final controller = TextEditingController(text: currentTarget.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Water Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Daily goal (mL)',
            suffixText: 'mL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newTarget = int.tryParse(controller.text.trim());
              if (newTarget == null || newTarget < 500 || newTarget > 10000) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Enter a value between 500-10000 mL')),
                );
                return;
              }
              await updateWaterTarget(userId: user.id, newTargetMl: newTarget);
              ref.invalidate(waterTargetProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomSheet() {
    int amountMl = 350;
    final customPresets = [
      (ml: 250, label: '250\nml', icon: Icons.water_drop_outlined),
      (ml: 500, label: '500\nml', icon: Icons.water_drop_outlined),
      (ml: 750, label: '750\nml', icon: Icons.water_drop_outlined),
      (ml: 1000, label: '1\nL', icon: Icons.local_drink_outlined),
      (ml: 2000, label: '2\nL', icon: Icons.local_drink_outlined),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);

          void updateAmount(int newAmount) {
            setSheetState(() {
              amountMl = newAmount.clamp(AppConstants.minWaterMlPerEntry,
                  AppConstants.maxWaterMlPerEntry);
            });
          }

          void appendDigit(String digit) {
            final currentStr = amountMl.toString();
            if (digit == '.' && currentStr.contains('.')) return;
            final newStr = currentStr + digit;
            final newAmount = int.tryParse(newStr);
            if (newAmount != null &&
                newAmount <= AppConstants.maxWaterMlPerEntry) {
              setSheetState(() => amountMl = newAmount);
            }
          }

          void backspace() {
            final currentStr = amountMl.toString();
            if (currentStr.length <= 1) {
              setSheetState(() => amountMl = AppConstants.minWaterMlPerEntry);
            } else {
              final newStr = currentStr.substring(0, currentStr.length - 1);
              final newAmount = int.tryParse(newStr);
              if (newAmount != null &&
                  newAmount >= AppConstants.minWaterMlPerEntry) {
                setSheetState(() => amountMl = newAmount);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.water_drop,
                          color: AppColors.textPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Custom Amount',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Enter the amount of water you drank.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => updateAmount(amountMl - 50),
                      icon: const Icon(Icons.remove_circle_outline, size: 40),
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$amountMl',
                      style: theme.textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ml',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => updateAmount(amountMl + 50),
                      icon: const Icon(Icons.add_circle_outline, size: 40),
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: amountMl.toDouble().clamp(50.0, 2000.0),
                  min: 50,
                  max: 2000,
                  divisions: 39,
                  activeColor: AppColors.primary,
                  onChanged: (value) => updateAmount(value.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('50 ml',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                    Text('2000 ml',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: customPresets.map((preset) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => updateAmount(preset.ml),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: amountMl == preset.ml
                                    ? AppColors.primary
                                    : AppColors.divider,
                                width: amountMl == preset.ml ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: amountMl == preset.ml
                                  ? AppColors.primary.withAlpha(15)
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Icon(preset.icon,
                                    size: 20, color: AppColors.primary),
                                const SizedBox(height: 4),
                                Text(
                                  preset.label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: amountMl == preset.ml
                                        ? AppColors.primary
                                        : null,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildNumpad(theme, appendDigit, backspace),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This will add $amountMl ml to your water log for today.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/hydration/history');
                        },
                        child: const Text('View Log'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _logWater(amountMl);
                  },
                  icon: const Icon(Icons.water_drop),
                  label: Text('Add $amountMl ml'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNumpad(ThemeData theme, void Function(String) onDigit,
      VoidCallback onBackspace) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '⌫'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: row.map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: key == '⌫' ? onBackspace : () => onDigit(key),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: key == '⌫'
                            ? AppColors.error.withAlpha(15)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppColors.divider.withAlpha(51)),
                      ),
                      child: Center(
                        child: key == '⌫'
                            ? const Icon(Icons.backspace_outlined,
                                size: 20, color: AppColors.error)
                            : Text(
                                key,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayTotal = ref.watch(todayWaterProvider);
    final waterTarget = ref.watch(waterTargetProvider);
    final todayLogs = ref.watch(todayWaterLogsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayWaterProvider);
          ref.invalidate(todayWaterLogsProvider);
          ref.invalidate(waterTargetProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Track your daily water intake and stay hydrated.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildProgressCard(todayTotal, waterTarget),
              const SizedBox(height: 20),
              _buildQuickAddSection(),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _isSaving ? null : _showAddCustomSheet,
                    icon: const Icon(Icons.water_drop_outlined),
                    label: const Text('Add Custom Amount'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildHistorySection(todayLogs),
              const SizedBox(height: 12),
              _buildInfoBanner(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(
      AsyncValue<int> todayTotal, AsyncValue<int> waterTarget) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: todayTotal.when(
            data: (total) {
              final target = waterTarget.valueOrNull ?? 2500;
              final progress = target > 0 ? total / target : 0.0;
              final percent = (progress.clamp(0.0, 1.0) * 100).round();
              final remaining = (target - total).clamp(0, target);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Progress",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$percent%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Formatters.formatWater(total),
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'of ${Formatters.formatWater(target)} goal',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor:
                                    AppColors.primary.withAlpha(38),
                                valueColor: AlwaysStoppedAnimation(
                                  progress >= 1.0
                                      ? AppColors.success
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Remaining: ${Formatters.formatWater(remaining)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.water_drop,
                          size: 40,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _showEditGoalDialog,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_outlined,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Edit Goal',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            error: (err, _) => Text('Error: $err'),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddSection() {
    final theme = Theme.of(context);
    const presets = AppConstants.waterPresets;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Add',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tips',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ...presets.asMap().entries.map((entry) {
                final index = entry.key;
                final ml = entry.value;
                return SizedBox(
                  width: 64,
                  child: _buildPresetCard(ml, _presetIcons[index]),
                );
              }),
              SizedBox(
                width: 64,
                child: GestureDetector(
                  onTap: _showAddCustomSheet,
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Custom',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(int ml, IconData icon) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: _isSaving ? null : () => _logWater(ml),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Formatters.formatWater(ml),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(AsyncValue<List<WaterLog>> todayLogs) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's History",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/hydration/history'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Chart',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.bar_chart,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          todayLogs.when(
            data: (logs) {
              if (logs.isEmpty) {
                return _buildEmptyState();
              }
              return _buildLogList(logs);
            },
            error: (err, _) => _buildErrorState(err.toString()),
            loading: () => _buildLoadingState(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(List<WaterLog> logs) {
    final theme = Theme.of(context);

    return Column(
      children: logs.map((log) {
        final isSynced = log.syncStatus == 'synced';
        final timeStr = DateHelper.formatTime(log.loggedAt);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.water_drop,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeStr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatWater(log.amountMl),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                isSynced
                    ? const StatusTag.ok(label: 'Synced')
                    : const StatusTag.neutral(label: 'Pending'),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmation(log);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.water_drop_outlined,
            size: 48,
            color: AppColors.textSecondary.withAlpha(100),
          ),
          const SizedBox(height: 12),
          Text(
            'No water logged today',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start by adding your first intake.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _logWater(250),
            icon: const Icon(Icons.water_drop_outlined),
            label: const Text('Add Water'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load logs.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Please try again.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              ref.invalidate(todayWaterLogsProvider);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Loading water logs...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.water_drop_outlined,
              size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Water logs are saved locally and synced when you're back online.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(WaterLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text(
          'Delete ${Formatters.formatWater(log.amountMl)} logged at ${DateHelper.formatTime(log.loggedAt)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteWaterLog(log);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
