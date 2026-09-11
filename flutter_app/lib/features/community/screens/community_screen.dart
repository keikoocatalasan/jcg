import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/core/widgets/internet_required_widget.dart';
import 'package:jcg_fitness/core/widgets/loading_widget.dart';
import 'package:jcg_fitness/features/community/community_provider.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(communityRealtimeProvider);
    final feedAsync = ref.watch(communityFeedProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Community'),
            Text(
              'Share progress. Find momentum.',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.post_add_rounded),
            tooltip: 'Create Post',
            onPressed: isOnline
                ? () => context.push('/create-post')
                : () => _showOfflineSnackbar(context),
          ),
          if (!isOnline)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.wifi_off_rounded, color: colors.textMuted),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Trending'),
                Tab(text: 'Latest'),
              ],
            ),
          ),
        ),
      ),
      body: feedAsync.when(
        loading: () => const LoadingWidget(message: 'Loading community...'),
        error: (e, _) => _FeedError(
          onRetry: () => ref.invalidate(communityFeedProvider),
        ),
        data: (posts) => _buildFeed(context, posts, isOnline),
      ),
    );
  }

  Widget _buildFeed(
    BuildContext context,
    List<CommunityPost> posts,
    bool isOnline,
  ) {
    final orderedPosts = _orderedPosts(posts);
    final colors = context.colors;

    if (!isOnline && orderedPosts.isEmpty) {
      return const InternetRequiredWidget(featureName: 'Community');
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () async {
        ref.invalidate(communityFeedProvider);
        await ref.read(communityFeedProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          _CommunityIntroCard(
            isOnline: isOnline,
            onCreate: isOnline
                ? () => context.push('/create-post')
                : () => _showOfflineSnackbar(context),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                _tabLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                '${orderedPosts.length} ${orderedPosts.length == 1 ? 'post' : 'posts'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (orderedPosts.isEmpty)
            const _EmptyCommunityState()
          else
            ...orderedPosts.map(
              (post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PostCard(
                  post: post,
                  isOnline: isOnline,
                  onTap: () => context.push('/post-detail', extra: post),
                  onLike: () async {
                    try {
                      await ref.read(likePostProvider(post.postId))();
                      ref.invalidate(communityFeedProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  String get _tabLabel {
    switch (_tabController.index) {
      case 1:
        return 'Trending now';
      case 2:
        return 'Latest posts';
      default:
        return 'Your community';
    }
  }

  List<CommunityPost> _orderedPosts(List<CommunityPost> posts) {
    final ordered = List<CommunityPost>.from(posts);
    if (_tabController.index == 1) {
      ordered.sort((a, b) {
        final scoreA = a.likeCount + a.commentCount * 2;
        final scoreB = b.likeCount + b.commentCount * 2;
        return scoreB.compareTo(scoreA);
      });
    } else {
      ordered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return ordered;
  }

  void _showOfflineSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Creating posts requires an internet connection.'),
      ),
    );
  }
}

class _CommunityIntroCard extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onCreate;

  const _CommunityIntroCard({required this.isOnline, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [colors.surfaceElevated, colors.accentSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.forum_rounded, color: colors.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep each other going',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Share a meal win, a workout note, or a small habit.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onCreate,
            tooltip: isOnline ? 'Create post' : 'Go online to create a post',
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyCommunityState extends StatelessWidget {
  const _EmptyCommunityState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 34, color: colors.primary),
          const SizedBox(height: 14),
          Text(
            'No posts here yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start the conversation and make the next healthy choice easier for someone else.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  final VoidCallback onRetry;

  const _FeedError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 42, color: colors.textMuted),
            const SizedBox(height: 14),
            Text(
              'The community is taking a moment',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  final CommunityPost post;
  final bool isOnline;
  final VoidCallback onTap;
  final VoidCallback onLike;

  const _PostCard({
    required this.post,
    required this.isOnline,
    required this.onTap,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final initial = post.authorNickname.trim().isEmpty
        ? '?'
        : post.authorNickname.trim()[0].toUpperCase();

    return Material(
      color: colors.surfaceElevated,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colors.accentSoft,
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateHelper.formatDateTime(post.createdAt),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.textMuted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.more_horiz_rounded, color: colors.textMuted),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                post.bodyText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                    ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Divider(color: colors.border, height: 1),
              Row(
                children: [
                  _PostAction(
                    icon: post.isLikedByMe
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: '${post.likeCount}',
                    color: post.isLikedByMe ? colors.error : colors.textMuted,
                    onPressed: isOnline ? onLike : null,
                    tooltip: post.isLikedByMe ? 'Unlike post' : 'Like post',
                  ),
                  _PostAction(
                    icon: Icons.mode_comment_outlined,
                    label: '${post.commentCount}',
                    color: colors.textMuted,
                    onPressed: onTap,
                    tooltip: 'Open comments',
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Open'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final String tooltip;

  const _PostAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$tooltip, $label',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    color: onPressed == null
                        ? color.withValues(alpha: 0.45)
                        : color,
                    size: 20),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onPressed == null
                            ? color.withValues(alpha: 0.45)
                            : color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
