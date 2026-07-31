import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/widgets/internet_required_widget.dart';
import 'package:jcg_fitness/features/community/community_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _controller = TextEditingController();
  final _topicController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  bool _isPublic = true;
  final List<String> _selectedTopics = [];
  static const int _maxCharacters = 500;
  static const List<String> _availableTopics = [
    'Healthy Meals',
    'Fitness',
    'Motivation',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _topicController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _controller.text.trim().isNotEmpty &&
      _controller.text.length <= _maxCharacters;

  void _toggleTopic(String topic) {
    setState(() {
      if (_selectedTopics.contains(topic)) {
        _selectedTopics.remove(topic);
      } else {
        _selectedTopics.add(topic);
      }
    });
  }

  void _addCustomTopic() {
    final topic = _topicController.text.trim();
    if (topic.isNotEmpty && !_selectedTopics.contains(topic)) {
      setState(() {
        _selectedTopics.add(topic);
        _topicController.clear();
      });
    }
  }

  Future<void> _submit() async {
    if (!_isValid || _isSubmitting) return;

    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Creating posts requires an internet connection.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Post'),
        content: const Text(
            'Are you sure you want to share this post with the community?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Share'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(createPostProvider(_controller.text.trim()))();
      ref.invalidate(communityFeedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    if (!isOnline) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Post')),
        body: InternetRequiredWidget(
          featureName: 'Creating posts',
          onGoBack: () => context.pop(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isSubmitting ? null : () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isValid && !_isSubmitting ? _submit : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Post'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
                maxLength: _maxCharacters,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 8),
              Text(
                'Tag Topics (Optional)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final topic in _availableTopics)
                    FilterChip(
                      label: Text(topic),
                      selected: _selectedTopics.contains(topic),
                      onSelected:
                          _isSubmitting ? null : (_) => _toggleTopic(topic),
                    ),
                  for (final topic in _selectedTopics)
                    if (!_availableTopics.contains(topic))
                      Chip(
                        label: Text(topic),
                        onDeleted:
                            _isSubmitting ? null : () => _toggleTopic(topic),
                      ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _topicController,
                      decoration: const InputDecoration(
                        hintText: 'Add a topic...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _addCustomTopic(),
                      enabled: !_isSubmitting,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSubmitting ? null : _addCustomTopic,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Visibility',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.public),
                    label: Text('Public'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.lock_outline),
                    label: Text('Private'),
                  ),
                ],
                selected: {_isPublic},
                onSelectionChanged: _isSubmitting
                    ? null
                    : (selected) {
                        setState(() => _isPublic = selected.first);
                      },
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
