import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/offline_banner.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/recommendations/recommendation_engine.dart';
import 'package:jcg_fitness/features/recommendations/recommendation_provider.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  String? _selectedGoal;
  String? _selectedMealType;
  String? _selectedBudget;
  double? _minimumPricePhp;
  double? _maximumPricePhp;
  bool _highProteinOnly = false;
  bool _lowCostOnly = false;
  Timer? _recordDebounce;

  static const _goalOptions = <String, String>{
    'cutting': 'Cutting',
    'bulking': 'Bulking',
    'maintenance': 'Maintenance',
    'lean': 'Lean Gain',
    'gain_weight': 'Weight Gain',
  };

  static const _mealTypeOptions = <String, String>{
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
  };

  static const _budgetOptions = <String, String>{
    'under_50': 'Under ₱50',
    'under_100': 'Under ₱100',
    'under_150': 'Under ₱150',
    'custom': 'Custom Range',
    'any': 'Any Budget',
  };

  RecommendationRequest get _request => RecommendationRequest(
        goalCode: _selectedGoal,
        mealTypeCode: _selectedMealType,
        minimumPricePhp: _minimumPricePhp,
        maximumPricePhp: _maximumPricePhp,
        highProteinOnly: _highProteinOnly,
        lowCostOnly: _lowCostOnly,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordCurrent());
  }

  Future<void> _recordCurrent({bool refresh = false}) async {
    final request = _request;
    final future = refresh
        ? ref.refresh(recommendationProvider(request).future)
        : ref.read(recommendationProvider(request).future);
    try {
      final results = await future;
      await ref.read(recommendationRecorderProvider).record(request, results);
    } catch (_) {
      // The screen already renders provider errors and remains retryable.
    }
  }

  void _changeFilter(VoidCallback update) {
    setState(update);
    _recordDebounce?.cancel();
    _recordDebounce = Timer(
      const Duration(milliseconds: 350),
      _recordCurrent,
    );
  }

  @override
  void dispose() {
    _recordDebounce?.cancel();
    super.dispose();
  }

  void _setBudgetPreset(String? value) {
    if (value == 'custom') {
      Future<void>.microtask(_showBudgetRangeSheet);
      return;
    }
    _changeFilter(() {
      _selectedBudget = value;
      _minimumPricePhp = null;
      _maximumPricePhp = switch (value) {
        'under_50' => 50,
        'under_100' => 100,
        'under_150' => 150,
        _ => null,
      };
    });
  }

  Future<void> _showBudgetRangeSheet() async {
    final minimumController = TextEditingController(
      text: _minimumPricePhp?.toStringAsFixed(0) ?? '',
    );
    final maximumController = TextEditingController(
      text: _maximumPricePhp?.toStringAsFixed(0) ?? '',
    );
    final range = await showModalBottomSheet<(double?, double?)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Custom budget range',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minimumController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minimum PHP',
                      prefixText: '₱',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: maximumController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Maximum PHP',
                      prefixText: '₱',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final minimum = double.tryParse(minimumController.text);
                  final maximum = double.tryParse(maximumController.text);
                  if ((minimum != null && minimum < 0) ||
                      (maximum != null && maximum < 0) ||
                      (minimum != null &&
                          maximum != null &&
                          minimum > maximum)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid minimum and maximum.'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, (minimum, maximum));
                },
                child: const Text('Apply range'),
              ),
            ),
          ],
        ),
      ),
    );
    minimumController.dispose();
    maximumController.dispose();
    if (range == null || !mounted) return;
    _changeFilter(() {
      _selectedBudget = 'custom';
      _minimumPricePhp = range.$1;
      _maximumPricePhp = range.$2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = _request;
    final recsAsync = ref.watch(recommendationProvider(request));
    final dashAsync = ref.watch(dashboardDataProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _recordCurrent(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _recordCurrent(refresh: true),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildSubtitle(theme),
                  ),
                  SliverToBoxAdapter(
                    child: _buildFilterChips(theme),
                  ),
                  if (!isOnline)
                    const SliverToBoxAdapter(
                      child: _OfflineBanner(),
                    ),
                  SliverToBoxAdapter(
                    child: dashAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (data) => _SummarySection(data: data),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _CachedInfoBanner(),
                  ),
                  recsAsync.when(
                    loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => SliverFillRemaining(
                      child: _ErrorState(
                        onRetry: () => _recordCurrent(refresh: true),
                      ),
                    ),
                    data: (results) {
                      if (results.isEmpty) {
                        return const SliverFillRemaining(
                          child: _EmptyState(),
                        );
                      }
                      return SliverPadding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 8,
                          bottom: 88,
                        ),
                        sliver: SliverList.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _FoodCard(
                            index: i,
                            scored: results[i],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        'Affordable meal ideas matched to your goal and budget.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _FilterDropdown(
            label: 'Goal',
            value: _selectedGoal,
            options: _goalOptions,
            onChanged: (v) => _changeFilter(() => _selectedGoal = v),
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            label: 'Meal Type',
            value: _selectedMealType,
            options: _mealTypeOptions,
            onChanged: (v) => _changeFilter(() => _selectedMealType = v),
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            label: 'Budget',
            value: _selectedBudget,
            options: _budgetOptions,
            onChanged: _setBudgetPreset,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('High Protein'),
            selected: _highProteinOnly,
            onSelected: (v) => _changeFilter(() => _highProteinOnly = v),
            selectedColor: AppColors.primary.withValues(alpha: 0.1),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              fontSize: 13,
              color: _highProteinOnly
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            side: BorderSide(
              color: _highProteinOnly ? AppColors.primary : AppColors.divider,
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Low Cost'),
            selected: _lowCostOnly,
            onSelected: (v) => _changeFilter(() => _lowCostOnly = v),
            selectedColor: AppColors.primary.withValues(alpha: 0.1),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              fontSize: 13,
              color: _lowCostOnly ? AppColors.primary : AppColors.textSecondary,
            ),
            side: BorderSide(
              color: _lowCostOnly ? AppColors.primary : AppColors.divider,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final displayText = hasValue ? options[value] ?? label : label;

    return GestureDetector(
      onTap: () => _showOptions(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hasValue
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasValue ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                color: hasValue ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: hasValue ? AppColors.primary : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Filter by $label',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (value != null)
                    TextButton(
                      onPressed: () {
                        onChanged(null);
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            ...options.entries.map(
              (entry) => ListTile(
                title: Text(entry.value),
                trailing: value == entry.key
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  onChanged(entry.key);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final DashboardData data;
  const _SummarySection({required this.data});

  @override
  Widget build(BuildContext context) {
    final remainingBudget =
        (data.dailyBudget - data.spentBudget).clamp(0.0, double.infinity);
    final remainingCalories = (data.targetCalories - data.consumedCalories)
        .clamp(0, data.targetCalories);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              icon: Icons.monetization_on,
              title: 'Budget Remaining',
              value:
                  '${Formatters.formatPhp(remainingBudget)} of ${Formatters.formatPhp(data.dailyBudget)}/day',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              icon: Icons.local_fire_department,
              title: 'Calories Remaining',
              value:
                  '$remainingCalories kcal of ${data.targetCalories} kcal/day',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              icon: Icons.schedule,
              title: 'Meal Context',
              value: _mealContextLabel(),
            ),
          ),
        ],
      ),
    );
  }

  String _mealContextLabel() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Breakfast / Morning';
    if (hour < 15) return 'Lunch / Midday meal';
    if (hour < 18) return 'Snack / Afternoon';
    return 'Dinner / Evening meal';
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CachedInfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
              'Showing cached recommendations. Last updated: just now',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are offline. Showing cached results.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodCard extends ConsumerWidget {
  final int index;
  final ScoredFood scored;

  const _FoodCard({required this.index, required this.scored});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final food = scored.food;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/recommendation-detail', extra: scored),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _FoodImagePlaceholder(foodName: food.foodName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            food.foodName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.formatPhp(food.estimatedPricePhp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.budgetColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _NutritionPill(
                          value: Formatters.formatCalories(food.calories),
                        ),
                        const SizedBox(width: 6),
                        _NutritionPill(
                          value: '${food.proteinG.toStringAsFixed(0)}P',
                        ),
                        const SizedBox(width: 6),
                        _NutritionPill(
                          value: '${food.carbsG.toStringAsFixed(0)}C',
                        ),
                        const SizedBox(width: 6),
                        _NutritionPill(
                          value: '${food.fatG.toStringAsFixed(0)}F',
                        ),
                        if (scored.overBudgetPenalty > 0) ...[
                          const SizedBox(width: 6),
                          const StatusTag.over(label: 'Over Budget'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _buildReasonChips(scored),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
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
        .take(3)
        .map(
          (label) => StatusTag.ok(label: label),
        )
        .toList();
  }
}

class _FoodImagePlaceholder extends StatelessWidget {
  final String foodName;
  const _FoodImagePlaceholder({required this.foodName});

  @override
  Widget build(BuildContext context) {
    final initial = foodName.isNotEmpty ? foodName[0].toUpperCase() : '?';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _NutritionPill extends StatelessWidget {
  final String value;

  const _NutritionPill({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to generate recommendations',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No recommendations available',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Log some meals first to help us find\nthe best foods for your remaining needs.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
