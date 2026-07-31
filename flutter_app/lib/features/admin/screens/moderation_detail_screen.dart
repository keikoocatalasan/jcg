import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/features/admin/screens/reports_screen.dart';

class ModerationDetailScreen extends ConsumerStatefulWidget {
  final PostReport report;
  const ModerationDetailScreen({super.key, required this.report});

  @override
  ConsumerState<ModerationDetailScreen> createState() =>
      _ModerationDetailScreenState();
}

class _ModerationDetailScreenState
    extends ConsumerState<ModerationDetailScreen> {
  bool _isLoading = false;

  StatusTag _statusTag(String status) {
    switch (status) {
      case 'pending':
        return const StatusTag.neutral(label: 'Pending');
      case 'resolved_hidden':
        return const StatusTag.over(label: 'Hidden');
      case 'dismissed':
        return const StatusTag.ok(label: 'Dismissed');
      case 'reviewed':
        return const StatusTag.ok(label: 'Reviewed');
      case 'action_taken':
        return const StatusTag.over(label: 'Post Removed');
      default:
        return StatusTag.neutral(label: status.toUpperCase());
    }
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final months = [
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
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$minute $amPm';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _approve() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('community_report')
          .update({'status_id': 3}).eq('report_id', widget.report.reportId);
      await _logModerationAction('dismissed', widget.report.reportId,
          widget.report.postId, 'Report dismissed');
      ref.invalidate(reportsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to keep post: $e')),
        );
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.rpc('admin_hide_reported_post', params: {
        'p_report_id': widget.report.reportId,
      });
      ref.invalidate(reportsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove post: $e')),
        );
      }
    }
  }

  Future<void> _reject() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('community_report')
          .update({'status_id': 2}).eq('report_id', widget.report.reportId);
      await _logModerationAction('reviewed', widget.report.reportId,
          widget.report.postId, 'Report marked as reviewed');
      ref.invalidate(reportsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark reviewed: $e')),
        );
      }
    }
  }

  Future<void> _logModerationAction(
    String actionCode,
    String reportId,
    String postId,
    String details,
  ) async {
    try {
      await ref.read(supabaseClientProvider).rpc(
        'admin_log_moderation_action',
        params: {
          'p_action_code': actionCode,
          'p_report_id': reportId,
          'p_post_id': postId,
          'p_details': details,
        },
      );
    } catch (_) {
      try {
        await ref.read(supabaseClientProvider).rpc(
          'admin_log_moderation_action',
          params: {
            'p_action_code': actionCode,
            'p_report_id': reportId,
            'p_post_id': postId,
            'p_details': details,
          },
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Moderation audit log failed to sync'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return Scaffold(
      appBar: AppBar(title: const Text('Report Detail')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Report Info',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                              label: 'Post ID', value: '#${report.postId}'),
                          const SizedBox(height: 8),
                          _InfoRow(
                              label: 'Reported by',
                              value: '@${report.reportedByUserId}'),
                          const SizedBox(height: 8),
                          _InfoRow(
                              label: 'Reported on',
                              value: _formatDateTime(report.createdAt)),
                          const SizedBox(height: 8),
                          _InfoRow(label: 'Reason', value: report.reason),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text(
                                'Status: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              _statusTag(report.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reported Content',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.surfaceAlt,
                                child: Text(
                                  (report.authorNickname ?? 'U')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      report.authorNickname ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      _formatDateTime(report.createdAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (report.postBody != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              report.postBody!,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (report.status == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _approve,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text('Keep Post'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _remove,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.textPrimary,
                              foregroundColor: AppColors.surface,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text('Remove Post'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _reject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                  color: AppColors.borderStrong),
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text('Mark Reviewed'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
