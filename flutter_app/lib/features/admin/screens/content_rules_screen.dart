import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:jcg_fitness/features/admin/admin_provider.dart';

class ContentRulesScreen extends ConsumerWidget {
  const ContentRulesScreen({super.key});

  Future<void> _addWord(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final word = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add blocked word'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'Word or short phrase',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    final normalized = word?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty || !context.mounted) return;

    try {
      await ref
          .read(supabaseClientProvider)
          .from('community_blocked_word')
          .insert({
        'blocked_word': normalized,
      });
      ref.invalidate(adminBlockedWordsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to add rule: $error')),
        );
      }
    }
  }

  Future<void> _toggleWord(
    BuildContext context,
    WidgetRef ref,
    AdminBlockedWord item,
    bool value,
  ) async {
    try {
      await ref
          .read(supabaseClientProvider)
          .from('community_blocked_word')
          .update({'is_active': value}).eq('blocked_word_id', item.id);
      ref.invalidate(adminBlockedWordsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update rule: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsAsync = ref.watch(adminBlockedWordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Content Rules'),
        actions: [
          IconButton(
            tooltip: 'Add blocked word',
            onPressed: () => _addWord(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: wordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                const Text('Unable to load content rules.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(adminBlockedWordsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (words) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Active rules are enforced by the database for posts and comments. The app also checks text before sending it so users get immediate feedback.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (words.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No blocked words configured.')),
                ),
              )
            else
              ...words.map(
                (item) => Card(
                  child: SwitchListTile(
                    title: Text(item.word),
                    subtitle: Text(item.isActive ? 'Enforced' : 'Disabled'),
                    value: item.isActive,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) =>
                        _toggleWord(context, ref, item, value),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
