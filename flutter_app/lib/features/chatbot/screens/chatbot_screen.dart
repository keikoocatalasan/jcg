import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/features/chatbot/chatbot_provider.dart';
import 'package:jcg_fitness/features/chatbot/suggested_prompts.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _dismissedDisclaimer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatSessionProvider.notifier).loadOrCreateSession();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _messageController.clear();
    await ref.read(chatSessionProvider.notifier).sendMessage(trimmed);
    _scrollToBottom();
  }

  void _onPromptTap(String prompt) => _sendMessage(prompt);

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final session = ref.watch(chatSessionProvider);
    final colors = context.colors;
    final sessionId = session?.chatSessionId;
    final messagesAsync =
        sessionId == null ? null : ref.watch(chatMessagesProvider(sessionId));

    if (sessionId != null) {
      ref.listen(chatMessagesProvider(sessionId), (previous, next) {
        final previousCount = previous?.valueOrNull?.length;
        final nextCount = next.valueOrNull?.length;
        if (nextCount != null && nextCount != previousCount) {
          _scrollToBottom();
        }
      });
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  color: colors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nutrition Coach'),
                  Text(
                    'Practical guidance for your next choice',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            _ConnectionPill(isOnline: isOnline),
          ],
        ),
      ),
      body: GlassBackground(
        child: Column(
          children: [
            if (!_dismissedDisclaimer)
              _DisclaimerBanner(
                onDismiss: () => setState(() => _dismissedDisclaimer = true),
              ),
            if (!isOnline) const _OfflineChatNotice(),
            Expanded(
              child: messagesAsync?.when(
                    data: (messages) {
                      if (messages.isEmpty) {
                        return _EmptyChatView(onPromptTap: _onPromptTap);
                      }
                      return _MessageList(
                        messages: messages,
                        scrollController: _scrollController,
                        onRetry: (message) => ref
                            .read(chatSessionProvider.notifier)
                            .retryFailed(message.id),
                      );
                    },
                    error: (error, _) => _ChatError(message: '$error'),
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ) ??
                  const Center(child: CircularProgressIndicator()),
            ),
            _ChatInput(
              controller: _messageController,
              isOnline: isOnline,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  final bool isOnline;

  const _ConnectionPill({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.circle : Icons.cloud_off_rounded,
            size: isOnline ? 8 : 14,
            color: isOnline ? colors.success : colors.textMuted,
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Ready' : 'Offline',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const _DisclaimerBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GlassContainer(
        level: GlassSurfaceLevel.panel,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: colors.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'General nutrition guidance, not medical advice.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: 'Dismiss notice',
              icon: const Icon(Icons.close_rounded, size: 18),
              color: colors.textMuted,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineChatNotice extends StatelessWidget {
  const _OfflineChatNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: colors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are offline. Messages will wait until you reconnect.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  final ValueChanged<String> onPromptTap;

  const _EmptyChatView({required this.onPromptTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final quickStarts = <(String, String)>[
      ('Breakfast ideas', suggestedPrompts[0]),
      ('More protein', suggestedPrompts[1]),
      ('Budget meals', suggestedPrompts[2]),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassContainer(
            level: GlassSurfaceLevel.panel,
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      Icon(Icons.auto_awesome_rounded, color: colors.onPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Let’s make your next meal easier.',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ask one question about food, portions, goals, or your budget.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Quick starts',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                for (var index = 0; index < quickStarts.length; index++) ...[
                  _PromptChip(
                    label: quickStarts[index].$1,
                    onTap: () => onPromptTap(quickStarts[index].$2),
                  ),
                  if (index != quickStarts.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Or type your own question below.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceGlassStrong,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  final String message;

  const _ChatError({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassContainer(
          level: GlassSurfaceLevel.card,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: colors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The conversation could not be loaded. $message',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final ValueChanged<ChatMessage> onRetry;

  const _MessageList({
    required this.messages,
    required this.scrollController,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isUser = message.roleCode == 'user';
        final colors = context.colors;
        final isFailed = message.deliveryStatus == 'failed';
        final isBlocked = message.safetyStatus == 'blocked';
        final isRedirected = message.safetyStatus == 'redirected';

        return Padding(
          padding: EdgeInsets.only(
            bottom: 14,
            left: isUser ? 42 : 0,
            right: isUser ? 0 : 42,
          ),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 5),
                child: Text(
                  isUser ? 'You' : 'JCG Coach',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              GlassContainer(
                level:
                    isUser ? GlassSurfaceLevel.panel : GlassSurfaceLevel.card,
                padding: const EdgeInsets.all(14),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 5),
                  bottomRight: Radius.circular(isUser ? 5 : 18),
                ),
                fillOpacity: isUser ? 0.28 : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBlocked)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: StatusTag.over(label: 'Blocked'),
                      ),
                    if (isRedirected)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: StatusTag.neutral(label: 'Redirected'),
                      ),
                    Text(
                      message.messageText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isUser
                                ? colors.textPrimary
                                : colors.textPrimary,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              if (isFailed)
                _MessageStatus(
                  icon: Icons.error_outline_rounded,
                  label: 'Failed to send. Tap to retry.',
                  color: colors.error,
                  onTap: () => onRetry(message),
                ),
              if (message.deliveryStatus == 'local_saved' && !isFailed)
                _MessageStatus(
                  icon: Icons.schedule_rounded,
                  label: 'Sending…',
                  color: colors.textMuted,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageStatus extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _MessageStatus({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 5, left: 4, right: 4),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class _ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isOnline;
  final ValueChanged<String> onSend;

  const _ChatInput({
    required this.controller,
    required this.isOnline,
    required this.onSend,
  });

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canSend = _hasText && widget.isOnline;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      child: GlassContainer(
        level: GlassSurfaceLevel.chrome,
        liveBlur: false,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        borderRadius: BorderRadius.circular(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                enabled: widget.isOnline,
                decoration: InputDecoration(
                  hintText: widget.isOnline
                      ? 'Ask one question…'
                      : 'Reconnect to continue chatting',
                  filled: true,
                  fillColor: colors.surfaceGlassStrong,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
                onSubmitted: canSend ? widget.onSend : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed:
                  canSend ? () => widget.onSend(widget.controller.text) : null,
              tooltip: 'Send message',
              icon: const Icon(Icons.arrow_upward_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                disabledBackgroundColor: colors.border,
                disabledForegroundColor: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
