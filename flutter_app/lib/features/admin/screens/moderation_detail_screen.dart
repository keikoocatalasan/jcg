import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/features/admin/admin_provider.dart';
import 'package:jcg_fitness/features/admin/screens/reports_screen.dart';

class ModerationComment {
  final String commentId;
  final String userId;
  final String commentText;
  final bool isHidden;
  final bool isDeleted;
  final String? nickname;
  final DateTime createdAt;

  const ModerationComment({
    required this.commentId,
    required this.userId,
    required this.commentText,
    required this.isHidden,
    required this.isDeleted,
    required this.nickname,
    required this.createdAt,
  });
}

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
  bool _commentsLoading = true;
  String? _commentsError;
  List<ModerationComment> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _commentsLoading = true;
      _commentsError = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final rows = await supabase
          .from('community_comment')
          .select(
              'comment_id, user_id, comment_text, is_hidden, is_deleted, created_at')
          .eq('post_id', widget.report.postId)
          .order('created_at');
      final userIds = rows.map((row) => row['user_id'] as String).toSet().toList();
      final profileRows = userIds.isEmpty
          ? const <dynamic>[]
          : await supabase
              .from('user_profile')
              .select('user_id, nickname')
              .inFilter('user_id', userIds);
      final nicknames = <String, String?>{
        for (final row in profileRows)
          row['user_id'] as String: row['nickname'] as String?,
      };

      final comments = rows.map((row) {
        return ModerationComment(
          commentId: row['comment_id'] as String,
          userId: row['user_id'] as String,
          commentText: row['comment_text'] as String,
          isHidden: row['is_hidden'] as bool? ?? false,
          isDeleted: row['is_deleted'] as bool? ?? false,
          nickname: nicknames[row['user_id'] as String],
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _comments = comments;
          _commentsLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _commentsError = '$error';
          _commentsLoading = false;
        });
      }
    }
  }

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
      await supabase.rpc('admin_resolve_report', params: {
        'p_report_id': widget.report.reportId,
        'p_status_code': 'dismissed',
        'p_details': 'Report dismissed',
      });
      ref.invalidate(reportsProvider);
      ref.invalidate(adminAuditLogProvider);
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
    await _setPostVisibility(true);
  }

  Future<void> _reject() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.rpc('admin_resolve_report', params: {
        'p_report_id': widget.report.reportId,
        'p_status_code': 'reviewed',
        'p_details': 'Report marked as reviewed',
      });
      ref.invalidate(reportsProvider);
      ref.invalidate(adminAuditLogProvider);
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

  Future<void> _setPostVisibility(bool hidden) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(supabaseClientProvider).rpc('admin_set_post_visibility',
          params: {
        'p_post_id': widget.report.postId,
        'p_is_hidden': hidden,
        'p_report_id': widget.report.reportId,
        'p_details': hidden ? 'Post hidden by administrator' : 'Post restored by administrator',
      });
      ref.invalidate(reportsProvider);
      ref.invalidate(adminAuditLogProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change post visibility: $error')),
        );
      }
    }
  }

  Future<void> _setCommentVisibility(
    ModerationComment comment,
    bool hidden,
  ) async {
    try {
      await ref.read(supabaseClientProvider).rpc(
        'admin_set_comment_visibility',
        params: {
          'p_comment_id': comment.commentId,
          'p_is_hidden': hidden,
          'p_details': hidden
              ? 'Comment hidden during post review'
              : 'Comment restored during post review',
        },
      );
      ref.invalidate(adminAuditLogProvider);
      await _loadComments();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change comment visibility: $error')),
        );
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
                          if (report.reportDetails != null) ...[
                            const SizedBox(height: 8),
                            _InfoRow(
                              label: 'Details',
                              value: report.reportDetails!,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _InfoRow(
                            label: 'Visibility',
                            value: report.isHidden ? 'Hidden' : 'Visible',
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
                  const SizedBox(height: 16),
                  _buildComments(),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _setPostVisibility(!report.isHidden),
                        icon: Icon(report.isHidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        label: Text(report.isHidden ? 'Unhide Post' : 'Hide Post'),
                      ),
                      if (report.status == 'pending') ...[
                        OutlinedButton(
                          onPressed: _approve,
                          child: const Text('Keep Post'),
                        ),
                        OutlinedButton(
                          onPressed: _reject,
                          child: const Text('Mark Reviewed'),
                        ),
                        OutlinedButton(
                          onPressed: _remove,
                          child: const Text('Remove and Resolve'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildComments() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (_commentsLoading)
              const Center(child: CircularProgressIndicator())
            else if (_commentsError != null)
              Row(
                children: [
                  const Expanded(child: Text('Failed to load comments.')),
                  IconButton(
                    tooltip: 'Retry',
                    onPressed: _loadComments,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              )
            else if (_comments.isEmpty)
              const Text(
                'No comments on this post.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ..._comments.map(_buildCommentCard),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCard(ModerationComment comment) {
    final stateLabel = comment.isDeleted
        ? 'Deleted'
        : comment.isHidden
            ? 'Hidden'
            : 'Visible';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: comment.isHidden ? AppColors.surfaceAlt : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.nickname ?? 'Unknown user',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                stateLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(comment.commentText),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDateTime(comment.createdAt.toIso8601String()),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (!comment.isDeleted)
                TextButton(
                  onPressed: () =>
                      _setCommentVisibility(comment, !comment.isHidden),
                  child: Text(comment.isHidden ? 'Unhide' : 'Hide'),
                ),
            ],
          ),
        ],
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
