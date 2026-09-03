import 'package:flutter/material.dart';

import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/features/ai_scanner/ai_scanner_provider.dart';
import 'package:jcg_fitness/features/ai_scanner/screens/confirm_ai_log_screen.dart';
import 'package:jcg_fitness/features/ai_scanner/screens/manual_correction_screen.dart';

class PredictionResultScreen extends StatelessWidget {
  final ScanResult scanResult;
  final String mealType;
  final String clientScanId;

  const PredictionResultScreen({
    super.key,
    required this.scanResult,
    required this.mealType,
    required this.clientScanId,
  });

  List<ScanPrediction> get _sortedPredictions {
    final sorted = List<ScanPrediction>.from(scanResult.predictions);
    sorted.sort((a, b) => b.confidence.compareTo(a.confidence));
    return sorted;
  }

  String? get _primaryComponentId => scanResult.components.isEmpty
      ? null
      : scanResult.components.first.componentId;

  String get _primaryComponentRole => scanResult.components.isEmpty
      ? 'ulam'
      : scanResult.components.first.roleCode;

  List<ScanComponent> _componentsForPrediction(ScanPrediction prediction) {
    if (scanResult.components.isEmpty) return const [];
    final primary = scanResult.components.first.copyWith(
      foodId: prediction.foodId,
      foodName: prediction.foodName,
      confidence: prediction.confidence,
      calories: prediction.calories,
      proteinG: prediction.proteinG,
      carbsG: prediction.carbsG,
      fatG: prediction.fatG,
      estimatedCostPhp: prediction.estimatedCostPhp,
      referenceGrams: prediction.servingGrams,
    );
    return [primary, ...scanResult.components.skip(1)];
  }

  @override
  Widget build(BuildContext context) {
    final predictions = _sortedPredictions;

    if (predictions.isEmpty) {
      return _buildEmptyResult(context);
    }

    final topConfidence = predictions.first.confidence;

    if (topConfidence >= 0.95) {
      return _buildHighConfidence(context, predictions);
    } else if (topConfidence >= 0.60) {
      return _buildMediumConfidence(context, predictions);
    } else {
      return _buildLowConfidence(context, predictions);
    }
  }

