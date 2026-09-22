import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

class NutritionistReportsTab extends ConsumerStatefulWidget {
  const NutritionistReportsTab({super.key});

  @override
  ConsumerState<NutritionistReportsTab> createState() =>
      _NutritionistReportsTabState();
}

class _NutritionistReportsTabState
    extends ConsumerState<NutritionistReportsTab> {
  static const _filters = <String, String>{
    'open': 'Open',
    'in_review': 'In review',
    'resolved': 'Resolved',
    'dismissed': 'Dismissed',
    'all': 'All',
  };

  String _status = 'open';

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(nutritionistReportsProvider(_status));
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: _filters.entries
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(filter.value),
                      selected: _status == filter.key,
                      onSelected: (_) => setState(() => _status = filter.key),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: reportsAsync.when(
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
                      'Food-data reports could not be loaded. Check the connection and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(nutritionistReportsProvider(_status)),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
            data: (reports) {
              if (reports.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No food-data reports in this state.'),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(nutritionistReportsProvider(_status)),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: reports.length,
                  itemBuilder: (context, index) =>
                      _ReportCard(report: reports[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final FoodReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (report.status) {
      'resolved' => AppColors.success,
      'dismissed' => AppColors.textSecondary,
      'in_review' => AppColors.primary,
      _ => AppColors.warning,
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/nutritionist/report', extra: report),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      report.foodName ?? 'Unknown food',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      report.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                report.issueLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Reported ${DateFormat('MMM d, yyyy').format(report.createdAt.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
