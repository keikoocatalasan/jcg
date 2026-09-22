import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

class NutritionistDashboardTab extends ConsumerWidget {
  const NutritionistDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(nutritionistDashboardProvider);
    final historyAsync = ref.watch(nutritionistHistoryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(nutritionistDashboardProvider);
        ref.invalidate(nutritionistCatalogProvider);
        ref.invalidate(nutritionistHistoryProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          kpisAsync.when(
            loading: () => const _SectionLoader(),
            error: (_, __) => const _SectionError(
              message: 'Dashboard counts could not be loaded.',
            ),
            data: (kpis) => _KpiGrid(kpis: kpis),
          ),
          const SizedBox(height: 12),
          kpisAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (kpis) => _CredentialWarning(kpis: kpis),
          ),
          const SizedBox(height: 8),
          Text(
            'Priority review queue',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const _QueueList(
            statuses: ['needs_revision', 'unreviewed'],
          ),
          const SizedBox(height: 12),
          Text(
            'Recent activity',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          historyAsync.when(
            loading: () => const _SectionLoader(),
            error: (_, __) => const _SectionError(
              message: 'Review history could not be loaded.',
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return Text(
                  'No review activity recorded yet.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                );
              }
              return Column(
                children: entries
                    .take(5)
                    .map((entry) => _ActivityRow(entry: entry))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QueueList extends ConsumerWidget {
  final List<String> statuses;

  const _QueueList({required this.statuses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: statuses.map((status) {
        final asyncEntries = ref.watch(
          nutritionistCatalogProvider(NutritionistCatalogQuery(status: status)),
        );
        return asyncEntries.when(
          loading: () => const _SectionLoader(),
          error: (_, __) =>
              const _SectionError(message: 'Food review queue unavailable.'),
          data: (entries) {
            if (entries.isEmpty) {
              return Text(
                status == 'unreviewed'
                    ? 'No unreviewed foods in the catalog.'
                    : 'No foods need revision right now.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              );
            }
            return Column(
              children: entries
                  .take(5)
                  .map((entry) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(entry.foodName),
                          subtitle: Text(
                            '${entry.categoryName} · '
                            '${entry.caloriesPer100g.toStringAsFixed(0)} kcal/100 g',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            '/nutritionist/review',
                            extra: entry,
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        );
      }).toList(),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final NutritionistDashboardKpis kpis;

  const _KpiGrid({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final cards = <(String, int, Color)>[
      ('Unreviewed', kpis.unreviewed, AppColors.textSecondary),
      ('In review', kpis.inReview, AppColors.primary),
      ('Verified', kpis.verified, AppColors.success),
      ('Needs revision', kpis.needsRevision, AppColors.warning),
      ('Rejected', kpis.rejected, AppColors.error),
      ('Open reports', kpis.openReports, AppColors.secondary),
    ];
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.5,
          children: cards
              .map(
                (card) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${card.$2}',
                            maxLines: 1,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: card.$3,
                                ),
                          ),
                          Text(
                            card.$1,
                            maxLines: 1,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Your reviews this week: ${kpis.myReviewsThisWeek}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}

class _CredentialWarning extends StatelessWidget {
  final NutritionistDashboardKpis kpis;

  const _CredentialWarning({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final expiration = kpis.credentialExpiresOn;
    final String? message;
    final Color color;
    if (kpis.credentialExpired) {
      message =
          'Your PRC credential has expired. Review actions are paused until it is renewed and re-verified.';
      color = AppColors.error;
    } else if (kpis.revalidationRequired) {
      message =
          'Your credential needs revalidation. Submit your PRC expiration date for administrator re-verification.';
      color = AppColors.warning;
    } else if (expiration != null &&
        expiration.isBefore(DateTime.now().add(const Duration(days: 60)))) {
      message =
          'Your PRC credential expires on ${DateFormat('MMM d, yyyy').format(expiration)}. Renew before then to keep review access.';
      color = AppColors.warning;
    } else {
      message = null;
      color = AppColors.warning;
    }
    if (message == null) return const SizedBox.shrink();

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

class _ActivityRow extends StatelessWidget {
  final NutritionistActionEntry entry;

  const _ActivityRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final label = switch (entry.action) {
      'review_verified' => 'Verified nutrition data',
      'review_needs_revision' => 'Requested revision',
      'review_rejected' => 'Rejected nutrition data',
      'food_archived' => 'Archived a food entry',
      'report_in_review' => 'Opened a food report',
      'report_resolved' => 'Resolved a food report',
      'report_dismissed' => 'Dismissed a food report',
      _ => entry.action.replaceAll('_', ' '),
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.history, color: AppColors.primary),
        title: Text(label),
        subtitle: Text(
          '${DateFormat('MMM d, yyyy · h:mm a').format(entry.createdAt.toLocal())}'
          '${entry.reason == null || entry.reason!.isEmpty ? '' : ' · ${entry.reason}'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SectionLoader extends StatelessWidget {
  const _SectionLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: LinearProgressIndicator(),
    );
  }
}

class _SectionError extends StatelessWidget {
  final String message;

  const _SectionError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.error),
      ),
    );
  }
}
