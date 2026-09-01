import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/widgets/section_header.dart';
import 'package:jcg_fitness/features/onboarding/onboarding_controller.dart';

const _budgetExamples = [
  (
    'Tight',
    '\u20b1500 \u2013 \u20b11,000',
    'Basic & simple\nmeal options',
    Icons.savings_outlined,
  ),
  (
    'Moderate',
    '\u20b11,001 \u2013 \u20b12,500',
    'Balanced & variety\nof meal options',
    Icons.shopping_basket_outlined,
  ),
  (
    'Flexible',
    '\u20b12,501 \u2013 \u20b14,500',
    'More variety &\npremium options',
    Icons.local_grocery_store_outlined,
  ),
  (
    'High',
    '\u20b14,501+',
    'Premium & higher\nquality options',
    Icons.restaurant_outlined,
  ),
];

class OnboardingBudgetScreen extends ConsumerStatefulWidget {
  const OnboardingBudgetScreen({super.key});

  @override
  ConsumerState<OnboardingBudgetScreen> createState() =>
      _OnboardingBudgetScreenState();
}

class _OnboardingBudgetScreenState
    extends ConsumerState<OnboardingBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  double _weeklyBudget = 2000;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final daily = ref.read(onboardingControllerProvider).dailyBudgetPhp;
    _weeklyBudget = daily * 7;
    if (_weeklyBudget < 500) _weeklyBudget = 700;
    if (_weeklyBudget > 6000) _weeklyBudget = 6000;
    _controller.text = _weeklyBudget.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    final budget = _weeklyBudget / 7;
    ref.read(onboardingControllerProvider.notifier).setDailyBudget(budget);
    ref.read(onboardingControllerProvider.notifier).advanceStep(6);
    context.go('/onboarding/review');
  }

  void _back() => context.go('/onboarding/stats');
  void _skip() {
    ref.read(onboardingControllerProvider.notifier).advanceStep(6);
    context.go('/onboarding/review');
  }

  void _applyPreset(double weekly) {
    setState(() {
      _weeklyBudget = weekly;
      _controller.text = weekly.toStringAsFixed(0);
      _isEditing = false;
    });
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
                    child: SectionHeader(number: 6, title: 'budget'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Set Your Budget',
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
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us your weekly food budget so we can recommend meals that fit your pocket.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 24),
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
                          const Text(
                            'Weekly Food Budget',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'How much can you spend on groceries each week?',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                '\u20b1 ${_weeklyBudget.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _isEditing = !_isEditing),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: AppColors.primary),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.edit_outlined,
                                          size: 16, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isEditing ? 'Done' : 'Edit',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isEditing) ...[
                            const SizedBox(height: 12),
                            Form(
                              key: _formKey,
                              child: TextFormField(
                                controller: _controller,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  prefixText: '\u20b1 ',
                                  prefixStyle: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  hintText: '2000',
                                  isDense: true,
                                ),
                                onFieldSubmitted: (v) {
                                  final val = double.tryParse(v);
                                  if (val != null && val >= 500) {
                                    setState(() {
                                      _weeklyBudget = val.clamp(500, 6000);
                                      _isEditing = false;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: AppColors.divider,
                              thumbColor: AppColors.primary,
                              overlayColor: AppColors.primary.withAlpha(25),
                              trackHeight: 6,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 10),
                            ),
                            child: Slider(
                              value:
                                  _weeklyBudget.clamp(500, 6000).toDouble(),
                              min: 500,
                              max: 6000,
                              onChanged: (v) {
                                setState(() {
                                  _weeklyBudget = v.roundToDouble();
                                  _controller.text =
                                      _weeklyBudget.toStringAsFixed(0);
                                });
                              },
                            ),
                          ),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '\u20b1500',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Min',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '\u20b12,000',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    'Suggested',
                                    style: TextStyle(
                                        fontSize: 11, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '\u20b16,000+',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Max',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
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
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What this means',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "We'll use your budget to:",
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                          SizedBox(height: 12),
                          _BenefitItem(
                            icon: Icons.local_offer_outlined,
                            title: 'Recommend affordable foods',
                            subtitle: 'Based on local prices in your area.',
                          ),
                          SizedBox(height: 10),
                          _BenefitItem(
                            icon: Icons.trending_down,
                            title: 'Suggest budget-friendly meals',
                            subtitle: 'Meals that help you reach your goals.',
                          ),
                          SizedBox(height: 10),
                          _BenefitItem(
                            icon: Icons.warning_amber_outlined,
                            title: 'Alert you if you go over budget',
                            subtitle: 'So you can adjust and stay on track.',
                          ),
                        ],
                      ),
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
                          const Text(
                            'Budget Examples (Weekly)',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: _budgetExamples.map((e) {
                              final isSelected =
                                  _weeklyBudget >= _parseMin(e.$2) &&
                                      _weeklyBudget <= _parseMax(e.$2);
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => _applyPreset(_parseMid(e.$2)),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withAlpha(13)
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.divider.withAlpha(128),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          e.$4,
                                          size: 24,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          e.$1,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          e.$2,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          e.$3,
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'You can update your budget anytime in Profile > Settings.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
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
                                    fontSize: 16, fontWeight: FontWeight.w600)),
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
                  final isActive = i == 5;
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

  double _parseMin(String range) {
    final match = RegExp(r'\u20b1([\d,]+)').firstMatch(range);
    if (match != null) {
      return double.parse(match.group(1)!.replaceAll(',', ''));
    }
    return 0;
  }

  double _parseMax(String range) {
    final matches = RegExp(r'\u20b1([\d,]+)').allMatches(range).toList();
    if (matches.length >= 2) {
      return double.parse(matches.last.group(1)!.replaceAll(',', ''));
    }
    if (matches.isNotEmpty) {
      return 99999;
    }
    return 0;
  }

  double _parseMid(String range) {
    final min = _parseMin(range);
    final max = _parseMax(range);
    if (max > 99999) return min + 2000;
    return ((min + max) / 2).roundToDouble();
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitItem(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 1),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