  Widget _buildEmptyResult(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prediction Results')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off,
                  size: 64, color: Theme.of(context).disabledColor),
              const SizedBox(height: 16),
              Text(
                'No predictions returned',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManualCorrectionScreen(
                        mealType: mealType,
                        clientScanId: clientScanId,
                        scanId: scanResult.scanId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Enter Food Manually'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighConfidence(
      BuildContext context, List<ScanPrediction> predictions) {
    final prediction = predictions.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Prediction Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopMatchHeader(context, prediction),
            const SizedBox(height: 8),
            _buildCompositionCard(context),
            const SizedBox(height: 8),
            _buildNutritionCard(context, prediction),
            if (predictions.length > 1) ...[
              const SizedBox(height: 24),
              _buildMultipleItemsBanner(context, predictions.length),
            ],
            const SizedBox(height: 24),
            _buildReviewConfirmButton(context, prediction),
            const SizedBox(height: 12),
            _buildScanAnotherButton(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMatchHeader(BuildContext context, ScanPrediction prediction) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Match',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              prediction.foodName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            prediction.confidence >= 0.95
                ? StatusTag.ok(
                    label:
                        '${(prediction.confidence * 100).toStringAsFixed(0)}% match')
                : prediction.confidence >= 0.60
                    ? StatusTag.neutral(
                        label:
                            '${(prediction.confidence * 100).toStringAsFixed(0)}% match')
                    : StatusTag.over(
                        label:
                            '${(prediction.confidence * 100).toStringAsFixed(0)}% match'),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleItemsBanner(BuildContext context, int count) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Other possible matches are available',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _CandidateSelectionScreen(
                      predictions: _sortedPredictions,
                      mealType: mealType,
                      clientScanId: clientScanId,
                      scanId: scanResult.scanId,
                      componentId: _primaryComponentId,
                      componentRole: _primaryComponentRole,
                      components: scanResult.components,
                    ),
                  ),
                );
              },
              child: Text(
                'View all matches ($count)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewConfirmButton(
      BuildContext context, ScanPrediction prediction) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConfirmAiLogScreen(
                foodName: prediction.foodName,
                calories: prediction.calories ?? 0,
                proteinG: prediction.proteinG ?? 0,
                carbsG: prediction.carbsG ?? 0,
                fatG: prediction.fatG ?? 0,
                estimatedCostPhp: prediction.estimatedCostPhp ?? 0,
                mealType: mealType,
                scanId: scanResult.scanId,
                clientScanId: clientScanId,
                foodId: prediction.foodId,
                predictedConfidence: prediction.confidence,
                servingGrams: prediction.servingGrams,
                componentId: _primaryComponentId,
                componentRole: _primaryComponentRole,
                components: _componentsForPrediction(prediction),
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnAccent,
        ),
        child: const Text('Review & Confirm'),
      ),
    );
  }

  Widget _buildScanAnotherButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          Navigator.pop(context);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
        ),
        child: const Text('Scan Another'),
      ),
    );
  }

  Widget _buildMediumConfidence(
      BuildContext context, List<ScanPrediction> predictions) {
    return _CandidateSelectionScreen(
      predictions: predictions,
      mealType: mealType,
      clientScanId: clientScanId,
      scanId: scanResult.scanId,
      componentId: _primaryComponentId,
      componentRole: _primaryComponentRole,
      components: scanResult.components,
      showAppBar: true,
    );
  }

  Widget _buildLowConfidence(
      BuildContext context, List<ScanPrediction> predictions) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Prediction Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Low confidence scan. Please review the results below.',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildTopMatchHeader(context, predictions.first),
            const SizedBox(height: 8),
            _buildCompositionCard(context),
            const SizedBox(height: 8),
            _buildNutritionCard(context, predictions.first),
            if (predictions.length > 1) ...[
              const SizedBox(height: 24),
              _buildMultipleItemsBanner(context, predictions.length),
            ],
            const SizedBox(height: 24),
            _buildReviewConfirmButton(context, predictions.first),
            const SizedBox(height: 12),
            _buildScanAnotherButton(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCompositionCard(BuildContext context) {
    if (scanResult.components.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What is on the plate?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review each component separately so rice and sides are not counted as part of the ulam.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            for (final component in scanResult.components)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      component.roleCode == 'rice'
                          ? Icons.rice_bowl_outlined
                          : Icons.restaurant_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_componentRoleLabel(component.roleCode)}: ${component.foodName}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${(component.confidence * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              'Portion weight is required for a more accurate total.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _componentRoleLabel(String roleCode) {
    switch (roleCode) {
      case 'ulam':
        return 'Ulam';
      case 'rice':
        return 'Rice';
      case 'vegetable':
        return 'Vegetable';
      case 'soup':
        return 'Soup';
      case 'side':
        return 'Side';
      case 'drink':
        return 'Drink';
      case 'dessert':
        return 'Dessert';
      default:
        return 'Item';
    }
  }

  Widget _buildNutritionCard(BuildContext context, ScanPrediction prediction) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimated Nutrition',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _NutrientChip(
                  value: prediction.calories != null
                      ? Formatters.formatCalories(prediction.calories!)
                      : '--',
                  label: 'Calories',
                ),
                const SizedBox(width: 16),
                _NutrientChip(
                  value: prediction.proteinG != null
                      ? Formatters.formatMacro(prediction.proteinG!)
                      : '--',
                  label: 'Protein',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _NutrientChip(
                  value: prediction.carbsG != null
                      ? Formatters.formatMacro(prediction.carbsG!)
                      : '--',
                  label: 'Carbs',
                ),
                const SizedBox(width: 16),
                _NutrientChip(
                  value: prediction.fatG != null
                      ? Formatters.formatMacro(prediction.fatG!)
                      : '--',
                  label: 'Fat',
                ),
              ],
            ),
            if (prediction.estimatedCostPhp != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.monetization_on,
                      size: 20, color: AppColors.budgetColor),
                  const SizedBox(width: 8),
                  Text(
                    'Est. Cost: ${Formatters.formatPhp(prediction.estimatedCostPhp!)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.budgetColor,
                    ),
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

class _CandidateSelectionScreen extends StatefulWidget {
  final List<ScanPrediction> predictions;
  final String mealType;
  final String clientScanId;
  final String scanId;
  final String? componentId;
  final String componentRole;
  final List<ScanComponent> components;
  final bool showAppBar;

  const _CandidateSelectionScreen({
    required this.predictions,
    required this.mealType,
    required this.clientScanId,
    required this.scanId,
    this.componentId,
    this.componentRole = 'ulam',
    this.components = const [],
    this.showAppBar = false,
  });

  @override
  State<_CandidateSelectionScreen> createState() =>
      _CandidateSelectionScreenState();
}

class _CandidateSelectionScreenState extends State<_CandidateSelectionScreen> {
  int? _selectedIndex;

  List<ScanPrediction> get _sortedPredictions {
    final sorted = List<ScanPrediction>.from(widget.predictions);
    sorted.sort((a, b) => b.confidence.compareTo(a.confidence));
    return sorted;
  }

  void _onContinue() {
    if (_selectedIndex == null) return;

    final isNoneMatch = _selectedIndex == widget.predictions.length;

    if (isNoneMatch) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManualCorrectionScreen(
            mealType: widget.mealType,
            clientScanId: widget.clientScanId,
            scanId: widget.scanId,
          ),
        ),
      );
      return;
    }

    final prediction = _sortedPredictions[_selectedIndex!];
    final components = widget.components.isEmpty
        ? const <ScanComponent>[]
        : [
            widget.components.first.copyWith(
              foodId: prediction.foodId,
              foodName: prediction.foodName,
              confidence: prediction.confidence,
              calories: prediction.calories,
              proteinG: prediction.proteinG,
              carbsG: prediction.carbsG,
              fatG: prediction.fatG,
              estimatedCostPhp: prediction.estimatedCostPhp,
              referenceGrams: prediction.servingGrams,
            ),
            ...widget.components.skip(1),
          ];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmAiLogScreen(
          foodName: prediction.foodName,
          calories: prediction.calories ?? 0,
          proteinG: prediction.proteinG ?? 0,
          carbsG: prediction.carbsG ?? 0,
          fatG: prediction.fatG ?? 0,
          estimatedCostPhp: prediction.estimatedCostPhp ?? 0,
          mealType: widget.mealType,
          scanId: widget.scanId,
          clientScanId: widget.clientScanId,
          foodId: prediction.foodId,
          predictedConfidence: prediction.confidence,
          servingGrams: prediction.servingGrams,
          componentId: widget.componentId,
          componentRole: widget.componentRole,
          components: components,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = _sortedPredictions;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Prediction Results'))
          : null,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.showAppBar) ...[
              const SizedBox(height: 16),
            ],
            Text(
              'Select the best match',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the option that best describes your food',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: sorted.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  if (i == sorted.length) {
                    return _buildNoneMatchOption(theme);
                  }
                  return _buildCandidateOption(theme, sorted[i], i);
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedIndex != null ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnAccent,
                  disabledBackgroundColor: AppColors.divider,
                ),
                child: const Text('Continue'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateOption(
      ThemeData theme, ScanPrediction prediction, int index) {
    final isSelected = _selectedIndex == index;

    return Card(
      color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Radio<int>(
                value: index,
                groupValue: _selectedIndex,
                onChanged: (value) {
                  setState(() {
                    _selectedIndex = value;
                  });
                },
                activeColor: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.foodName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (prediction.calories != null)
                          Text(
                            '${Formatters.formatCalories(prediction.calories!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (prediction.calories != null)
                          Text(
                            ' \u2022 ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        prediction.confidence >= 0.95
                            ? StatusTag.ok(
                                label:
                                    '${(prediction.confidence * 100).toStringAsFixed(0)}% match')
                            : prediction.confidence >= 0.60
                                ? StatusTag.neutral(
                                    label:
                                        '${(prediction.confidence * 100).toStringAsFixed(0)}% match')
                                : StatusTag.over(
                                    label:
                                        '${(prediction.confidence * 100).toStringAsFixed(0)}% match'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoneMatchOption(ThemeData theme) {
    final isSelected = _selectedIndex == widget.predictions.length;

    return Card(
      color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedIndex = widget.predictions.length;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Radio<int>(
                value: widget.predictions.length,
                groupValue: _selectedIndex,
                onChanged: (value) {
                  setState(() {
                    _selectedIndex = value;
                  });
                },
                activeColor: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'None of these match',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutrientChip extends StatelessWidget {
  final String value;
  final String label;

  const _NutrientChip({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
