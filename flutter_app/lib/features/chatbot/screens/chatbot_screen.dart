import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
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
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _messageController.clear();
    await ref.read(chatSessionProvider.notifier).sendMessage(text.trim());
    _scrollToBottom();
  }

  void _onPromptTap(String prompt) {
    _sendMessage(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final session = ref.watch(chatSessionProvider);
    final theme = Theme.of(context);

    final sessionId = session?.chatSessionId;
    final messagesAsync =
        sessionId != null ? ref.watch(chatMessagesProvider(sessionId)) : null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.eco, size: 24),
            const SizedBox(width: 8),
            const Text('JCG Fitness'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'BETA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!isOnline)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.wifi_off, color: AppColors.textSecondary),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_dismissedDisclaimer)
            _DisclaimerBanner(onDismiss: () {
              setState(() => _dismissedDisclaimer = true);
            }),
          if (!isOnline)
            Container(
              width: double.infinity,
              color: AppColors.surfaceAlt,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off,
                      size: 16, color: AppColors.textPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You\'re offline. New messages will be sent when reconnected.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: messagesAsync?.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return _EmptyChatView(onPromptTap: _onPromptTap);
                    }
                    return _MessageList(
                      messages: messages,
                      scrollController: _scrollController,
                      onRetry: (msg) {
                        ref
                            .read(chatSessionProvider.notifier)
                            .retryFailed(msg.id);
                      },
                    );
                  },
                  error: (err, _) => Center(child: Text('Error: $err')),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                ) ??
                const Center(child: CircularProgressIndicator()),
          ),
          _ChatInput(
            controller: _messageController,
            isOnline: isOnline,
            onSend: (text) => _sendMessage(text),
            showPrompts: messagesAsync != null,
            onPromptTap: _onPromptTap,
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
    return MaterialBanner(
      backgroundColor: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This AI assistant provides general nutrition information only, not medical advice. Always consult a healthcare professional.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Got it', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  final void Function(String) onPromptTap;
  const _EmptyChatView({required this.onPromptTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Text(
              "Hi! I'm your JCG Fitness coach. Ask me about nutrition, healthy eating, or your goals.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Try asking',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...suggestedPrompts.take(5).map((prompt) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: () => onPromptTap(prompt),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              prompt,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (sheetContext) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      Text('Suggested prompts',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final prompt in suggestedPrompts)
                        ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: Text(prompt),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            onPromptTap(prompt);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              child: const Text(
                'See more prompts >',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final void Function(ChatMessage) onRetry;

  const _MessageList({
    required this.messages,
    required this.scrollController,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isUser = msg.roleCode == 'user';
        final isFailed = msg.deliveryStatus == 'failed';
        final isBlocked = msg.safetyStatus == 'blocked';
        final isRedirected = msg.safetyStatus == 'redirected';

        return Padding(
          padding: EdgeInsets.only(
            bottom: 12,
            left: isUser ? 48 : 0,
            right: isUser ? 0 : 48,
          ),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isUser ? AppColors.textPrimary : AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: isUser
                      ? null
                      : Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBlocked)
                      const Row(
                        children: [
                          StatusTag.over(label: 'Blocked'),
                        ],
                      ),
                    if (isRedirected)
                      const Row(
                        children: [
                          StatusTag.neutral(label: 'Redirected'),
                        ],
                      ),
                    Text(
                      msg.messageText,
                      style: TextStyle(
                        color:
                            isUser ? AppColors.surface : AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: GestureDetector(
                    onTap: () => onRetry(msg),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 14, color: AppColors.error),
                        SizedBox(width: 4),
                        Text(
                          'Failed to send. Tap to retry.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (msg.deliveryStatus == 'local_saved' && !isFailed)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Sending...',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isOnline;
  final void Function(String) onSend;
  final bool showPrompts;
  final void Function(String) onPromptTap;

  const _ChatInput({
    required this.controller,
    required this.isOnline,
    required this.onSend,
    this.showPrompts = false,
    required this.onPromptTap,
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
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && widget.isOnline;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showPrompts)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestedPrompts.take(4).map((prompt) {
                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      onTap: () => widget.onPromptTap(prompt),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          prompt,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
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
                          ? 'Ask a question...'
                          : 'Connect to internet to chat',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withAlpha(128),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: canSend ? (v) => widget.onSend(v) : null,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: canSend ? AppColors.textPrimary : AppColors.border,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: canSend
                        ? () => widget.onSend(widget.controller.text)
                        : null,
                    icon: const Icon(Icons.send_rounded),
                    color: AppColors.surface,
                    splashRadius: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
