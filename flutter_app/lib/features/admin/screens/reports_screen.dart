import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:jcg_fitness/core/widgets/empty_state_widget.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';

class PostReport {
  final String reportId;
  final String postId;
  final String reportedByUserId;
  final String reason;
  final String status;
  final String? authorNickname;
  final String? postBody;
  final String createdAt;

  const PostReport({
    required this.reportId,
    required this.postId,
    required this.reportedByUserId,
    required this.reason,
    required this.status,
    this.authorNickname,
    this.postBody,
    required this.createdAt,
  });

  factory PostReport.fromMap(Map<String, dynamic> map) {
    return PostReport(
      reportId: map['report_id'] as String,
      postId: map['post_id'] as String,
      reportedByUserId: map['reporter_user_id'] as String,
      reason: map['reason'] as String,
      status: map['status'] as String? ?? 'pending',
      authorNickname: map['author_nickname'] as String?,
      postBody: map['post_body'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}

final reportsProvider = FutureProvider<List<PostReport>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase
      .from('community_report')
      .select()
      .order('created_at', ascending: false);
  if (response.isEmpty) return [];

  final reasonRows =
      await supabase.from('report_reason').select('reason_id, reason_code');
  final statusRows =
      await supabase.from('report_status').select('status_id, status_code');
  final postIds = response.map((row) => row['post_id'] as String).toList();
  final posts = await supabase
      .from('community_post')
      .select('post_id, user_id, body_text')
      .inFilter('post_id', postIds);
  final authorIds =
      posts.map((row) => row['user_id'] as String).toSet().toList();
  final profiles = authorIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await supabase
          .from('user_profile')
          .select('user_id, nickname')
          .inFilter('user_id', authorIds);

  final reasons = {
    for (final row in reasonRows) row['reason_id']: row['reason_code'],
  };
  final statuses = {
    for (final row in statusRows) row['status_id']: row['status_code'],
  };
  final postsById = {for (final row in posts) row['post_id']: row};
  final nicknames = {
    for (final row in profiles) row['user_id']: row['nickname']
  };
  return response.map((m) {
    final post = postsById[m['post_id']];
    return PostReport.fromMap({
      ...m,
      'reason': reasons[m['reason_id']] ?? 'other',
      'status': statuses[m['status_id']] ?? 'pending',
      if (post != null) 'author_nickname': nicknames[post['user_id']],
      if (post != null) 'post_body': post['body_text'],
    });
  }).toList();
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: GlassBackground(
        child: reportsAsync.when(
          data: (reports) {
            if (reports.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.flag_outlined,
                title: 'No Reports',
                subtitle: 'There are no community reports to review right now.',
              );
            }

            final pending =
                reports.where((r) => r.status == 'pending').toList();
            final resolved = reports
                .where(
                    (r) => r.status == 'action_taken' || r.status == 'reviewed')
                .toList();
            final dismissed =
                reports.where((r) => r.status == 'dismissed').toList();

            final reasonCounts = <String, int>{};
            for (final r in reports) {
              reasonCounts[r.reason] = (reasonCounts[r.reason] ?? 0) + 1;
            }
            final sortedReasons = reasonCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final maxReasonCount =
                sortedReasons.isEmpty ? 1 : sortedReasons.first.value;

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                const SizedBox(height: 8),
                _SummaryCards(
                  total: reports.length,
                  pending: pending.length,
                  resolved: resolved.length,
                  dismissed: dismissed.length,
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today,
                                size: 14, color: AppColors.textSecondary),
                            SizedBox(width: 6),
                            Text(
                              'Last 30 days',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (sortedReasons.isNotEmpty) ...[
                  _SectionHeader(title: 'Report Reasons'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: sortedReasons.map((entry) {
                            final fraction = entry.value / maxReasonCount;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      Text(
                                        '${entry.value}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: fraction,
                                      backgroundColor: AppColors.surface,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          _reasonColor(entry.key)),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (pending.isNotEmpty) ...[
                  _SectionHeader(title: 'Pending (${pending.length})'),
                  ...pending.map((r) => _ReportCard(report: r)),
                ],
                if (dismissed.isNotEmpty) ...[
                  _SectionHeader(title: 'Dismissed (${dismissed.length})'),
                  ...dismissed.map((r) => _ReportCard(report: r)),
                ],
                if (resolved.isNotEmpty) ...[
                  _SectionHeader(title: 'Resolved (${resolved.length})'),
                  ...resolved.map((r) => _ReportCard(report: r)),
                ],
                const SizedBox(height: 16),
              ],
            );
          },
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  const Text(
                    'Failed to load reports',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(reportsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  static Color _reasonColor(String reason) {
    return AppColors.textPrimary;
  }
}

class _SummaryCards extends StatelessWidget {
  final int total;
  final int pending;
  final int resolved;
  final int dismissed;

  const _SummaryCards({
    required this.total,
    required this.pending,
    required this.resolved,
    required this.dismissed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _SummaryCard(label: 'Total Reports', value: '$total'),
          _SummaryCard(label: 'Pending', value: '$pending'),
          _SummaryCard(label: 'Resolved', value: '$resolved'),
          _SummaryCard(label: 'Dismissed', value: '$dismissed'),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  final PostReport report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = report.status == 'pending';

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceAlt,
          child: const Icon(
            Icons.flag,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        title: Text(
          report.reason,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'by ${report.authorNickname ?? 'unknown'} \u2022 ${_formatDate(report.createdAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isPending
            ? const StatusTag.neutral(label: 'Pending')
            : StatusTag.neutral(label: report.status.toUpperCase()),
        onTap: () => context.push('/admin/reports/detail', extra: report),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return iso;
    }
  }
}
