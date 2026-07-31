import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/recommendations/recommendation_engine.dart';

class RecommendationDetailScreen extends ConsumerWidget {
  const RecommendationDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extra = GoRouterState.of(context).extra;
    if (extra is! ScoredFood) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recommendation Detail')),
        body: const Center(child: Text('No recommendation data')),
      );
    }

    final scored = extra;
    final food = scored.food;
    final dashAsync = ref.watch(dashboardDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recommendation Detail')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const _CachedInfoBanner(),
          const SizedBox(height: 8),
          _FoodHeader(food: food, scored: scored),
          const SizedBox(height: 16),
          _WhyRecommended(scored: scored),
          const SizedBox(height: 16),
          dashAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) => _BudgetContext(food: food, data: data),
          ),
          const SizedBox(height: 16),
          _NutritionSummary(food: food),
          const SizedBox(height: 16),
          _MealOverview(food: food),
          const SizedBox(height: 16),
          _ServingInfo(food: food),
          const SizedBox(height: 16),
          dashAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) => _BudgetImpact(food: food, data: data),
          ),
          const SizedBox(height: 16),
          _RelatedAlternatives(scored: scored),
          const SizedBox(height: 24),
          _ActionButtons(food: food),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CachedInfoBanner extends StatelessWidget {
  const _CachedInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing cached recommendation. Last updated: just now',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodHeader extends StatelessWidget {
  final Food food;
  final ScoredFood scored;

  const _FoodHeader({required this.food, required this.scored});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FoodImageLarge(foodName: food.foodName),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.foodName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        food.categoryName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.monetization_on,
                              size: 16, color: AppColors.budgetColor),
                          const SizedBox(width: 4),
                          Text(
                            Formatters.formatPhp(food.estimatedPricePhp),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.budgetColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _MealContextBadge(),
                    ],
                  ),
                ),
                _MatchBadge(score: scored.finalScore),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _NutritionGrid(food: food),
          ],
        ),
      ),
    );
  }
}

class _FoodImageLarge extends StatelessWidget {
  final String foodName;
  const _FoodImageLarge({required this.foodName});

  @override
  Widget build(BuildContext context) {
    final initial = foodName.isNotEmpty ? foodName[0].toUpperCase() : '?';
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  final double score;
  const _MatchBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '${(score * 100).round()}%',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          Text(
            'Match',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealContextBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String label;
    if (hour < 11) {
      label = 'Breakfast';
    } else if (hour < 15) {
      label = 'Lunch';
    } else if (hour < 18) {
      label = 'Snack';
    } else {
      label = 'Dinner';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.secondary,
        ),
      ),
    );
  }
}

class _NutritionGrid extends StatelessWidget {
  final Food food;
  const _NutritionGrid({required this.food});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NutrientColumn(
            label: 'Calories',
            value: Formatters.formatCalories(food.calories),
          ),
        ),
        Expanded(
          child: _NutrientColumn(
            label: 'Protein',
            value: Formatters.formatMacro(food.proteinG),
          ),
        ),
        Expanded(
          child: _NutrientColumn(
            label: 'Carbs',
            value: Formatters.formatMacro(food.carbsG),
          ),
        ),
        Expanded(
          child: _NutrientColumn(
            label: 'Fat',
            value: Formatters.formatMacro(food.fatG),
          ),
        ),
      ],
    );
  }
}

class _NutrientColumn extends StatelessWidget {
  final String label;
  final String value;

