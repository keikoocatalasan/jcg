import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/auth/account_flow_provider.dart';
import 'package:jcg_fitness/features/auth/screens/logout_dialog.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

class NutritionistProfileTab extends ConsumerWidget {
  const NutritionistProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationAsync = ref.watch(nutritionistApplicationProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        applicationAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Profile could not be loaded.'),
          data: (application) {
            if (application == null) {
              return const Text('No nutritionist profile found.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.credentialName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(application.profession),
                        const SizedBox(height: 12),
                        _ProfileRow(
                          label: 'Verification status',
                          value: application.isVerified
                              ? 'Verified'
                              : _statusLabel(application.status),
                        ),
                        _ProfileRow(
                          label: 'PRC license',
                          value: _maskLicense(application.licenseNumber),
                        ),
                        _ProfileRow(
                          label: 'License expiration',
                          value: application.prcLicenseExpirationDate == null
                              ? 'Not recorded'
                              : DateFormat('MMM d, yyyy').format(
                                  application.prcLicenseExpirationDate!,
                                ),
                        ),
                        _ProfileRow(
                          label: 'Verified on',
                          value: application.reviewedAt == null
                              ? '—'
                              : DateFormat('MMM d, yyyy')
                                  .format(application.reviewedAt!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (application.isExpired)
                  const _WarningCard(
                    color: AppColors.error,
                    message:
                        'Your PRC credential has expired. Review actions are paused until it is renewed and re-verified.',
                  )
                else if (application.revalidationRequired ||
                    application.prcLicenseExpirationDate == null)
                  const _WarningCard(
                    color: AppColors.warning,
                    message:
                        'Credential revalidation required. Submit your PRC expiration date for administrator re-verification.',
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.push('/nutritionist-application'),
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('View or update credentials'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    enterConsumerFlow(ref);
                    context.go('/dashboard');
                  },
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Open food tracking'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => LogoutDialog.show(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log out'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _statusLabel(String status) => switch (status) {
        'pending' => 'Pending verification',
        'verified' => 'Verified',
        'rejected' => 'Rejected',
        'suspended' => 'Suspended',
        _ => status,
      };

  String _maskLicense(String license) {
    if (license.length <= 4) return license;
    return '••••${license.substring(license.length - 4)}';
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final Color color;
  final String message;

  const _WarningCard({required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
