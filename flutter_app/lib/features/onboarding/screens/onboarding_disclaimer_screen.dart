import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/widgets/section_header.dart';
import 'package:jcg_fitness/features/onboarding/onboarding_controller.dart';

class OnboardingDisclaimerScreen extends ConsumerStatefulWidget {
  const OnboardingDisclaimerScreen({super.key});

  @override
  ConsumerState<OnboardingDisclaimerScreen> createState() =>
      _OnboardingDisclaimerScreenState();
}

class _OnboardingDisclaimerScreenState
    extends ConsumerState<OnboardingDisclaimerScreen> {
  bool _accepted = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _accepted = ref.read(onboardingControllerProvider).disclaimerAccepted;
  }

  void _next() {
    if (!_accepted) {
      setState(() => _showError = true);
      return;
    }
    ref.read(onboardingControllerProvider.notifier).setDisclaimerAccepted(true);
    ref.read(onboardingControllerProvider.notifier).setDisclaimerVersion('1.0');
    ref.read(onboardingControllerProvider.notifier).advanceStep(3);
    context.go('/onboarding/allergies');
  }

  void _back() {
    context.go('/onboarding/goal');
  }

  void _skip() {
    ref.read(onboardingControllerProvider.notifier).setDisclaimerAccepted(true);
    ref.read(onboardingControllerProvider.notifier).setDisclaimerVersion('1.0');
    ref.read(onboardingControllerProvider.notifier).advanceStep(3);
    context.go('/onboarding/allergies');
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
                  const Spacer(),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: SectionHeader(number: 3, title: 'disclaimer'),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Important Health\nand Safety Information',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please read the following carefully before using JCG Fitness.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        width: 160,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          size: 56,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(13),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.primary.withAlpha(51)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Disclaimer',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _DisclaimerItem(
                      icon: Icons.person_outline,
                      text:
                          'JCG Fitness provides general nutrition and wellness information for educational purposes only. It is not intended to replace professional medical advice, diagnosis, or treatment.',
                    ),
                    const _DisclaimerItem(
                      icon: Icons.medical_services_outlined,
                      text:
                          'Always consult a qualified healthcare professional before making changes to your diet or exercise routine.',
                    ),
                    const _DisclaimerItem(
                      icon: Icons.warning_amber_outlined,
                      text:
                          'Do not use this app if you have a medical condition that requires specialized dietary management without advice.',
                    ),
                    const _DisclaimerItem(
                      icon: Icons.pregnant_woman_outlined,
                      text:
                          'If you are pregnant, nursing, have a medical condition, or taking medication, please consult your healthcare provider.',
                    ),
                    const _DisclaimerItem(
                      icon: Icons.favorite_outline,
                      text:
                          'Stop and seek medical attention if you experience any discomfort or adverse reactions during your activities.',
                    ),
                    _DisclaimerItem(
                      icon: Icons.description_outlined,
                      text:
                          'Results may vary. Your use of this app indicates that you agree to our Terms of Service and Privacy Policy.',
                      trailing: RichText(
                        text: TextSpan(
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                    height: 1.5,
                                  ),
                          children: const [
                            TextSpan(
                              text:
                                  'Results may vary. Your use of this app indicates that you agree to our ',
                            ),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => setState(() {
                        _accepted = !_accepted;
                        _showError = false;
                      }),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _showError
                              ? AppColors.error.withAlpha(13)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _showError
                                ? AppColors.error.withAlpha(128)
                                : AppColors.divider.withAlpha(128),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _accepted
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  width: 2,
                                ),
                                color: _accepted
                                    ? AppColors.primary
                                    : Colors.transparent,
                              ),
                              child: _accepted
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: AppColors.textPrimary,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                            height: 1.4,
                                          ),
                                      children: const [
                                        TextSpan(
                                          text:
                                              'I have read and understood the above information.\n',
                                        ),
                                        TextSpan(
                                          text:
                                              'I agree to use this app responsibly.',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You must agree to continue.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showError) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: AppColors.error.withAlpha(77)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Please agree to the disclaimer to continue.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                  top: BorderSide(color: AppColors.divider.withAlpha(128)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (i) {
                  final isActive = i == 2;
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
                                : AppColors.divider,
                          ),
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
                          width: 12,
                          height: 2,
                          color: AppColors.divider,
                        ),
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

class _DisclaimerItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;

  const _DisclaimerItem({
    required this.icon,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider.withAlpha(128)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: trailing ??
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
