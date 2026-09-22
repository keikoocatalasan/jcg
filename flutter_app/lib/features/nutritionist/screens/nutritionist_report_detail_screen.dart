import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

class NutritionistReportDetailScreen extends ConsumerStatefulWidget {
  final FoodReport report;

  const NutritionistReportDetailScreen({super.key, required this.report});

  @override
  ConsumerState<NutritionistReportDetailScreen> createState() =>
      _NutritionistReportDetailScreenState();
}

class _NutritionistReportDetailScreenState
    extends ConsumerState<NutritionistReportDetailScreen> {
  bool _saving = false;
  NutritionistCatalogEntry? _foodEntry;

  FoodReport get _report => widget.report;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFood());
  }

  Future<void> _loadFood() async {
    try {
      final entry = await ref
          .read(nutritionistServiceProvider)
          .fetchPrimaryServingEntry(_report.foodId);
      if (mounted) setState(() => _foodEntry = entry);
    } catch (_) {
      // The food link is optional; report actions still work without it.
    }
  }

  Future<void> _resolve(String status) async {
    final noteController = TextEditingController();
    final requiresNote = status == 'dismissed';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(switch (status) {
          'in_review' => 'Mark report in review?',
          'resolved' => 'Resolve this report?',
          _ => 'Dismiss this report?',
        }),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 'resolved')
              const Text(
                'Only resolve when the food data has been corrected, verified, or confirmed accurate.',
              ),
            if (status == 'dismissed')
              const Text(
                'Dismiss only clearly invalid reports and record why.',
              ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: requiresNote
                    ? 'Reason (required)'
                    : 'Resolution note (optional)',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (requiresNote && noteController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(nutritionistServiceProvider).resolveReport(
            reportId: _report.reportId,
            status: status,
            note: note.isEmpty ? null : note,
          );
      ref.invalidate(nutritionistReportsProvider);
      ref.invalidate(nutritionistDashboardProvider);
      ref.invalidate(nutritionistHistoryProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report could not be updated: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food-data report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _report.foodName ?? 'Unknown food',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _ReportRow(label: 'Issue', value: _report.issueLabel),
                  _ReportRow(
                    label: 'Status',
                    value: _report.status.replaceAll('_', ' '),
                  ),
                  _ReportRow(
                    label: 'Reported',
                    value: DateFormat('MMM d, yyyy · h:mm a')
                        .format(_report.createdAt.toLocal()),
                  ),
                  if (_report.resolvedAt != null)
                    _ReportRow(
                      label: 'Closed',
                      value: DateFormat('MMM d, yyyy · h:mm a')
                          .format(_report.resolvedAt!.toLocal()),
                    ),
                  if (_report.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Description',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(_report.description!),
                  ],
                  if (_report.resolutionNote?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Resolution note',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(_report.resolutionNote!),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Reporter details are intentionally hidden. Review the food data, not the reporter.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (_foodEntry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push('/nutritionist/review', extra: _foodEntry),
              icon: const Icon(Icons.rate_review_outlined),
              label: Text('Review ${_foodEntry!.foodName}'),
            ),
          ],
          const SizedBox(height: 16),
          if (_report.status == 'open') ...[
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _resolve('in_review'),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Mark in review'),
            ),
            const SizedBox(height: 8),
          ],
          if (_report.status != 'resolved') ...[
            FilledButton.icon(
              onPressed: _saving ? null : () => _resolve('resolved'),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Resolve report'),
            ),
            const SizedBox(height: 8),
          ],
          if (_report.status != 'dismissed')
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _resolve('dismissed'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              icon: const Icon(Icons.block_outlined),
              label: const Text('Dismiss report'),
            ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReportRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
