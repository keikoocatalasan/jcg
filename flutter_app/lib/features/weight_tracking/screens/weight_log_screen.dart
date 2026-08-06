import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/constants.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/profile_repository.dart';
import 'package:jcg_fitness/core/database/weight_log_repository.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/meal_logging/recent_logs_provider.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_engine.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';
import 'package:jcg_fitness/features/weight_tracking/weight_provider.dart';

class WeightLogScreen extends ConsumerStatefulWidget {
  const WeightLogScreen({super.key});

  @override
  ConsumerState<WeightLogScreen> createState() => _WeightLogScreenState();
}

class _WeightLogScreenState extends ConsumerState<WeightLogScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isDeleting = false;
  late double _currentWeight;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  final _notesController = TextEditingController();
  final _weightController = TextEditingController();
  int? _energyLevel;
  int? _sleepQuality;
  int _notesMaxLength = 150;

  @override
  void initState() {
    super.initState();
    _currentWeight = 70.0;
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
    _weightController.text = _currentWeight.toStringAsFixed(1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLatestWeight());
  }

  @override
  void dispose() {
    _notesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestWeight() async {
    final weight = ref.read(latestWeightProvider).valueOrNull;
    if (weight != null) {
      setState(() {
        _currentWeight = weight.weightKg;
        _weightController.text = _currentWeight.toStringAsFixed(1);
      });
    }
  }

  void _updateWeightFromField() {
    final parsed = double.tryParse(_weightController.text);
    if (parsed != null &&
        parsed >= AppConstants.minWeightKg &&
        parsed <= AppConstants.maxWeightKg) {
      setState(() => _currentWeight = parsed);
    }
  }

  Future<void> _saveWeight() async {
    _updateWeightFromField();

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final weightKg = _currentWeight;
    if (weightKg < AppConstants.minWeightKg ||
        weightKg > AppConstants.maxWeightKg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enter a weight between ${AppConstants.minWeightKg.toStringAsFixed(0)} and ${AppConstants.maxWeightKg.toStringAsFixed(0)} kg',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profileRepo = ProfileRepository(DatabaseProvider());
      final profile = await profileRepo.readByUserId(user.id);
      if (profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile not found')),
          );
        }
        return;
      }

      final sexCode = profile.sexCode;
      final age = profile.age;
      final heightCm = profile.heightCm;
      final activityLevelCode = profile.activityLevelCode;
      final fitnessGoalCode = profile.fitnessGoalCode;
      final dailyBudget = profile.dailyBudgetPhp;

      if (sexCode == null ||
          age == null ||
          heightCm == null ||
          activityLevelCode == null ||
          fitnessGoalCode == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incomplete profile data')),
          );
        }
        return;
      }

      final result = NutritionEngine.calculateAll(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        sexCode: sexCode,
        activityLevelCode: activityLevelCode,
        fitnessGoalCode: fitnessGoalCode,
      );

      final loggedAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ).toUtc().toIso8601String();
      final todayDate = DateHelper.todayDate();
      final weightLogId = UuidHelper.generateUuid();
      final targetId = UuidHelper.generateUuid();
      final snapshotId = UuidHelper.generateUuid();

      final helper = LocalTransactionHelper(DatabaseProvider());

      await helper.saveWeightLogAndRecalculate(
        weightLogData: {
          'weight_log_id': weightLogId,
          'user_id': user.id,
          'weight_kg': weightKg,
          'logged_at': loggedAt,
        },
        newTargetData: {
          'target_id': targetId,
          'formula_version_code': 'mifflin_stjeor',
          'fitness_goal_code': fitnessGoalCode,
          'bmr': result.bmr,
          'tdee': result.tdee,
          'calorie_target': result.calorieTarget,
          'protein_target_g': result.proteinG,
          'carbs_target_g': result.carbsG,
          'fat_target_g': result.fatG,
          'water_target_ml': result.waterTargetMl,
          'source_weight_log_id': weightLogId,
          'effective_from': todayDate,
        },
        dailySnapshotData: {
          'snapshot_id': snapshotId,
          'nutrition_target_id': targetId,
          'target_date': todayDate,
          'calorie_target_snapshot': result.calorieTarget,
          'protein_target_g_snapshot': result.proteinG,
          'carbs_target_g_snapshot': result.carbsG,
          'fat_target_g_snapshot': result.fatG,
          'water_target_ml_snapshot': result.waterTargetMl,
          'daily_budget_php_snapshot': dailyBudget,
        },
      );

      ref.invalidate(latestWeightProvider);
      ref.invalidate(weightHistoryProvider);
      ref.invalidate(nutritionTargetProvider);
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(recentLogsProvider);
      ref.read(syncProvider.notifier).startSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle,
                    color: AppColors.textPrimary, size: 20),
                SizedBox(width: 8),
                Text('Weight logged successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save weight: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteLatestWeight() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Weight Entry'),
        content: const Text(
            'Are you sure you want to delete your latest weight entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isDeleting = true);

    try {
      final weightRepo = WeightLogRepository(DatabaseProvider());
      final latest = await weightRepo.readLatest(user.id);
      if (latest == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No weight entry to delete')),
        );
        return;
      }

      final secondLatest = await weightRepo.readSecondLatest(user.id);
      final helper = LocalTransactionHelper(DatabaseProvider());

      if (secondLatest != null) {
        final profileRepo = ProfileRepository(DatabaseProvider());
        final profile = await profileRepo.readByUserId(user.id);

        if (profile?.sexCode != null &&
            profile?.age != null &&
            profile?.heightCm != null &&
            profile?.activityLevelCode != null &&
            profile?.fitnessGoalCode != null) {
          final result = NutritionEngine.calculateAll(
            weightKg: secondLatest.weightKg,
            heightCm: profile!.heightCm!,
            age: profile.age!,
            sexCode: profile.sexCode!,
            activityLevelCode: profile.activityLevelCode!,
            fitnessGoalCode: profile.fitnessGoalCode!,
          );

          final todayDate = DateHelper.todayDate();
          final targetId = UuidHelper.generateUuid();
          final snapshotId = UuidHelper.generateUuid();

          await helper.deleteWeightLogAndRecalculate(
            weightLogId: latest.weightLogId,
            userId: user.id,
            newLatestWeightData: {
              'weight_log_id': secondLatest.weightLogId,
              'weight_kg': secondLatest.weightKg,
            },
            newTargetData: {
              'target_id': targetId,
              'formula_version_code': 'mifflin_stjeor',
              'fitness_goal_code': profile.fitnessGoalCode,
              'bmr': result.bmr,
              'tdee': result.tdee,
              'calorie_target': result.calorieTarget,
              'protein_target_g': result.proteinG,
              'carbs_target_g': result.carbsG,
              'fat_target_g': result.fatG,
              'water_target_ml': result.waterTargetMl,
              'source_weight_log_id': secondLatest.weightLogId,
              'effective_from': todayDate,
            },
            dailySnapshotData: {
              'snapshot_id': snapshotId,
              'nutrition_target_id': targetId,
              'target_date': todayDate,
              'calorie_target_snapshot': result.calorieTarget,
              'protein_target_g_snapshot': result.proteinG,
              'carbs_target_g_snapshot': result.carbsG,
              'fat_target_g_snapshot': result.fatG,
              'water_target_ml_snapshot': result.waterTargetMl,
              'daily_budget_php_snapshot': profile.dailyBudgetPhp,
            },
          );
        } else {
          await helper.deleteWeightLogAndRecalculate(
            weightLogId: latest.weightLogId,
            userId: user.id,
          );
        }
      } else {
        await helper.deleteWeightLogAndRecalculate(
          weightLogId: latest.weightLogId,
          userId: user.id,
        );
      }

      ref.invalidate(latestWeightProvider);
      ref.invalidate(weightHistoryProvider);
      ref.invalidate(nutritionTargetProvider);
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(recentLogsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight entry deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestWeight = ref.watch(latestWeightProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Log New Weight'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveWeight,
            child: _isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.textPrimary),
                  )
                : const Text('Save',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeightEntrySection(theme),
              const SizedBox(height: 20),
              _buildDateTimeSection(theme),
              const SizedBox(height: 20),
              _buildNotesSection(theme),
              const SizedBox(height: 20),
              _buildContextSection(theme),
              const SizedBox(height: 24),
              _buildActionButtons(theme),
              const SizedBox(height: 16),
              _buildPrivacyInfo(theme),
              const SizedBox(height: 16),
              latestWeight.when(
                data: (weight) {
                  if (weight == null) return const SizedBox.shrink();
                  return Center(
                    child: TextButton.icon(
                      onPressed: _isDeleting ? null : _deleteLatestWeight,
                      icon: _isDeleting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.delete_outline,
                              size: 18, color: AppColors.error),
                      label: const Text('Delete Latest Entry',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  );
                },
                error: (_, __) => const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeightEntrySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weight Entry',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _updateWeightFromField(),
          decoration: InputDecoration(
            hintText: 'Enter your weight',
            suffixText: 'kg',
            suffixStyle: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(Icons.monitor_weight_outlined,
                color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDateTimeSection(ThemeData theme) {
    final dateStr = DateFormat('MMM d, yyyy').format(_selectedDate);
    final timeStr = _selectedTime.format(context);
    final displayText = '$dateStr  $timeStr';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date & Time',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              if (!mounted) return;
              final pickedTime = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              setState(() {
                _selectedDate = picked;
                if (pickedTime != null) _selectedTime = pickedTime;
              });
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon:
                  const Icon(Icons.calendar_today, color: AppColors.primary),
              suffixIcon: const Icon(Icons.arrow_drop_down,
                  color: AppColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: Text(
              displayText,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _notesController,
          maxLength: _notesMaxLength,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'How are you feeling? Any notes for today?',
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary.withAlpha(150)),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_notesController.text.length}/$_notesMaxLength',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildContextSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Context (Optional)',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        _buildEnergyLevelRow(theme),
        const SizedBox(height: 14),
        _buildSleepQualityRow(theme),
      ],
    );
  }

  Widget _buildEnergyLevelRow(ThemeData theme) {
    final emojis = ['😔', '😕', '😐', '😊', '😄'];
    final labels = ['Very Low', 'Low', 'Medium', 'High', 'Very High'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Energy Level',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final isSelected = _energyLevel == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _energyLevel = isSelected ? null : index;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withAlpha(25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(emojis[index], style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 2),
                      Text(
                        labels[index],
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 9,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSleepQualityRow(ThemeData theme) {
    final moonIcons = [
      Icons.nightlight_round, // empty
      Icons.nightlight_outlined, // 1/4
      Icons.dark_mode_outlined, // 1/2
      Icons.dark_mode, // 3/4
      Icons.brightness_2, // full
    ];
    final moonLabels = ['None', 'Poor', 'Fair', 'Good', 'Excellent'];
    final moonColors = [
      AppColors.textSecondary,
      AppColors.textSecondary,
      AppColors.textPrimary,
      AppColors.textPrimary,
      AppColors.textPrimary,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sleep Quality',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final isSelected = _sleepQuality == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _sleepQuality = isSelected ? null : index;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withAlpha(25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        moonIcons[index],
                        color: isSelected
                            ? moonColors[index]
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        moonLabels[index],
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 9,
                          color: isSelected
                              ? moonColors[index]
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveWeight,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.textPrimary),
                  )
                : const Text(
                    'Save Weight',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your weight data is stored securely and only visible to you. We never share your personal data with third parties.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
