import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/chat_message_repository.dart' as db;
import 'package:jcg_fitness/core/database/chat_session_repository.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/chatbot/chatbot_provider.dart';

final _sessionsWithPreviewProvider =
    FutureProvider<List<_SessionWithPreview>>((ref) async {
  final user = ref.read(authStateProvider).valueOrNull;
  if (user == null) return [];

  final dbProvider = DatabaseProvider();
  final sessionRepo = ChatSessionRepository(dbProvider);
  final msgRepo = db.ChatMessageRepository(dbProvider);
  final localUserId = await LocalUserIdentity.resolve(dbProvider, user.id);

  final sessions = await sessionRepo.queryByUser(localUserId);
  final result = <_SessionWithPreview>[];

  for (final session in sessions) {
    final messages = await msgRepo.queryBySession(session.chatSessionId);
    final lastMsg =
        messages.isNotEmpty ? messages.last.messageText : 'No messages';
    final firstUserMsg = messages
        .where((m) => m.roleCode == 'user')
        .map((m) => m.messageText)
        .firstOrNull;
    result.add(_SessionWithPreview(
      session: session,
      lastMessagePreview: lastMsg,
      messageCount: messages.length,
      title: firstUserMsg != null
          ? (firstUserMsg.length > 40
              ? '${firstUserMsg.substring(0, 40)}...'
              : firstUserMsg)
          : 'New Chat',
    ));
  }

  return result;
});

class _SessionWithPreview {
  final ChatSession session;
  final String lastMessagePreview;
  final int messageCount;
  final String title;

  const _SessionWithPreview({
    required this.session,
    required this.lastMessagePreview,
    required this.messageCount,
    required this.title,
  });
}

class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  ConsumerState<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends ConsumerState<ChatHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date.year, date.month, date.day);
      final diff = today.difference(dateOnly).inDays;
      final hour =
          date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      final timeStr = '$hour:$minute $amPm';

      if (diff == 0) return 'Today, $timeStr';
      if (diff == 1) return 'Yesterday, $timeStr';
      return '${DateHelper.formatDate(isoDate)}, $timeStr';
    } catch (_) {
      return isoDate;
    }
  }

  bool _isThisWeek(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      return date.isAfter(
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day));
    } catch (_) {
      return false;
    }
  }

  Map<String, List<_SessionWithPreview>> _groupSessions(
      List<_SessionWithPreview> sessions) {
    final thisWeek = <_SessionWithPreview>[];
    final older = <_SessionWithPreview>[];

    for (final s in sessions) {
      if (_isThisWeek(s.session.startedAt)) {
        thisWeek.add(s);
      } else {
        older.add(s);
      }
    }

    return {
      if (thisWeek.isNotEmpty) 'This Week': thisWeek,
      if (older.isNotEmpty) 'Older': older,
    };
  }

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History'),
        content: const Text(
          'This will permanently delete all chat sessions and messages. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final user = ref.read(authStateProvider).valueOrNull;
              if (user == null) return;
              final dbProvider = DatabaseProvider();
              final sessionRepo = ChatSessionRepository(dbProvider);
              final msgRepo = db.ChatMessageRepository(dbProvider);
              final localUserId =
                  await LocalUserIdentity.resolve(dbProvider, user.id);
              final sessions = await sessionRepo.queryByUser(localUserId);
              for (final session in sessions) {
                final msgs =
                    await msgRepo.queryBySession(session.chatSessionId);
                for (final msg in msgs) {
                  await msgRepo.delete(msg.chatMessageId);
                }
                await sessionRepo.delete(session.chatSessionId);
              }
              ref.invalidate(_sessionsWithPreviewProvider);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(_sessionsWithPreviewProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Chat History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  setState(() => _searchQuery = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor:
                    theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_sessionsWithPreviewProvider);
              },
              child: sessionsAsync.when(
                data: (sessions) {
                  final filtered = _searchQuery.isEmpty
                      ? sessions
                      : sessions
                          .where((s) =>
                              s.title.toLowerCase().contains(_searchQuery) ||
                              s.lastMessagePreview
                                  .toLowerCase()
                                  .contains(_searchQuery))
                          .toList();

                  if (filtered.isEmpty) {
                    return _buildEmptyState(context, _searchQuery.isNotEmpty);
                  }

                  final grouped = _groupSessions(filtered);
                  final sections = grouped.entries.toList();

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: sections.fold<int>(
                        0, (sum, e) => sum + 1 + e.value.length),
                    itemBuilder: (context, index) {
                      int running = 0;
                      for (final entry in sections) {
                        if (index == running) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          );
                        }
                        running++;
                        final itemIndex = index - running;
                        if (itemIndex >= 0 && itemIndex < entry.value.length) {
                          final item = entry.value[itemIndex];
                          return _buildSessionTile(context, ref, item);
                        }
                        running += entry.value.length;
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
                error: (err, _) => ListView(
                  children: [
                    const SizedBox(height: 64),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: AppColors.textPrimary),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load chat history',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$err',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                loading: () => ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: 6,
                  itemBuilder: (_, __) => _buildSkeletonTile(context),
                ),
              ),
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildSessionTile(
      BuildContext context, WidgetRef ref, _SessionWithPreview item) {
    final session = item.session;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceAlt,
        radius: 22,
        child: Icon(
          session.endedAt == null
              ? Icons.chat_bubble
              : Icons.check_circle_outline,
          color: AppColors.textPrimary,
          size: 18,
        ),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            item.lastMessagePreview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                _formatTimestamp(session.startedAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.messageCount} message${item.messageCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await ref
            .read(chatSessionProvider.notifier)
            .switchSession(session.chatSessionId);
        if (context.mounted) context.go('/chatbot');
      },
    );
  }

  Widget _buildSkeletonTile(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppColors.border,
        radius: 22,
      ),
      title: Container(
        height: 14,
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Container(
            height: 12,
            width: 200,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 10,
            width: 100,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.border),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isSearch) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        const SizedBox(height: 64),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSearch ? Icons.search_off : Icons.chat_bubble_outline,
                size: 64,
                color: AppColors.border,
              ),
              const SizedBox(height: 16),
              Text(
                isSearch ? 'No conversations found' : 'No conversations yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSearch
                    ? 'Try a different search term.'
                    : 'Start a conversation to see it here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (!isSearch) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/chatbot'),
                  icon: const Icon(Icons.chat),
                  label: const Text('Start Chatting'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Chat history is available offline.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showClearAllDialog(context),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear All History'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
