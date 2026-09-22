import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

class NutritionistHistoryTab extends ConsumerWidget {
  const NutritionistHistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(nutritionistHistoryProvider);
    return historyAsync.when(
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
                'Review history could not be loaded.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(nutritionistHistoryProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No professional review actions recorded yet.'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(nutritionistHistoryProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: entries.length,
            itemBuilder: (context, index) =>
                _HistoryCard(entry: entries[index]),
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final NutritionistActionEntry entry;

  const _HistoryCard({required this.entry});

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
        isThreeLine: true,
        leading: const Icon(Icons.history, color: AppColors.primary),
        title: Text(label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM d, yyyy · h:mm a')
                  .format(entry.createdAt.toLocal()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (entry.reason != null && entry.reason!.isNotEmpty)
              Text(
                entry.reason!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
