import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/features/meal_logging/recent_logs_provider.dart';

class RecentLogsScreen extends ConsumerStatefulWidget {
  const RecentLogsScreen({super.key});

  @override
  ConsumerState<RecentLogsScreen> createState() => _RecentLogsScreenState();
}

class _RecentLogsScreenState extends ConsumerState<RecentLogsScreen> {
  LogFilter _filter = LogFilter.all;

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(recentLogsProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Previous Logs'),
        actions: [
          IconButton(
            tooltip: 'Add meal',
            onPressed: () => context.push('/add-meal-log'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: GlassBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isOnline)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off,
                        size: 16, color: AppColors.textPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'You\'re offline. Showing saved logs.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ],
                ),
              ),
            _buildFilterBar(),
            Expanded(
              child: logsAsync.when(
                loading: () => _buildLoadingSkeleton(),
                error: (e, _) => _buildErrorState(e.toString()),
                data: (data) {
                  final today = data['today'];
                  final yesterday = data['yesterday'];
                  final entries = _filteredEntries(today, yesterday);
                  if (entries.isEmpty) return _buildEmptyState();
                  return _buildLogList(entries);
                },
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    const filters = [
      (LogFilter.all, 'All'),
      (LogFilter.meals, 'Meals'),
      (LogFilter.water, 'Water'),
      (LogFilter.weight, 'Weight'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: filters.map((filter) {
          final selected = _filter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.$2),
              selected: selected,
              onSelected: (_) => setState(() => _filter = filter.$1),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  List<LogEntry> _filteredEntries(DaySummary? today, DaySummary? yesterday) {
    final entries = [...?today?.entries, ...?yesterday?.entries];
    if (_filter == LogFilter.meals) {
      return entries.where((e) => e.type == LogEntryType.meal).toList();
    }
    if (_filter == LogFilter.water) {
      return entries.where((e) => e.type == LogEntryType.water).toList();
    }
    if (_filter == LogFilter.weight) {
      return entries.where((e) => e.type == LogEntryType.weight).toList();
    }
    return entries;
  }

  Widget _buildLogList(List<LogEntry> allEntries) {
    allEntries.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    final grouped = <String, List<LogEntry>>{};
    for (final entry in allEntries) {
      final key = _formatDate(entry.loggedAt);
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    final sortedDates = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(recentLogsProvider),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final dateLabel in sortedDates) ...[
            _DayHeader(
              label: dateLabel,
              summary: _daySummary(grouped[dateLabel]!),
            ),
            ...grouped[dateLabel]!.map((entry) => _LogEntryTile(entry: entry)),
          ],
        ],
      ),
    );
  }

  String _daySummary(List<LogEntry> entries) {
    switch (_filter) {
      case LogFilter.water:
        final total =
            entries.fold(0, (sum, e) => sum + (int.tryParse(e.amount) ?? 0));
        return '$total ml';
      case LogFilter.weight:
        return '${entries.length} entr${entries.length == 1 ? 'y' : 'ies'}';
      case LogFilter.all:
      case LogFilter.meals:
        final calories = entries
            .where((e) => e.type == LogEntryType.meal)
            .fold(0, (sum, e) => sum + (int.tryParse(e.amount) ?? 0));
        return '$calories kcal';
    }
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: AppColors.divider,
            ),
            const SizedBox(height: 16),
            Text(
              'No logs yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start logging a meal to see it here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-meal-log'),
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Log'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load logs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(recentLogsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing today and yesterday',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          Text(
            'Pull to refresh',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
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
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  final String summary;

  const _DayHeader({
    required this.label,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.calorieColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;
  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        child: InkWell(
          onTap: () => context.push(
            _editRouteFor(entry),
            extra: _editRouteArgs(entry),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _entryIcon(entry),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (entry.subtitle != null &&
                          entry.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 1),
                      Text(
                        _formatTime(entry.loggedAt),
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    '${entry.amount} ${entry.amountUnit}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.calorieColor,
                        ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _editRouteFor(LogEntry entry) {
    switch (entry.type) {
      case LogEntryType.meal:
        return '/edit-meal-log';
      case LogEntryType.water:
        return '/edit-water-log';
      case LogEntryType.weight:
        return '/edit-weight-log';
    }
  }

  static Map<String, dynamic> _editRouteArgs(LogEntry entry) {
    switch (entry.type) {
      case LogEntryType.meal:
        return {
          'mealLogId': entry.id,
          'mealType': entry.mealTypeCode,
        };
      case LogEntryType.water:
        return {'waterLogId': entry.id};
      case LogEntryType.weight:
        return {'weightLogId': entry.id};
    }
  }

  static Widget _mealIcon(String code) {
    IconData iconData;
    Color iconColor;
    Color bgColor;

    switch (code) {
      case 'breakfast':
        iconData = Icons.free_breakfast;
        iconColor = AppColors.secondary;
        bgColor = AppColors.secondary.withValues(alpha: 0.1);
        break;
      case 'lunch':
        iconData = Icons.lunch_dining;
        iconColor = AppColors.secondary;
        bgColor = AppColors.secondary.withValues(alpha: 0.1);
        break;
      case 'dinner':
        iconData = Icons.dinner_dining;
        iconColor = AppColors.secondary;
        bgColor = AppColors.secondary.withValues(alpha: 0.1);
        break;
      case 'snack':
        iconData = Icons.cookie;
        iconColor = AppColors.secondary;
        bgColor = AppColors.secondary.withValues(alpha: 0.1);
        break;
      case 'pre_workout':
      case 'post_workout':
        iconData = Icons.fitness_center;
        iconColor = AppColors.secondary;
        bgColor = AppColors.secondary.withValues(alpha: 0.1);
        break;
      default:
        iconData = Icons.restaurant;
        iconColor = AppColors.secondary;
        bgColor = AppColors.secondary.withValues(alpha: 0.1);
        break;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }

  static Widget _entryIcon(LogEntry entry) {
    if (entry.type == LogEntryType.water) {
      return _iconBadge(Icons.water_drop_outlined);
    }
    if (entry.type == LogEntryType.weight) {
      return _iconBadge(Icons.monitor_weight_outlined);
    }
    return _mealIcon(entry.mealTypeCode);
  }

  static Widget _iconBadge(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.accentSoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.accentPrimary, size: 24),
    );
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
