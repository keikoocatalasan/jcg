import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/constants.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/features/profile_settings/screens/clear_cache_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'ACCOUNT'),
          _SettingsTile(
            icon: Icons.person_outline,
            iconColor: AppColors.primary,
            title: 'Edit Profile',
            onTap: () => context.push('/edit-profile'),
          ),
          const _SectionHeader(title: 'APP PREFERENCES'),
          const _SettingsTile(
            icon: Icons.straighten,
            iconColor: AppColors.secondary,
            title: 'Units',
            trailingText: 'Metric (kg, cm)',
            showChevron: false,
          ),
          const _SettingsTile(
            icon: Icons.language,
            iconColor: AppColors.primary,
            title: 'Language',
            trailingText: 'English',
            showChevron: false,
          ),
          const _SettingsTile(
            icon: Icons.dark_mode_outlined,
            iconColor: AppColors.fatColor,
            title: 'Theme',
            trailingText: 'System',
            showChevron: false,
          ),
          const _SectionHeader(title: 'DATA & SYNC'),
          _SyncStatusTile(syncState: syncState, ref: ref),
          _PendingChangesTile(syncState: syncState),
          const _SettingsTile(
            icon: Icons.data_usage_outlined,
            iconColor: AppColors.proteinColor,
            title: 'Data Usage',
            showChevron: false,
          ),
          const _SectionHeader(title: 'STORAGE'),
          _ClearCacheTile(),
          const _SettingsTile(
            icon: Icons.folder_open_outlined,
            iconColor: AppColors.textSecondary,
            title: 'Manage Storage',
            showChevron: false,
          ),
          const _SectionHeader(title: 'ABOUT'),
          const _SettingsTile(
            icon: Icons.info_outline,
            iconColor: AppColors.textSecondary,
            title: 'App Version',
            trailingText: AppConstants.version,
            showChevron: false,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? trailingText;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailingText,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              if (showChevron) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatusTile extends StatelessWidget {
  final SyncState syncState;
  final WidgetRef ref;

  const _SyncStatusTile({required this.syncState, required this.ref});

  @override
  Widget build(BuildContext context) {
    final String statusText;

    if (syncState.isSyncing) {
      statusText = 'Syncing...';
    } else if (syncState.pendingCount > 0) {
      statusText = '${syncState.pendingCount} waiting';
    } else if (syncState.lastResult != null &&
        syncState.lastResult!.errors.isNotEmpty) {
      statusText = 'Error';
    } else {
      statusText = 'All synced \u2713';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            _SettingsTile(
              icon: Icons.sync,
              iconColor: AppColors.primary,
              title: 'Sync Status',
              trailingText: statusText,
            ),
            if (syncState.lastResult != null &&
                syncState.lastResult!.errors.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last sync errors:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    ...syncState.lastResult!.errors.map(
                      (e) => Text(e,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.error)),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: syncState.isSyncing
                          ? null
                          : () => ref.read(syncProvider.notifier).startSync(),
                      icon: syncState.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.textPrimary),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('Sync Now'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/sync-status'),
                      child: const Text('Details'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingChangesTile extends StatelessWidget {
  final SyncState syncState;

  const _PendingChangesTile({required this.syncState});

  @override
  Widget build(BuildContext context) {
    final String trailingText =
        syncState.pendingCount > 0 ? '${syncState.pendingCount} items' : 'None';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.pending_outlined,
                size: 22, color: AppColors.warning),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Pending Changes',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Text(
              trailingText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ClearCacheTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: () => ClearCacheDialog.show(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.cleaning_services_outlined,
                  size: 22, color: AppColors.warning),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Clear Cache',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Text(
                '45.2 MB',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
