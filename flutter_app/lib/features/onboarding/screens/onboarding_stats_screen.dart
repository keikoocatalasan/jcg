import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/validators/validators.dart';
import 'package:jcg_fitness/core/widgets/section_header.dart';
import 'package:jcg_fitness/features/onboarding/onboarding_controller.dart';

const _activityLevels = [
  ('sedentary', 'Sedentary', 'Little or no\nexercise', Icons.weekend_outlined),
  (
    'light',
    'Light',
    'Light exercise\n1\u20133 days/week',
    Icons.directions_walk
  ),
  (
    'moderate',
    'Moderate',
    'Moderate exercise\n3\u20135 days/week',
    Icons.directions_run
  ),
  (
    'active',
    'Active',
    'Hard exercise\n6\u20137 days/week',
    Icons.fitness_center
  ),
  (
    'very_active',
    'Very Active',
    'Very hard exercise\n& physical job',
    Icons.terrain
  ),
];

int _calculateAge(DateTime dob) {
  final now = DateTime.now();
  int age = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
    age--;
  }
  return age;
}

class OnboardingStatsScreen extends ConsumerStatefulWidget {
  const OnboardingStatsScreen({super.key});

  @override
  ConsumerState<OnboardingStatsScreen> createState() =>
      _OnboardingStatsScreenState();
}

