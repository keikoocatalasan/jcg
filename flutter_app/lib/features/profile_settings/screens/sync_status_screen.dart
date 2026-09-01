import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/sync_queue_repository.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';

const _entityTypeLabels = {
  'meal_log': 'Meal Logs',
  'water_log': 'Water Logs',
  'weight_log': 'Weight Logs',
  'meal_plan': 'Planned Meals',
  'profile': 'Profile Updates',
  'nutrition_target': 'Nutrition Targets',
  'daily_target_snapshot': 'Daily Snapshots',
  'ai_scan_feedback': 'AI Scan Feedback',
  'chat_message': 'Chat Messages',
};

const _entityTypeIcons = {
  'meal_log': Icons.restaurant_outlined,
  'water_log': Icons.water_drop_outlined,
  'weight_log': Icons.monitor_weight_outlined,
  'meal_plan': Icons.calendar_today_outlined,
  'profile': Icons.person_outline,
  'nutrition_target': Icons.track_changes_outlined,
  'daily_target_snapshot': Icons.analytics_outlined,
  'ai_scan_feedback': Icons.feedback_outlined,
  'chat_message': Icons.chat_bubble_outline,
};

const _entityDisplayOrder = [
  'profile',
  'nutrition_target',
  'daily_target_snapshot',
  'meal_log',
  'water_log',
  'weight_log',
  'meal_plan',
  'chat_message',
  'ai_scan_feedback',
];

