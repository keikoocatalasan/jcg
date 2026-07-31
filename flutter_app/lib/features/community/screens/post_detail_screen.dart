import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/community/community_provider.dart';
import 'package:jcg_fitness/features/community/screens/report_post_dialog.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  CommunityPost? get _post => GoRouterState.of(context).extra as CommunityPost?;

  Future<void> _toggleLike(CommunityPost post) async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      _showError('Liking posts requires an internet connection.');
      return;
    }

    try {
      await ref.read(likePostProvider(post.postId))();
      ref.invalidate(communityFeedProvider);
    } catch (e) {
      _showError('$e');
    }
  }

  Future<void> _submitComment(CommunityPost post) async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmittingComment) return;

    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      _showError('Adding comments requires an internet connection.');
      return;
    }

    setState(() => _isSubmittingComment = true);

    try {
      await ref.read(createCommentProvider(
          CreateCommentInput(postId: post.postId, bodyText: text)))();
      _commentController.clear();
      ref.invalidate(postCommentsProvider(post.postId));
      ref.invalidate(communityFeedProvider);
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  Future<void> _deletePost(CommunityPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(deletePostProvider(post.postId))();
      ref.invalidate(communityFeedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted.')),
        );
        context.pop();
      }
    } catch (e) {
      _showError('$e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reportPost(CommunityPost post) async {
    final input = await showReportPostDialog(context, post.postId);
    if (input != null) {
      try {
        await ref.read(reportPostProvider(input))();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post reported. We\'ll review it.')),
          );
        }
      } catch (e) {
        if (mounted) _showError('$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post Detail')),
        body: const Center(child: Text('Post not found.')),
      );
    }

    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isOwnPost = currentUser?.id == post.userId;
    final commentsAsync = ref.watch(postCommentsProvider(post.postId));
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (isOwnPost)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: isOnline ? () => _deletePost(post) : null,
              tooltip: 'Delete post',
            ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            onPressed: isOnline ? () => _reportPost(post) : null,
            tooltip: 'Report',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _PostContent(
                    post: post,
                    isOnline: isOnline,
                    onLike: () => _toggleLike(post)),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                commentsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Failed to load comments.',
                        style:
                            TextStyle(color: Theme.of(context).disabledColor),
                      ),
                    ),
                  ),
                  data: (comments) {
                    if (comments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No comments yet.',
                            style: TextStyle(
                                color: Theme.of(context).disabledColor),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return _CommentTile(comment: comment);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          if (isOnline)
            _CommentInput(
              controller: _commentController,
              isSubmitting: _isSubmittingComment,
              onSubmit: () => _submitComment(post),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.surfaceAlt,
              child: Text(
                'Comments require an internet connection.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _PostContent extends StatelessWidget {
  final CommunityPost post;
  final bool isOnline;
  final VoidCallback onLike;

  const _PostContent({
    required this.post,
    required this.isOnline,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceAlt,
                  child: Text(
                    post.authorNickname.isNotEmpty
                        ? post.authorNickname[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorNickname,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        DateHelper.formatDateTime(post.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).disabledColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              post.bodyText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                    color: post.isLikedByMe ? AppColors.textPrimary : null,
                  ),
                  onPressed: isOnline ? onLike : null,
                ),
                Text(
                  '${post.likeCount}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                const Icon(Icons.comment_outlined),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommunityComment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.surfaceAlt,
            child: Text(
              comment.authorNickname.isNotEmpty
                  ? comment.authorNickname[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorNickname,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateHelper.formatTime(comment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).disabledColor,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.bodyText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _CommentInput({
    required this.controller,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              enabled: !isSubmitting,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: isSubmitting ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}
