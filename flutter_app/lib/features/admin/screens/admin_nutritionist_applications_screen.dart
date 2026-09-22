import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/widgets/empty_state_widget.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

class AdminNutritionistApplicationsScreen extends ConsumerWidget {
  const AdminNutritionistApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(adminNutritionistApplicationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nutritionist credentials')),
      body: applicationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Credential applications could not be loaded. Check the connection and confirm the latest online database setup is in place.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.invalidate(adminNutritionistApplicationsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (applications) {
          if (applications.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.verified_user_outlined,
              title: 'No applications yet',
              subtitle:
                  'Nutritionist credential applications will appear here for manual admin verification.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(adminNutritionistApplicationsProvider),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Review the submitted PRC credential image and details, verify the license externally within the official PRC service, then record the decision here. This is a manual admin review, not automatic PRC verification.',
                    ),
                  ),
                ),
                ...applications.map(
                  (application) => _ApplicationCard(application: application),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends ConsumerWidget {
  final NutritionistApplication application;

  const _ApplicationCard({required this.application});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentialUrlAsync = ref.watch(
      nutritionistCredentialSignedUrlProvider(
        application.credentialDocumentPath,
      ),
    );
    final statusColor = switch (application.status) {
      'verified' => AppColors.success,
      'rejected' => AppColors.error,
      'suspended' => AppColors.warning,
      _ => AppColors.primary,
    };
    final expiration = application.prcLicenseExpirationDate;
    final expirationLabel = expiration == null
        ? 'Not recorded'
        : DateFormat('MMM d, yyyy').format(expiration);
    final canVerify = credentialUrlAsync.hasValue &&
        !credentialUrlAsync.hasError &&
        !application.isExpired;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.badge_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.credentialName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(application.profession),
                      Text(
                          'PRC license: ${application.licenseNumber}'),
                      Text('Expires: $expirationLabel'),
                      Text(
                        'Submitted ${DateFormat('MMM d, yyyy').format(application.submittedAt.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(application.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (application.isExpired) ...[
              const SizedBox(height: 8),
              Text(
                'The PRC credential is expired and cannot be verified.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.error),
              ),
            ],
            if (application.revalidationRequired) ...[
              const SizedBox(height: 8),
              Text(
                'Grandfathered approval: PRC expiration was not on record and needs revalidation.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.warning),
              ),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: credentialUrlAsync.when(
                loading: () => const _DocumentPlaceholder(
                  message: 'Loading private credential image…',
                  loading: true,
                ),
                error: (_, __) => const _DocumentPlaceholder(
                  message: 'Credential image could not be opened.',
                ),
                data: (signedUrl) => Image.network(
                  signedUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const _DocumentPlaceholder(
                    message: 'Credential image could not be opened.',
                  ),
                ),
              ),
            ),
            if (application.rejectionReason?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text('Rejection reason: ${application.rejectionReason}'),
            ],
            if (application.suspensionReason?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text('Suspension reason: ${application.suspensionReason}'),
            ],
            if (application.reviewedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last decision ${DateFormat('MMM d, yyyy').format(application.reviewedAt!.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (application.status != 'verified')
                  FilledButton.icon(
                    onPressed: canVerify
                        ? () => _review(context, ref, 'verified')
                        : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(_verifyLabel(application.status)),
                  ),
                if (application.status != 'rejected')
                  OutlinedButton.icon(
                    onPressed: () => _review(context, ref, 'rejected'),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject'),
                  ),
                if (application.status == 'verified')
                  TextButton.icon(
                    onPressed: () => _review(context, ref, 'suspended'),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Suspend access'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    String decision,
  ) async {
    final noteController = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_decisionLabel(decision)} nutritionist access?'),
        content: TextField(
          controller: noteController,
          maxLength: 1000,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: decision == 'verified'
                ? 'Verification note (optional)'
                : 'Reason for the applicant (optional)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, noteController.text),
            child: Text(_decisionLabel(decision)),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (note == null || !context.mounted) return;

    try {
      await ref.read(nutritionistServiceProvider).reviewApplication(
            applicationId: application.applicationId,
            decision: decision,
            note: note,
          );
      ref.invalidate(adminNutritionistApplicationsProvider);
      ref.invalidate(nutritionistCredentialSignedUrlProvider(
          application.credentialDocumentPath));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Access ${_decisionLabel(decision).toLowerCase()}.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update application: ${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    }
  }

  String _statusLabel(String status) => switch (status) {
        'verified' => 'VERIFIED',
        'rejected' => 'REJECTED',
        'suspended' => 'SUSPENDED',
        _ => 'PENDING',
      };

  String _decisionLabel(String decision) => switch (decision) {
        'verified' => 'Verify',
        'rejected' => 'Reject',
        _ => 'Suspend',
      };

  String _verifyLabel(String status) => switch (status) {
        'suspended' => 'Restore access',
        'rejected' => 'Approve now',
        _ => 'Verify nutritionist',
      };
}

class _DocumentPlaceholder extends StatelessWidget {
  final String message;
  final bool loading;

  const _DocumentPlaceholder({required this.message, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const CircularProgressIndicator()
          else
            const Icon(Icons.image_not_supported_outlined),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