class SyncStatusScreen extends ConsumerStatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  ConsumerState<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends ConsumerState<SyncStatusScreen> {
  List<SyncQueueEntry> _allEntries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final dbProvider = ref.read(databaseProvider);
      final repo = SyncQueueRepository(dbProvider);
      final pending = await repo.readPending();
      final failed = await repo.readFailed();
      final all = [...pending, ...failed];
      if (mounted) {
        setState(() {
          _allEntries = all;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final isOnline = ref.watch(isOnlineProvider);

    ref.listen<SyncState>(syncProvider, (prev, next) {
      if (prev?.isSyncing == true && next.isSyncing == false) {
        _loadEntries();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Status'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh') _loadEntries();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Text('Refresh'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadEntries)
              : RefreshIndicator(
                  onRefresh: _loadEntries,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (!isOnline) ...[
                        const _OfflineBanner(),
                        const SizedBox(height: 12),
                      ],
                      _PendingChangesCard(
                        syncState: syncState,
                        isOnline: isOnline,
                        lastSyncAt: syncState.lastSyncAt,
                      ),
                      const SizedBox(height: 12),
                      _SyncCountsRow(
                        syncState: syncState,
                        allEntries: _allEntries,
                      ),
                      const SizedBox(height: 16),
                      _SyncNowButton(
                        isOnline: isOnline,
                        isSyncing: syncState.isSyncing,
                        onSyncNow: () =>
                            ref.read(syncProvider.notifier).startSync(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _hasPendingItems
                                  ? () => _showPendingItems(context)
                                  : null,
                              child: const Text('View Pending'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _hasFailedItems
                                  ? () => _showFailedItems(context)
                                  : null,
                              child: const Text('View Failed'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SyncQueueSection(
                        allEntries: _allEntries,
                      ),
                      const SizedBox(height: 16),
                      if (syncState.lastSyncAt != null)
                        Center(
                          child: Text(
                            'Last updated: ${DateHelper.formatDateTime(syncState.lastSyncAt!.toIso8601String())}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  bool get _hasPendingItems =>
      _allEntries.any((e) => e.syncStatus == 'pending');

  bool get _hasFailedItems => _allEntries.any((e) => e.syncStatus == 'failed');

  void _showPendingItems(BuildContext context) {
    final pending =
        _allEntries.where((e) => e.syncStatus == 'pending').toList();
    _showItemsList(context, 'Pending Items', pending, AppColors.warning);
  }

  void _showFailedItems(BuildContext context) {
    final failed = _allEntries.where((e) => e.syncStatus == 'failed').toList();
    _showItemsList(context, 'Failed Items', failed, AppColors.error);
  }

  void _showItemsList(BuildContext context, String title,
      List<SyncQueueEntry> items, Color color) {
    final isFailed = title.contains('Failed');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$title (${items.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (isFailed && items.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _retryFailed();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry All'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No items to display'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final entry = items[index];
                        final label = _entityTypeLabels[entry.entityTypeCode] ??
                            entry.entityTypeCode;
                        return Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                _entityTypeIcons[entry.entityTypeCode] ??
                                    Icons.sync,
                                color: color,
                              ),
                              title: Text(label),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${entry.operationCode} • ${DateHelper.formatDateTime(entry.createdAt)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                  if (entry.lastError != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Error: ${entry.lastError}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  entry.syncStatus.toUpperCase(),
                                  style: const TextStyle(fontSize: 10),
                                ),
                                backgroundColor: color.withAlpha(20),
                                side: BorderSide(color: color.withAlpha(50)),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const Divider(height: 1, indent: 72, endIndent: 16),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retryFailed() async {
    final count = await ref.read(syncProvider.notifier).retryFailed();
    if (!mounted) return;
    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retrying $count failed item(s)')),
      );
      _loadEntries();
    }
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withAlpha(76)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(25),
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
                  'You are offline',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sync will start when you\'re back online.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingChangesCard extends StatelessWidget {
  final SyncState syncState;
  final bool isOnline;
  final DateTime? lastSyncAt;

  const _PendingChangesCard({
    required this.syncState,
    required this.isOnline,
    required this.lastSyncAt,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  syncState.isSyncing ? Icons.sync : Icons.cloud_queue_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pending Changes',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                _ConnectionChip(isOnline: isOnline),
              ],
            ),
            const SizedBox(height: 12),
            if (!isOnline)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sync will start when you\'re online',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!isOnline) const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.history,
              label: 'Last successful sync',
              value: lastSyncAt != null
                  ? _formatRelativeTime(lastSyncAt!)
                  : 'Never',
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ConnectionChip extends StatelessWidget {
  final bool isOnline;

  const _ConnectionChip({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.success.withAlpha(25)
            : AppColors.error.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isOnline ? AppColors.success : AppColors.error,
                ),
          ),
        ],
      ),
    );
  }
}

class _SyncCountsRow extends StatelessWidget {
  final SyncState syncState;
  final List<SyncQueueEntry> allEntries;

  const _SyncCountsRow({
    required this.syncState,
    required this.allEntries,
  });

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        allEntries.where((e) => e.syncStatus == 'pending').length;
    final failedCount =
        allEntries.where((e) => e.syncStatus == 'failed').length;

    return Row(
      children: [
        Expanded(
          child: _CountTile(
            icon: Icons.pending_actions,
            label: 'Pending',
            count: pendingCount,
            color: pendingCount > 0 ? AppColors.warning : AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CountTile(
            icon: Icons.error_outline,
            label: 'Failed',
            count: failedCount,
            color: failedCount > 0 ? AppColors.error : AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _CountTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SyncNowButton extends StatelessWidget {
  final bool isOnline;
  final bool isSyncing;
  final VoidCallback onSyncNow;

  const _SyncNowButton({
    required this.isOnline,
    required this.isSyncing,
    required this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: isSyncing ? null : onSyncNow,
        icon: isSyncing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textPrimary,
                ),
              )
            : const Icon(Icons.sync),
        label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load sync queue',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncQueueSection extends StatelessWidget {
  final List<SyncQueueEntry> allEntries;

  const _SyncQueueSection({required this.allEntries});

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByEntityType();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.queue_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Sync Queue',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (allEntries.isEmpty)
              _EmptyQueueState()
            else
              ..._entityDisplayOrder.map((code) {
                final entries = grouped[code] ?? [];
                if (entries.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SyncQueueItem(
                    entityTypeCode: code,
                    entries: entries,
                  ),
                );
              }),
            ...grouped.entries
                .where((e) => !_entityDisplayOrder.contains(e.key))
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SyncQueueItem(
                      entityTypeCode: entry.key,
                      entries: entry.value,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Map<String, List<SyncQueueEntry>> _groupByEntityType() {
    final map = <String, List<SyncQueueEntry>>{};
    for (final entry in allEntries) {
      map.putIfAbsent(entry.entityTypeCode, () => []).add(entry);
    }
    return map;
  }
}

class _EmptyQueueState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 40,
              color: AppColors.success.withAlpha(178),
            ),
            const SizedBox(height: 8),
            Text(
              'All caught up!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'No items in the sync queue.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncQueueItem extends StatelessWidget {
  final String entityTypeCode;
  final List<SyncQueueEntry> entries;

  const _SyncQueueItem({
    required this.entityTypeCode,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final label = _entityTypeLabels[entityTypeCode] ?? entityTypeCode;
    final icon = _entityTypeIcons[entityTypeCode] ?? Icons.sync;

    final pendingCount = entries.where((e) => e.syncStatus == 'pending').length;
    final failedCount = entries.where((e) => e.syncStatus == 'failed').length;
    final syncedCount = entries.where((e) => e.syncStatus == 'synced').length;

    final overallStatus =
        _getOverallStatus(pendingCount, failedCount, syncedCount);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entries.length} item${entries.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          _StatusChip(
            status: overallStatus.label,
            color: overallStatus.color,
          ),
        ],
      ),
    );
  }

  _StatusInfo _getOverallStatus(int pending, int failed, int synced) {
    if (failed > 0) {
      return _StatusInfo(label: 'Failed', color: AppColors.error);
    }
    if (pending > 0) {
      return _StatusInfo(label: 'Pending', color: AppColors.warning);
    }
    return _StatusInfo(label: 'Synced', color: AppColors.success);
  }
}

class _StatusInfo {
  final String label;
  final Color color;

  const _StatusInfo({required this.label, required this.color});
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusChip({
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