class _OnboardingStatsScreenState extends ConsumerState<OnboardingStatsScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _dob;
  String _sex = 'male';
  bool _useCm = true;
  final _heightController = TextEditingController();
  bool _useKg = true;
  final _weightController = TextEditingController();
  String _activityLevel = 'moderate';

  @override
  void initState() {
    super.initState();
    final s = ref.read(onboardingControllerProvider);
    _sex = s.sexCode;
    _activityLevel = s.activityLevelCode;
    _heightController.text = s.heightCm.toStringAsFixed(0);
    _weightController.text = s.currentWeightKg.toStringAsFixed(1);
    final now = DateTime.now();
    _dob = DateTime(now.year - s.age, now.month, now.day);
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  double get _heightCm {
    final val = double.tryParse(_heightController.text) ?? 0;
    if (_useCm) return val;
    final feet = val.floor();
    final inches = ((val - feet) * 10).round();
    return feet * 30.48 + inches * 2.54;
  }

  double get _weightKg {
    final val = double.tryParse(_weightController.text) ?? 0;
    if (_useKg) return val;
    return val * 0.453592;
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) return;
    final age = _calculateAge(_dob!);
    final notifier = ref.read(onboardingControllerProvider.notifier);
    notifier.setSex(_sex);
    notifier.setAge(age);
    notifier.setHeight(_heightCm);
    notifier.setCurrentWeight(_weightKg);
    notifier.setActivityLevel(_activityLevel);
    notifier.advanceStep(5);
    context.go('/onboarding/budget');
  }

  void _back() => context.go('/onboarding/allergies');
  void _skip() {
    ref.read(onboardingControllerProvider.notifier).advanceStep(5);
    context.go('/onboarding/budget');
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _formatDate(DateTime d) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
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
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                  const Expanded(
                    child: SectionHeader(number: 5, title: 'stats'),
                  ),
                  GestureDetector(
                    onTap: _skip,
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Tell us about you',
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
                            child: const Icon(Icons.person_outline,
                                size: 40, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your stats help us personalize targets and recommendations.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: 24),
                      _SectionCard(
                        title: 'Basic Information',
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickDate,
                                child: _InfoField(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Date of Birth',
                                  value: _dob != null
                                      ? _formatDate(_dob!)
                                      : 'Select date',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (ctx) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.male),
                                            title: const Text('Male'),
                                            onTap: () {
                                              setState(() => _sex = 'male');
                                              Navigator.pop(ctx);
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.female),
                                            title: const Text('Female'),
                                            onTap: () {
                                              setState(() => _sex = 'female');
                                              Navigator.pop(ctx);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: _InfoField(
                                  icon: Icons.person_outline,
                                  label: 'Gender',
                                  value: _sex == 'male' ? 'Male' : 'Female',
                                  trailing: const Icon(Icons.arrow_drop_down,
                                      size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Height',
                        subtitle: 'Select your unit and enter your height.',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _UnitToggle(
                                    label: 'cm',
                                    isSelected: _useCm,
                                    onTap: () {
                                      if (!_useCm) {
                                        final cm = _heightCm;
                                        setState(() {
                                          _useCm = true;
                                          _heightController.text =
                                              cm.toStringAsFixed(0);
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _UnitToggle(
                                    label: 'ft / in',
                                    isSelected: !_useCm,
                                    onTap: () {
                                      if (_useCm) {
                                        final cm = double.tryParse(
                                                _heightController.text) ??
                                            170;
                                        final totalInches = cm / 2.54;
                                        final feet = (totalInches / 12).floor();
                                        final inches =
                                            (totalInches % 12).round();
                                        setState(() {
                                          _useCm = false;
                                          _heightController.text =
                                              '$feet.$inches';
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.divider.withAlpha(128)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.straighten,
                                      size: 20, color: AppColors.textSecondary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _heightController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      textInputAction: TextInputAction.next,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 14),
                                        hintText: _useCm ? '170' : '5.10',
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty)
                                          return 'Required';
                                        final val =
                                            double.tryParse(value.trim());
                                        if (val == null) return 'Invalid';
                                        if (_useCm) {
                                          if (!Validators.isValidHeight(val))
                                            return '100-250 cm';
                                        } else {
                                          final cm = val.floor() * 30.48 +
                                              ((val * 10) % 10) * 2.54;
                                          if (!Validators.isValidHeight(cm))
                                            return "3'3\" - 8'2\"";
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  Text(
                                    _useCm ? 'cm' : 'ft/in',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: AppColors.textSecondary),
                                SizedBox(width: 6),
                                Text(
                                  'You can change the unit anytime in Settings.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Current Weight',
                        subtitle: 'Enter your current body weight.',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _UnitToggle(
                                    label: 'kg',
                                    isSelected: _useKg,
                                    onTap: () {
                                      if (!_useKg) {
                                        final kg = _weightKg;
                                        setState(() {
                                          _useKg = true;
                                          _weightController.text =
                                              kg.toStringAsFixed(1);
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _UnitToggle(
                                    label: 'lb',
                                    isSelected: !_useKg,
                                    onTap: () {
                                      if (_useKg) {
                                        final kg = double.tryParse(
                                                _weightController.text) ??
                                            70;
                                        setState(() {
                                          _useKg = false;
                                          _weightController.text =
                                              (kg / 0.453592)
                                                  .toStringAsFixed(1);
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.divider.withAlpha(128)),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      final val = double.tryParse(
                                              _weightController.text) ??
                                          0;
                                      final step = _useKg ? 0.5 : 1.0;
                                      if (val > step) {
                                        setState(() {
                                          _weightController.text =
                                              (val - step).toStringAsFixed(1);
                                        });
                                      }
                                    },
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 32),
                                    color: AppColors.textSecondary,
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _weightController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 14),
                                        hintText: _useKg ? '70.0' : '154.0',
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty)
                                          return 'Required';
                                        final val =
                                            double.tryParse(value.trim());
                                        if (val == null) return 'Invalid';
                                        final kg =
                                            _useKg ? val : val * 0.453592;
                                        if (!Validators.isValidWeight(kg)) {
                                          return _useKg
                                              ? '30-300 kg'
                                              : '66-660 lb';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      final val = double.tryParse(
                                              _weightController.text) ??
                                          0;
                                      final step = _useKg ? 0.5 : 1.0;
                                      setState(() {
                                        _weightController.text =
                                            (val + step).toStringAsFixed(1);
                                      });
                                    },
                                    icon: const Icon(Icons.add_circle_outline,
                                        size: 32),
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Last updated: Not set',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Activity Level',
                        subtitle:
                            'Choose the option that best describes your daily activity.',
                        child: Column(
                          children: [
                            Row(
                              children: _activityLevels.map((a) {
                                final isSelected = _activityLevel == a.$1;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _activityLevel = a.$1),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary.withAlpha(13)
                                            : AppColors.background,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.divider
                                                  .withAlpha(128),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            a.$4,
                                            size: 22,
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.textSecondary,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            a.$2,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            a.$3,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: AppColors.textSecondary,
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: AppColors.textSecondary),
                                SizedBox(width: 6),
                                Text(
                                  'Not sure? You can update this later in your Profile.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Continue',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _back,
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
                  final isActive = i == 4;
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

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoField(
      {required this.icon,
      required this.label,
      required this.value,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _UnitToggle(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.divider.withAlpha(128),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
