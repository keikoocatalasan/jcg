import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/core/widgets/internet_required_widget.dart';
import 'package:jcg_fitness/core/widgets/loading_widget.dart';
import 'package:jcg_fitness/features/community/community_provider.dart';
import 'package:jcg_fitness/app/theme.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.post_add),
            tooltip: 'Create Post',
            onPressed: isOnline
                ? () => context.push('/create-post')
                : () => _showOfflineSnackbar(context),
          ),
          if (!isOnline)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.wifi_off, color: AppColors.textSecondary),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentPrimary,
          indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.accentPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Trending'),
            Tab(text: 'Latest'),
          ],
        ),
      ),
      body: feedAsync.when(
        loading: () => const LoadingWidget(message: 'Loading feed...'),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.textPrimary),
              const SizedBox(height: 16),
              Text('Failed to load feed',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(communityFeedProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (posts) {
          final orderedPosts = _orderedPosts(posts);
          if (!isOnline && orderedPosts.isEmpty) {
            return const InternetRequiredWidget(
              featureName: 'Community',
            );
          }

          if (orderedPosts.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.forum_outlined,
                        size: 48,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No posts yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Be the first to share something with the community!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(communityFeedProvider);
              await ref.read(communityFeedProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: orderedPosts.length,
              itemBuilder: (context, index) {
                final post = orderedPosts[index];
                return _PostCard(
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
                );
              },
            ),
          );
        },
      ),
    );
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
          content: Text('Creating posts requires an internet connection.')),
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
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
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                        ),
                        Text(
                          DateHelper.formatDateTime(post.createdAt),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.bodyText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: isOnline ? onLike : null,
                    child: Row(
                      children: [
                        Icon(
                          post.isLikedByMe
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: post.isLikedByMe
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.likeCount}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: onTap,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.commentCount}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('View all'),
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
