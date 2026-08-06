import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/constants.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';
import 'package:jcg_fitness/features/profile_settings/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _budgetController = TextEditingController();
  String _fitnessGoalCode = 'maintenance';
  String _activityLevelCode = 'moderate';
  bool _isSaving = false;
  bool _initialized = false;

  static const _goalOptions = [
    ('cutting', 'Cutting'),
    ('maintenance', 'Maintenance'),
    ('bulking', 'Bulking'),
    ('lean', 'Lean Bulk'),
    ('gain_weight', 'Gain Weight'),
  ];

  static const _activityOptions = [
    ('sedentary', 'Sedentary'),
    ('light', 'Lightly Active'),
    ('moderate', 'Moderately Active'),
    ('active', 'Active'),
    ('very_active', 'Very Active'),
  ];

  @override
  void dispose() {
    _nicknameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _initFromProfile() {
    if (_initialized) return;
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) return;

    _nicknameController.text = profile.nickname ?? '';
    _usernameController.text =
        profile.nickname?.toLowerCase().replaceAll(' ', '.') ?? '';
    _ageController.text = profile.age?.toString() ?? '';
    _heightController.text = profile.heightCm?.toString() ?? '';
    _weightController.text = profile.currentWeightKg?.toString() ?? '';
    _targetWeightController.text = profile.targetWeightKg?.toString() ?? '';
    _budgetController.text = profile.dailyBudgetPhp?.toStringAsFixed(0) ?? '';
    _fitnessGoalCode = profile.fitnessGoalCode ?? 'maintenance';
    _activityLevelCode = profile.activityLevelCode ?? 'moderate';
    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final update = ProfileUpdate(
        nickname: _nicknameController.text.trim(),
        fitnessGoalCode: _fitnessGoalCode,
        activityLevelCode: _activityLevelCode,
        age: int.tryParse(_ageController.text.trim()),
        heightCm: double.tryParse(_heightController.text.trim()),
        currentWeightKg: double.tryParse(_weightController.text.trim()),
        targetWeightKg: double.tryParse(_targetWeightController.text.trim()),
        dailyBudgetPhp: double.tryParse(_budgetController.text.trim()),
      );

      ref.invalidate(updateProfileProvider(update));
      await ref.read(updateProfileProvider(update).future);
      ref.invalidate(profileProvider);
      ref.invalidate(nutritionTargetProvider);
      ref.invalidate(dashboardDataProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _initFromProfile();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.textPrimary),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPhotoSection(theme),
            const SizedBox(height: 24),
            _buildDisplayNameField(theme),
            const SizedBox(height: 16),
            _buildUsernameField(theme),
            const SizedBox(height: 16),
            _buildBioField(theme),
            const SizedBox(height: 16),
            _buildLocationField(theme),
            const SizedBox(height: 16),
            _buildGoalSelector(theme),
            const SizedBox(height: 16),
            _buildActivitySelector(theme),
            const SizedBox(height: 16),
            _buildBodyStatsCard(theme),
            const SizedBox(height: 16),
            _buildTargetsCard(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(ThemeData theme) {
    final displayName =
        _nicknameController.text.isNotEmpty ? _nicknameController.text : 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.primary,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayNameField(ThemeData theme) {
    final charCount = _nicknameController.text.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nicknameController,
              maxLength: AppConstants.maxNicknameLength,
              decoration: InputDecoration(
                labelText: 'Display Name',
                prefixIcon: const Icon(Icons.person_outline),
                counterText: '$charCount/${AppConstants.maxNicknameLength}',
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'Display name is required';
                if (value.trim().length < AppConstants.minNicknameLength)
                  return 'Must be at least ${AppConstants.minNicknameLength} characters';
                if (value.trim().length > AppConstants.maxNicknameLength)
                  return 'Must be at most ${AppConstants.maxNicknameLength} characters';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameField(ThemeData theme) {
    final charCount = _usernameController.text.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _usernameController,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: const Icon(Icons.alternate_email),
                counterText: '$charCount/20',
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'Username is required';
                if (value.trim().length < 3)
                  return 'Must be at least 3 characters';
                if (value.trim().length > 20)
                  return 'Must be at most 20 characters';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBioField(ThemeData theme) {
    final charCount = _bioController.text.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _bioController,
              maxLength: 100,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Bio',
                prefixIcon: const Icon(Icons.info_outline),
                counterText: '$charCount/100',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (Optional)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fitness Goal',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _goalOptions.map((o) {
                final isSelected = _fitnessGoalCode == o.$1;
                return InkWell(
                  onTap: () => setState(() => _fitnessGoalCode = o.$1),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      o.$2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity Level',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _activityOptions.map((o) {
                final isSelected = _activityLevelCode == o.$1;
                return InkWell(
                  onTap: () => setState(() => _activityLevelCode = o.$1),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      o.$2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyStatsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Body Stats',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final age = int.tryParse(value);
                      if (age == null ||
                          age < AppConstants.minAge ||
                          age > AppConstants.maxAge) {
                        return 'Age ${AppConstants.minAge}-${AppConstants.maxAge}';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Height (cm)',
                      prefixIcon: Icon(Icons.height),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final h = double.tryParse(value);
                      if (h == null ||
                          h < AppConstants.minHeightCm ||
                          h > AppConstants.maxHeightCm) {
                        return '${AppConstants.minHeightCm.toInt()}-${AppConstants.maxHeightCm.toInt()} cm';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weight & Budget',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Current Weight (kg)',
                prefixIcon: Icon(Icons.monitor_weight_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                final w = double.tryParse(value);
                if (w == null ||
                    w < AppConstants.minWeightKg ||
                    w > AppConstants.maxWeightKg) {
                  return '${AppConstants.minWeightKg.toInt()}-${AppConstants.maxWeightKg.toInt()} kg';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _targetWeightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Target Weight (kg)',
                prefixIcon: Icon(Icons.track_changes_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                final w = double.tryParse(value);
                if (w == null ||
                    w < AppConstants.minWeightKg ||
                    w > AppConstants.maxWeightKg) {
                  return '${AppConstants.minWeightKg.toInt()}-${AppConstants.maxWeightKg.toInt()} kg';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily Budget (PHP)',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                final b = double.tryParse(value);
                if (b == null || b < AppConstants.minBudgetPhp) {
                  return 'Minimum ₱${AppConstants.minBudgetPhp.toInt()}';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
