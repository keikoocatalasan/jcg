import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/auth/account_flow_provider.dart';
import 'package:jcg_fitness/features/auth/screens/logout_dialog.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';
import 'package:jcg_fitness/features/nutritionist/widgets/nutritionist_catalog_tab.dart';
import 'package:jcg_fitness/features/nutritionist/widgets/nutritionist_dashboard_tab.dart';
import 'package:jcg_fitness/features/nutritionist/widgets/nutritionist_history_tab.dart';
import 'package:jcg_fitness/features/nutritionist/widgets/nutritionist_profile_tab.dart';
import 'package:jcg_fitness/features/nutritionist/widgets/nutritionist_reports_tab.dart';

class NutritionistWorkspaceScreen extends ConsumerWidget {
  const NutritionistWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationAsync = ref.watch(nutritionistApplicationProvider);
    final verifiedAsync = ref.watch(verifiedNutritionistProvider);

    return applicationAsync.when(
      loading: () => const _WorkspaceScaffold(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _WorkspaceScaffold(
        child: _StatusMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load verification status',
          message:
              'Connect to the internet and try again. The nutritionist workspace is online-only.',
          actionLabel: 'Try again',
          onAction: () =>
              ref.invalidate(nutritionistApplicationProvider),
        ),
      ),
      data: (application) {
        return verifiedAsync.when(
          loading: () => const _WorkspaceScaffold(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => _WorkspaceScaffold(
            child: _StatusMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load verification status',
              message: 'Connect to the internet and try again.',
              actionLabel: 'Try again',
              onAction: () =>
                  ref.invalidate(nutritionistApplicationProvider),
            ),
          ),
          data: (isVerified) {
            if (!isVerified) {
              return _WorkspaceScaffold(
                child: _NotVerifiedView(application: application),
              );
            }
            return DefaultTabController(
              length: 5,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Nutritionist workspace'),
                  actions: [
                    IconButton(
                      tooltip: 'Open food tracking',
                      icon: const Icon(Icons.restaurant_menu),
                      onPressed: () {
                        enterConsumerFlow(ref);
                        context.go('/dashboard');
                      },
                    ),
                    IconButton(
                      tooltip: 'Log out',
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: () => LogoutDialog.show(context),
                    ),
                  ],
                  bottom: const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Dashboard'),
                      Tab(text: 'Food reviews'),
                      Tab(text: 'Reports'),
                      Tab(text: 'History'),
                      Tab(text: 'Profile'),
                    ],
                  ),
                ),
                body: const TabBarView(
                  children: [
                    NutritionistDashboardTab(),
                    NutritionistCatalogTab(),
                    NutritionistReportsTab(),
                    NutritionistHistoryTab(),
                    NutritionistProfileTab(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WorkspaceScaffold extends StatelessWidget {
  final Widget child;

  const _WorkspaceScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutritionist workspace')),
      body: child,
    );
  }
}

class _NotVerifiedView extends StatelessWidget {
  final NutritionistApplication? application;

  const _NotVerifiedView({required this.application});

  @override
  Widget build(BuildContext context) {
    final status = application?.status;
    if (application == null) {
      return _StatusMessage(
        icon: Icons.verified_user_outlined,
        title: 'Nutritionist verification required',
        message:
            'The workspace is available to admin-verified Nutritionist-Dietitians. Submit your PRC credential details to request access.',
        actionLabel: 'Apply for verification',
        onAction: () => context.push('/nutritionist-application'),
      );
    }
    if (status == 'pending') {
      return _StatusMessage(
        icon: Icons.hourglass_top_rounded,
        title: 'Pending verification',
        message:
            'An administrator is reviewing your PRC credential details. Review actions unlock after verification.',
        actionLabel: 'View application status',
        onAction: () => context.push('/nutritionist-application'),
      );
    }
    if (status == 'suspended') {
      return _StatusMessage(
        icon: Icons.block_outlined,
        title: 'Reviewer access suspended',
        message: application?.suspensionReason?.trim().isNotEmpty == true
            ? application!.suspensionReason!
            : 'Contact an administrator if you have questions about your reviewer access.',
        actionLabel: 'View application status',
        onAction: () => context.push('/nutritionist-application'),
      );
    }
    if (application?.isExpired == true) {
      return _StatusMessage(
        icon: Icons.error_outline,
        title: 'Credential expired',
        message:
            'Your PRC credential has expired. Update your credential details and wait for admin re-verification to restore review actions.',
        actionLabel: 'Update credentials',
        onAction: () => context.push('/nutritionist-application'),
      );
    }
    return _StatusMessage(
      icon: Icons.info_outline,
      title: 'Verification not approved',
      message: application?.rejectionReason?.trim().isNotEmpty == true
          ? application!.rejectionReason!
          : 'Your credential details were not approved. You may submit updated information.',
      actionLabel: 'Update credentials',
      onAction: () => context.push('/nutritionist-application'),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 42, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
