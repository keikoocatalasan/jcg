import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

class NutritionistFoodReviewSection extends ConsumerWidget {
  final Food food;
  final bool isOnline;

  const NutritionistFoodReviewSection({
    super.key,
    required this.food,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servingId = food.servingId;
    if (!food.isOfficial || servingId == null) return const SizedBox.shrink();

    final approvedAsync = ref.watch(approvedNutritionistProvider);
    final reviewsAsync = isOnline
        ? ref.watch(foodNutritionistReviewsProvider((food.foodId, servingId)))
        : const AsyncValue.data(<FoodNutritionistReview>[]);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.health_and_safety_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nutritionist feedback',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isOnline
                  ? 'Notes apply to this listed serving and do not replace personal nutrition advice.'
                  : 'Connect to the internet to view or submit nutritionist feedback.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (!isOnline) ...[
              const SizedBox(height: 10),
              const Text('This review feature is online-only.'),
            ] else ...[
              const SizedBox(height: 10),
              reviewsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text(
                  'Nutritionist feedback is temporarily unavailable.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                data: (reviews) => reviews.isEmpty
                    ? Text(
                        'No nutritionist feedback for this serving yet.',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : Column(
                        children: reviews
                            .map((review) => _ReviewItem(review: review))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 10),
              approvedAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (approved) => approved
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _openReviewForm(
                            context,
                            ref,
                            servingId,
                          ),
                          icon: const Icon(Icons.rate_review_outlined),
                          label: const Text('Submit or update review'),
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              context.push('/nutritionist-application'),
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Apply to review foods'),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openReviewForm(
    BuildContext context,
    WidgetRef ref,
    String servingId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NutritionistReviewForm(
        food: food,
        servingId: servingId,
      ),
    );
    ref.invalidate(foodNutritionistReviewsProvider((food.foodId, servingId)));
  }
}

class _ReviewItem extends StatelessWidget {
  final FoodNutritionistReview review;

  const _ReviewItem({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _AssessmentTag(label: _servingLabel(review.servingAssessment)),
              _AssessmentTag(label: _macroLabel(review.macroAssessment)),
            ],
          ),
          if (review.comment?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(review.comment!),
          ],
          const SizedBox(height: 4),
          Text(
            'Updated ${DateFormat('MMM d, yyyy').format(review.updatedAt.toLocal())} · Admin-approved nutritionist',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  String _servingLabel(String value) => switch (value) {
        'balanced_for_serving' => 'Balanced for this serving',
        'watch_portion' => 'Consider the portion',
        _ => 'Needs more context',
      };

  String _macroLabel(String value) => switch (value) {
        'consistent' => 'Macros look consistent',
        'needs_recheck' => 'Macros need rechecking',
        _ => 'Source is not enough to confirm macros',
      };
}

class _AssessmentTag extends StatelessWidget {
  final String label;

  const _AssessmentTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      padding: EdgeInsets.zero,
    );
  }
}

class _NutritionistReviewForm extends ConsumerStatefulWidget {
  final Food food;
  final String servingId;

  const _NutritionistReviewForm({required this.food, required this.servingId});

  @override
  ConsumerState<_NutritionistReviewForm> createState() =>
      _NutritionistReviewFormState();
}

class _NutritionistReviewFormState
    extends ConsumerState<_NutritionistReviewForm> {
  final _commentController = TextEditingController();
  String _servingAssessment = 'needs_context';
  String _macroAssessment = 'insufficient_source';
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ref.read(nutritionistServiceProvider).submitFoodReview(
            foodId: widget.food.foodId,
            servingId: widget.servingId,
            servingAssessment: _servingAssessment,
            macroAssessment: _macroAssessment,
            comment: _commentController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review could not be saved: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Review ${widget.food.foodName}',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Assess the listed serving, not whether the food is universally healthy. Your feedback will not directly change the official nutrition values.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _servingAssessment,
            decoration: const InputDecoration(
              labelText: 'Serving assessment',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'balanced_for_serving',
                child: Text('Balanced for this serving'),
              ),
              DropdownMenuItem(
                value: 'watch_portion',
                child: Text('Consider the portion'),
              ),
              DropdownMenuItem(
                value: 'needs_context',
                child: Text('Needs more context'),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _servingAssessment = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _macroAssessment,
            decoration: const InputDecoration(
              labelText: 'Macro calculation',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'consistent',
                child: Text('Looks consistent'),
              ),
              DropdownMenuItem(
                value: 'needs_recheck',
                child: Text('Needs rechecking'),
              ),
              DropdownMenuItem(
                value: 'insufficient_source',
                child: Text('Not enough source information'),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _macroAssessment = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLength: 1200,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Nutritionist note (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_saving ? 'Saving…' : 'Save nutritionist review'),
          ),
        ],
      ),
    );
  }
}