  const _NutrientColumn({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text(
              value.replaceAll(' kcal', '').replaceAll('g', ''),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _WhyRecommended extends StatelessWidget {
  final ScoredFood scored;
  const _WhyRecommended({required this.scored});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppColors.secondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Why This is Recommended',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildReasonChips(scored),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReasonChips(ScoredFood scored) {
    final chips = <String>[];

    if (scored.affordabilityScore >= 0.7) {
      chips.add('Affordable');
    }
    if (scored.proteinFitScore >= 0.7) {
      chips.add('Protein Fit');
    }
    if (scored.calorieFitScore >= 0.7) {
      chips.add('Calorie Fit');
    }
    if (scored.macroBalanceScore >= 0.7) {
      chips.add('Macro Balance');
    }
    if (scored.goalMatchScore >= 0.75) {
      chips.add('Goal Match');
    }
    if (scored.mealTypeScore >= 0.75) {
      chips.add('Meal Type');
    }
    if (scored.overBudgetPenalty > 0) {
      return [const StatusTag.over(label: 'Over Budget')];
    }

    return chips
        .map(
          (label) => StatusTag.ok(label: label),
        )
        .toList();
  }
}

class _BudgetContext extends StatelessWidget {
  final Food food;
  final DashboardData data;

  const _BudgetContext({required this.food, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining =
        (data.dailyBudget - data.spentBudget).clamp(0.0, double.infinity);
    final fitsBudget = food.estimatedPricePhp <= remaining;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget Context',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _BudgetRow(
              label: 'Budget Remaining',
              value: Formatters.formatPhp(remaining),
              color: AppColors.budgetColor,
            ),
            const SizedBox(height: 8),
            _BudgetRow(
              label: 'Estimated Cost',
              value: Formatters.formatPhp(food.estimatedPricePhp),
              color: AppColors.textPrimary,
            ),
            const Divider(height: 20),
            fitsBudget
                ? const StatusTag.ok(label: 'Within Budget')
                : const StatusTag.over(label: 'Over Budget'),
          ],
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BudgetRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _NutritionSummary extends StatelessWidget {
  final Food food;
  const _NutritionSummary({required this.food});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Nutrition Summary',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _NutrientTile(
                  label: 'Calories',
                  value: Formatters.formatCalories(food.calories),
                ),
                _NutrientTile(
                  label: 'Protein',
                  value: Formatters.formatMacro(food.proteinG),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _NutrientTile(
                  label: 'Carbs',
                  value: Formatters.formatMacro(food.carbsG),
                ),
                _NutrientTile(
                  label: 'Fat',
                  value: Formatters.formatMacro(food.fatG),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientTile extends StatelessWidget {
  final String label;
  final String value;

  const _NutrientTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.textPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealOverview extends StatelessWidget {
  final Food food;
  const _MealOverview({required this.food});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = _generateTags(food);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meal Overview',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${food.foodName} from ${food.categoryName}. '
              'A satisfying meal option that fits your nutritional goals.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _generateTags(Food food) {
    final tags = <String>[];
    final name = food.foodName.toLowerCase();
    final category = food.categoryName.toLowerCase();

    if (category.contains('meat') ||
        name.contains('chicken') ||
        name.contains('pork')) {
      tags.add('Filipino');
    }
    if (name.contains('rice') || name.contains('bowl')) {
      tags.add('Rice Bowl');
    }
    if (food.proteinG >= 15) {
      tags.add('High Protein');
    }
    if (category.contains('snack') || name.contains('comfort')) {
      tags.add('Comfort Food');
    }
    if (food.calories >= 300) {
      tags.add('Filling');
    }
    return tags;
  }
}

class _ServingInfo extends StatelessWidget {
  final Food food;
  const _ServingInfo({required this.food});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Serving Info',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.straighten,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Serving Size: ${food.servingLabel ?? 'Standard'}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (food.servingGrams != null) ...[
              Row(
                children: [
                  const Icon(Icons.scale, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Weight: ${food.servingGrams!.toStringAsFixed(0)}g',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Icon(Icons.restaurant,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Ready to Eat',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetImpact extends StatelessWidget {
  final Food food;
  final DashboardData data;

  const _BudgetImpact({required this.food, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budgetPct = data.dailyBudget > 0
        ? (food.estimatedPricePhp / data.dailyBudget * 100).clamp(0.0, 100.0)
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget Impact',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${budgetPct.toStringAsFixed(1)}% of daily budget',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  Formatters.formatPhp(food.estimatedPricePhp),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.budgetColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: budgetPct / 100,
                minHeight: 8,
                backgroundColor: AppColors.budgetColor.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  budgetPct > 80 ? AppColors.error : AppColors.budgetColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelatedAlternatives extends StatelessWidget {
  final ScoredFood scored;
  const _RelatedAlternatives({required this.scored});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alternatives = _generateAlternatives(scored);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Related Alternatives',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: alternatives.isEmpty
                  ? Center(
                      child: Text(
                        'No alternatives available',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: alternatives.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _AlternativeCard(
                        name: alternatives[i].food.foodName,
                        price: alternatives[i].food.estimatedPricePhp,
                        calories: alternatives[i].food.calories,
                        score: alternatives[i].finalScore,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<ScoredFood> _generateAlternatives(ScoredFood current) {
    return [
      ScoredFood(
        food: Food(
          foodId: 'alt1',
          categoryName: current.food.categoryName,
          foodName: 'Grilled Chicken Bowl',
          normalizedName: 'grilled chicken bowl',
          calories: current.food.calories * 0.9,
          proteinG: current.food.proteinG * 1.1,
          carbsG: current.food.carbsG * 0.95,
          fatG: current.food.fatG * 0.85,
          estimatedPricePhp: current.food.estimatedPricePhp * 0.9,
          createdAt: '',
          updatedAt: '',
        ),
        finalScore: current.finalScore * 0.92,
        affordabilityScore: 0.8,
        proteinFitScore: 0.85,
        calorieFitScore: 0.8,
        macroBalanceScore: 0.75,
        goalMatchScore: 0.9,
        mealTypeScore: 0.8,
        overBudgetPenalty: 0,
        reasonText: 'Similar profile with slightly more protein',
      ),
      ScoredFood(
        food: Food(
          foodId: 'alt2',
          categoryName: current.food.categoryName,
          foodName: 'Tofu Rice Bowl',
          normalizedName: 'tofu rice bowl',
          calories: current.food.calories * 0.8,
          proteinG: current.food.proteinG * 0.8,
          carbsG: current.food.carbsG * 1.0,
          fatG: current.food.fatG * 0.7,
          estimatedPricePhp: current.food.estimatedPricePhp * 0.75,
          createdAt: '',
          updatedAt: '',
        ),
        finalScore: current.finalScore * 0.88,
        affordabilityScore: 0.9,
        proteinFitScore: 0.7,
        calorieFitScore: 0.85,
        macroBalanceScore: 0.72,
        goalMatchScore: 0.8,
        mealTypeScore: 0.75,
        overBudgetPenalty: 0,
        reasonText: 'Budget-friendly plant-based alternative',
      ),
    ];
  }
}

class _AlternativeCard extends StatelessWidget {
  final String name;
  final double price;
  final double calories;
  final double score;

  const _AlternativeCard({
    required this.name,
    required this.price,
    required this.calories,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            Formatters.formatPhp(price),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.budgetColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            Formatters.formatCalories(calories),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Food food;
  const _ActionButtons({required this.food});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => context.push(
              '/add-planned-meal',
              extra: {
                'food': food,
                'source': 'recommendation',
              },
            ),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: const Text('Add to Planner'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAccent,
              minimumSize: const Size(0, 48),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push(
              '/meal-log',
              extra: {
                'food': food,
                'source': 'recommendation',
              },
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Log Meal'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
            ),
          ),
        ),
      ],
    );
  }
}
