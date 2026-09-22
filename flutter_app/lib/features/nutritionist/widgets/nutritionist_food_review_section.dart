import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';
import 'package:jcg_fitness/features/nutritionist/widgets/food_report_sheet.dart';

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

    final verificationAsync = isOnline
        ? ref.watch(foodVerificationProvider((food.foodId, servingId)))
        : const AsyncValue<NutritionistCatalogEntry?>.data(null);
    final reviewsAsync = isOnline
        ? ref.watch(foodNutritionistReviewsProvider((food.foodId, servingId)))
        : const AsyncValue.data(<FoodNutritionistReview>[]);
    final verifiedAsync = ref.watch(verifiedNutritionistProvider);

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
                    'Nutrition data review',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (verificationAsync.valueOrNull != null)
                  Flexible(
                    child: _VerificationTag(
                      status: verificationAsync.value!.verificationStatus,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (!isOnline) ...[
              Text(
                'Connect to the internet to view verification details or report food data.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ] else ...[
              _VerificationDetails(entry: verificationAsync.valueOrNull),
              const SizedBox(height: 8),
              reviewsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text(
                  'Nutritionist feedback is temporarily unavailable.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                data: (reviews) => reviews.isEmpty
                    ? Text(
                        'No nutritionist review has been recorded for this serving yet.',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : Column(
                        children: reviews
                            .map((review) => _ReviewItem(review: review))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        showFoodReportSheet(context, ref, food: food),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Report data issue'),
                  ),
                  if (verifiedAsync.valueOrNull == true)
                    OutlinedButton.icon(
                      onPressed: verificationAsync.valueOrNull == null
                          ? null
                          : () => context.push(
                                '/nutritionist/review',
                                extra: verificationAsync.value,
                              ),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Open review'),
                    )
                  else
                    TextButton.icon(
                      onPressed: () =>
                          context.push('/nutritionist-application'),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Apply to review foods'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerificationTag extends StatelessWidget {
  final String status;

  const _VerificationTag({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'verified' => AppColors.success,
      'needs_revision' => AppColors.warning,
      'rejected' => AppColors.error,
      'in_review' => AppColors.primary,
      _ => AppColors.textSecondary,
    };
    final label = nutritionistVerificationLabels[status] ?? 'Unreviewed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VerificationDetails extends StatelessWidget {
  final NutritionistCatalogEntry? entry;

  const _VerificationDetails({required this.entry});

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return Text(
        'Notes apply to this listed serving and do not replace personal nutrition advice.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      );
    }
    final sourceLabel = entry!.sourceType == null
        ? null
        : nutritionistSourceTypes[entry!.sourceType] ?? entry!.sourceType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes apply to this listed serving and do not replace personal nutrition advice.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        if (entry!.verifiedAt != null)
          Text(
            'Reviewed ${DateFormat('MMM d, yyyy').format(entry!.verifiedAt!.toLocal())} · Admin-approved nutritionist',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        if (sourceLabel != null)
          Text(
            'Source: $sourceLabel${entry!.sourceName == null ? '' : ' · ${entry!.sourceName}'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        if (entry!.verificationStatus != 'verified')
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'This nutrition data has not been verified by an admin-approved nutritionist.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
            ),
          ),
      ],
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final FoodNutritionistReview review;

  const _ReviewItem({required this.review});

  @override
  Widget build(BuildContext context) {
    final isLegacy = review.isLegacy;
    final decisionLabel = review.decision == null
        ? null
        : nutritionistVerificationLabels[review.decision] ?? review.decision!;
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
          if (decisionLabel != null) ...[
            _AssessmentTag(label: decisionLabel),
          ] else if (isLegacy) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (review.servingAssessment != null)
                  _AssessmentTag(
                    label: _servingLabel(review.servingAssessment!),
                  ),
                if (review.macroAssessment != null)
                  _AssessmentTag(
                    label: _macroLabel(review.macroAssessment!),
                  ),
              ],
            ),
          ],
          if ((review.reviewNote ?? review.comment ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text((review.reviewNote ?? review.comment ?? '').trim()),
          ],
          const SizedBox(height: 4),
          Text(
            isLegacy
                ? 'Advisory note (legacy) · ${DateFormat('MMM d, yyyy').format(review.updatedAt.toLocal())}'
                : 'Updated ${DateFormat('MMM d, yyyy').format(review.updatedAt.toLocal())} · Admin-approved nutritionist',
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
