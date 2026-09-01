import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';

enum InternetRequiredVariant {
  offline,
  poorConnection,
  serverUnavailable,
}

class InternetRequiredWidget extends ConsumerWidget {
  final String featureName;
  final InternetRequiredVariant variant;
  final VoidCallback? onGoBack;
  final VoidCallback? onRetry;

  const InternetRequiredWidget({
    super.key,
    required this.featureName,
    this.variant = InternetRequiredVariant.offline,
    this.onGoBack,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: onGoBack ?? () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildIllustration(),
                    const SizedBox(height: 32),
                    _buildTitle(context),
                    const SizedBox(height: 12),
                    _buildDescription(context),
                    const SizedBox(height: 24),
                    _buildInfoBox(context),
                    const SizedBox(height: 32),
                    _buildTryAgainButton(context),
                    const SizedBox(height: 12),
                    _buildCheckConnectionButton(),
                    const SizedBox(height: 12),
                    _buildGoBackLink(context),
                  ],
                ),
              ),
            ),
            if (!isOnline) _buildOfflineBanner(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            _getCloudIcon(),
            size: 80,
            color: AppColors.accentPrimary.withValues(alpha: 0.30),
          ),
          Positioned(
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgTertiary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.borderDefault,
                  width: 1,
                ),
              ),
              child: Icon(
                _getStatusIcon(),
                size: 32,
                color: _getStatusColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCloudIcon() {
    switch (variant) {
      case InternetRequiredVariant.offline:
        return Icons.cloud_off_rounded;
      case InternetRequiredVariant.poorConnection:
        return Icons.cloud_queue_rounded;
      case InternetRequiredVariant.serverUnavailable:
        return Icons.cloud_off_rounded;
    }
  }

  IconData _getStatusIcon() {
    switch (variant) {
      case InternetRequiredVariant.offline:
        return Icons.wifi_off_rounded;
      case InternetRequiredVariant.poorConnection:
        return Icons.signal_cellular_alt_rounded;
      case InternetRequiredVariant.serverUnavailable:
        return Icons.dns_outlined;
    }
  }

  Color _getStatusColor() {
    switch (variant) {
      case InternetRequiredVariant.offline:
        return AppColors.error;
      case InternetRequiredVariant.poorConnection:
        return AppColors.warning;
      case InternetRequiredVariant.serverUnavailable:
        return AppColors.error;
    }
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      _getTitle(),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
      textAlign: TextAlign.center,
    );
  }

  String _getTitle() {
    switch (variant) {
      case InternetRequiredVariant.offline:
        return 'Internet connection required';
      case InternetRequiredVariant.poorConnection:
        return 'Connection is weak';
      case InternetRequiredVariant.serverUnavailable:
        return 'Service is unavailable';
    }
  }

  Widget _buildDescription(BuildContext context) {
    return Text(
      _getDescription(),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
      textAlign: TextAlign.center,
    );
  }

  String _getDescription() {
    switch (variant) {
      case InternetRequiredVariant.offline:
        return 'This feature needs an active internet connection to work. Please connect to the internet and try again.';
      case InternetRequiredVariant.poorConnection:
        return 'Please check your internet connection and try again.';
      case InternetRequiredVariant.serverUnavailable:
        return 'Our servers are currently busy. Please try again later.';
    }
  }

  Widget _buildInfoBox(BuildContext context) {
    if (variant != InternetRequiredVariant.offline) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: AppColors.accentPrimary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You can still use offline features like viewing your logs, tracking water, and planning your meals.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTryAgainButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 20),
        label: Text(
          variant == InternetRequiredVariant.serverUnavailable
              ? 'Try Again Later'
              : 'Try Again',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: AppColors.textOnAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckConnectionButton() {
    if (variant == InternetRequiredVariant.serverUnavailable) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.wifi_find_rounded, size: 20),
        label: const Text(
          'Check Connection',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderDefault),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildGoBackLink(BuildContext context) {
    return TextButton(
      onPressed: onGoBack ?? () => Navigator.of(context).pop(),
      child: const Text(
        'Go Back',
        style: TextStyle(
          color: AppColors.accentPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are currently offline.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Some features may be limited.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
