import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/core/database/ai_scan_feedback_repository.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/errors/result.dart';
import 'package:jcg_fitness/core/network/api_client.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/core/database/sync_queue_repository.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/ai_scanner/ai_scanner_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';

class ConfirmAiLogScreen extends ConsumerStatefulWidget {
  final String foodName;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double estimatedCostPhp;
  final String mealType;
  final String scanId;
  final String clientScanId;
  final String? foodId;
  final double? predictedConfidence;
  final double? servingGrams;
  final String? componentId;
  final String componentRole;
  final List<ScanComponent> components;
  final bool isManualCorrection;
  final String? correctionReason;

  const ConfirmAiLogScreen({
    super.key,
    required this.foodName,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.estimatedCostPhp,
    required this.mealType,
    required this.scanId,
    required this.clientScanId,
    this.foodId,
    this.predictedConfidence,
    this.servingGrams,
    this.componentId,
    this.componentRole = 'ulam',
    this.components = const [],
    this.isManualCorrection = false,
    this.correctionReason,
  });

  @override
  ConsumerState<ConfirmAiLogScreen> createState() => _ConfirmAiLogScreenState();
}

class _ConfirmAiLogScreenState extends ConsumerState<ConfirmAiLogScreen> {
  double _quantity = 1.0;
  bool _isSaving = false;
  String? _errorMessage;
  late final TextEditingController _portionGramsController;
  late final Map<String, TextEditingController> _componentGramsControllers;

  @override
  void initState() {
    super.initState();
    _portionGramsController = TextEditingController(
      text: widget.servingGrams == null
          ? ''
          : widget.servingGrams!.toStringAsFixed(0),
    );
    _componentGramsControllers = {
      for (final component in widget.components)
        component.componentId: TextEditingController(
          text: component.referenceGrams == null
              ? ''
              : component.referenceGrams!.toStringAsFixed(0),
        ),
    };
  }

  @override
  void dispose() {
    _portionGramsController.dispose();
    for (final controller in _componentGramsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasMultipleComponents => widget.components.length > 1;

  bool get _canUseWeight =>
      widget.servingGrams != null && widget.servingGrams! > 0;

  double? get _enteredGrams {
    final value = double.tryParse(_portionGramsController.text.trim());
    return value != null && value > 0 ? value : null;
  }

  double get _portionMultiplier {
    final grams = _enteredGrams;
    if (_canUseWeight && grams != null) {
      return grams / widget.servingGrams!;
    }
    return _quantity;
  }

  double get _adjustedCalories => widget.calories * _portionMultiplier;
  double get _adjustedProtein => widget.proteinG * _portionMultiplier;
  double get _adjustedCarbs => widget.carbsG * _portionMultiplier;
  double get _adjustedFat => widget.fatG * _portionMultiplier;
  double get _adjustedCost => widget.estimatedCostPhp * _portionMultiplier;

  double? _enteredComponentGrams(ScanComponent component) {
    final value = double.tryParse(
      _componentGramsControllers[component.componentId]?.text.trim() ?? '',
    );
    return value != null && value > 0 ? value : null;
  }

  double _componentMultiplier(ScanComponent component) {
    final reference = component.referenceGrams;
    final grams = _enteredComponentGrams(component);
    if (reference != null && reference > 0 && grams != null) {
      return grams / reference;
    }
    return 1.0;
  }

  double _componentCalories(ScanComponent component) =>
      component.calories ??
      (component.componentId == widget.componentId ? widget.calories : 0);

  double _componentProtein(ScanComponent component) =>
      component.proteinG ??
      (component.componentId == widget.componentId ? widget.proteinG : 0);

  double _componentCarbs(ScanComponent component) =>
      component.carbsG ??
      (component.componentId == widget.componentId ? widget.carbsG : 0);

  double _componentFat(ScanComponent component) =>
      component.fatG ??
      (component.componentId == widget.componentId ? widget.fatG : 0);

  double _componentCost(ScanComponent component) =>
      component.estimatedCostPhp ??
      (component.componentId == widget.componentId
          ? widget.estimatedCostPhp
          : 0);

  double get _componentCaloriesTotal => widget.components.fold(
        0,
        (total, component) =>
            total +
            _componentCalories(component) * _componentMultiplier(component),
      );

  double get _componentProteinTotal => widget.components.fold(
        0,
        (total, component) =>
            total +
            _componentProtein(component) * _componentMultiplier(component),
      );

  double get _componentCarbsTotal => widget.components.fold(
        0,
        (total, component) =>
            total +
            _componentCarbs(component) * _componentMultiplier(component),
      );

  double get _componentFatTotal => widget.components.fold(
        0,
        (total, component) =>
            total + _componentFat(component) * _componentMultiplier(component),
      );

  double get _displayCalories =>
      _hasMultipleComponents ? _componentCaloriesTotal : _adjustedCalories;
  double get _displayProtein =>
      _hasMultipleComponents ? _componentProteinTotal : _adjustedProtein;
  double get _displayCarbs =>
      _hasMultipleComponents ? _componentCarbsTotal : _adjustedCarbs;
  double get _displayFat =>
      _hasMultipleComponents ? _componentFatTotal : _adjustedFat;
  Future<void> _saveLog() async {
    setState(() => _isSaving = true);

    try {
      final missingComponentWeight = widget.components.any(
        (component) =>
            component.referenceGrams != null &&
            _enteredComponentGrams(component) == null,
      );
      if ((!_hasMultipleComponents && _canUseWeight && _enteredGrams == null) ||
          (_hasMultipleComponents && missingComponentWeight)) {
        setState(() {
          _errorMessage = _hasMultipleComponents
              ? 'Enter a valid weight for every detected component.'
              : 'Enter a valid portion weight in grams.';
          _isSaving = false;
        });
        return;
      }
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in')),
          );
        }
        return;
      }
      final localUserId = await LocalUserIdentity.resolve(
        DatabaseProvider(),
        user.id,
      );

      final now = DateTime.now().toUtc().toIso8601String();
      final helper = LocalTransactionHelper(DatabaseProvider());
      late final String mealLogId;
      if (_hasMultipleComponents) {
        String? primaryMealLogId;
        for (var index = 0; index < widget.components.length; index++) {
          final component = widget.components[index];
          final componentMealLogId = UuidHelper.generateUuid();
          primaryMealLogId ??= componentMealLogId;
          final componentGrams = _enteredComponentGrams(component);
          final multiplier = _componentMultiplier(component);
          await helper.createMealLog({
            'meal_log_id': componentMealLogId,
            'user_id': localUserId,
            'food_id': component.foodId,
            'meal_type_code': widget.mealType,
            'log_source_code': 'ai_scanner',
            'food_name_snapshot': component.foodName,
            'serving_grams_snapshot':
                componentGrams ?? component.referenceGrams ?? 0,
            'quantity': 1.0,
            'calories_snapshot': _componentCalories(component) * multiplier,
            'protein_g_snapshot': _componentProtein(component) * multiplier,
            'carbs_g_snapshot': _componentCarbs(component) * multiplier,
            'fat_g_snapshot': _componentFat(component) * multiplier,
            'cost_php_snapshot': _componentCost(component) * multiplier,
            'logged_at': now,
            'is_deleted': 0,
          });
          await _confirmComponent(
            component,
            index,
            localUserId,
            now,
            componentGrams,
            multiplier,
          );
        }
        mealLogId = primaryMealLogId!;
        ref.read(syncProvider.notifier).startSync();
      } else {
        final mealLogIdValue = UuidHelper.generateUuid();
        await helper.createMealLog({
          'meal_log_id': mealLogIdValue,
          'user_id': localUserId,
          'food_id': widget.foodId,
          'meal_type_code': widget.mealType,
          'log_source_code': 'ai_scanner',
          'food_name_snapshot': widget.foodName,
          'serving_grams_snapshot': _enteredGrams ?? widget.servingGrams ?? 0,
          'quantity': _canUseWeight ? 1.0 : _quantity,
          'calories_snapshot': _adjustedCalories,
          'protein_g_snapshot': _adjustedProtein,
          'carbs_g_snapshot': _adjustedCarbs,
          'fat_g_snapshot': _adjustedFat,
          'cost_php_snapshot': _adjustedCost,
          'logged_at': now,
          'is_deleted': 0,
        });
        mealLogId = mealLogIdValue;
        if (widget.componentId != null) {
          final component = widget.components.isEmpty
              ? ScanComponent(
                  componentId: widget.componentId!,
                  roleCode: widget.componentRole,
                  foodId: widget.foodId,
                  foodName: widget.foodName,
                  confidence: widget.predictedConfidence ?? 0,
                  referenceGrams: widget.servingGrams,
                )
              : widget.components.first;
          await _confirmComponent(
            component,
            0,
            localUserId,
            now,
            _enteredGrams,
            _portionMultiplier,
          );
          ref.read(syncProvider.notifier).startSync();
        }
      }

      final feedbackRepo = ref.read(aiScanFeedbackRepositoryProvider);
      final feedbackData = AiScanFeedback(
        feedbackId: UuidHelper.generateUuid(),
        scanId: widget.scanId,
        clientScanId: widget.clientScanId,
        selectedFoodId: widget.foodId,
        wasHelpful: !widget.isManualCorrection,
        feedbackText: widget.correctionReason,
        mealLogId: mealLogId,
        confirmedFoodId: widget.foodId,
        quantity: _hasMultipleComponents || _canUseWeight ? 1.0 : _quantity,
        mealTypeCode: widget.mealType,
        correctionReason: widget.correctionReason,
        feedbackType:
            widget.isManualCorrection ? 'manual_correction' : 'accepted',
        syncStatus: 'pending',
        createdAt: now,
        confirmedAt: now,
      );
      await feedbackRepo.upsert(feedbackData);
      await _submitFeedback(feedbackRepo, feedbackData);
      ref.invalidate(dashboardDataProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal logged successfully')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmComponent(
    ScanComponent component,
    int index,
    String localUserId,
    String now,
    double? componentGrams,
    double multiplier,
  ) async {
    final payload = <String, dynamic>{
      'component_id': component.componentId,
      'scan_id': widget.scanId,
      'component_order': index + 1,
      'role_code': component.roleCode,
      'food_id': component.foodId,
      'predicted_food_name': component.foodName,
      'confidence': component.confidence,
      'alternative_names': jsonEncode(component.alternatives),
      'reference_grams': component.referenceGrams,
      'grams': componentGrams ?? component.referenceGrams,
      'portion_method':
          componentGrams == null ? 'serving_preset' : 'user_input',
      'portion_confidence': componentGrams == null ? null : 1.0,
      'calories': _componentCalories(component) * multiplier,
      'protein_g': _componentProtein(component) * multiplier,
      'carbs_g': _componentCarbs(component) * multiplier,
      'fat_g': _componentFat(component) * multiplier,
      'estimated_cost_php': _componentCost(component) * multiplier,
      'is_confirmed': 1,
      'sync_status': 'pending',
      'created_at': now,
      'updated_at': now,
    };
    final db = await DatabaseProvider().database;
    await db.update(
      'ai_scan_components',
      payload,
      where: 'component_id = ?',
      whereArgs: [component.componentId],
    );
    await db.insert('sync_queue', {
      'sync_queue_id': UuidHelper.generateUuid(),
      'user_id': localUserId,
      'operation_id': UuidHelper.generateUuid(),
      'entity_type_code': 'ai_scan_component',
      'entity_id': component.componentId,
      'operation_code': 'update',
      'payload_json': jsonEncode(payload),
      'client_sequence': DateTime.now().millisecondsSinceEpoch,
      'attempt_count': 0,
      'sync_status': 'pending',
      'created_at': now,
    });
  }

  Future<void> _submitFeedback(
    AiScanFeedbackRepository feedbackRepo,
    AiScanFeedback feedback,
  ) async {
    final apiClient = ApiClient(AppConfig.fastApiBaseUrl);
    try {
      final result = await apiClient.post(
        '/ai/scan-feedback',
        body: {
          'feedback_id': feedback.feedbackId,
          'client_scan_id': widget.clientScanId,
          'selected_food_id': widget.foodId,
          'was_helpful': !widget.isManualCorrection,
          'feedback_text': widget.correctionReason,
        },
      );
      if (result case Success()) {
        await feedbackRepo.upsert(AiScanFeedback(
          feedbackId: feedback.feedbackId,
          scanId: feedback.scanId,
          clientScanId: feedback.clientScanId,
          selectedFoodId: feedback.selectedFoodId,
          wasHelpful: feedback.wasHelpful,
          feedbackText: feedback.feedbackText,
          mealLogId: feedback.mealLogId,
          confirmedFoodId: feedback.confirmedFoodId,
          quantity: feedback.quantity,
          mealTypeCode: feedback.mealTypeCode,
          correctionReason: feedback.correctionReason,
          feedbackType: feedback.feedbackType,
          syncStatus: 'synced',
          createdAt: feedback.createdAt,
          confirmedAt: feedback.confirmedAt,
        ));
      } else {
        await _queueFeedback(feedback);
      }
    } catch (_) {
      await _queueFeedback(feedback);
    } finally {
      apiClient.dispose();
    }
  }

  Future<void> _queueFeedback(AiScanFeedback feedback) async {
    final userId = ref.read(authSessionProvider)?.user.id;
    if (userId == null) return;
    final repo = SyncQueueRepository(DatabaseProvider());
    final payload = {
      'feedback_id': feedback.feedbackId,
      'client_scan_id': feedback.clientScanId,
      'selected_food_id': feedback.selectedFoodId,
      'was_helpful': feedback.wasHelpful,
      'feedback_text': feedback.feedbackText,
      'created_at': feedback.createdAt,
    };
    final existing = await repo.readByOperationId(feedback.feedbackId);
    if (existing != null) {
      if (existing.syncStatus != 'pending') {
        await repo.update(existing.copyWith(
          payloadJson: jsonEncode(payload),
          syncStatus: 'pending',
        ));
      }
      ref.read(syncProvider.notifier).startSync();
      return;
    }
    await repo.insert(SyncQueueEntry(
      syncQueueId: UuidHelper.generateUuid(),
      userId: userId,
      operationId: feedback.feedbackId,
      entityTypeCode: 'ai_scan_feedback',
      entityId: feedback.feedbackId,
      operationCode: 'create',
      payloadJson: jsonEncode(payload),
      clientSequence: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    ));
    ref.read(syncProvider.notifier).startSync();
  }

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);
    try {
      await _saveLog();
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Something went wrong. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Log')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFoodCard(theme),
          const SizedBox(height: 16),
          _buildPortionCard(theme),
          const SizedBox(height: 16),
          _buildNutritionGrid(theme),
          const SizedBox(height: 16),
          _buildMealInfoCard(theme),
          const SizedBox(height: 24),
          _buildAddToLogButton(theme),
          const SizedBox(height: 8),
          _buildEditDetailsButton(theme),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildErrorRetry(theme),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFoodCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.restaurant,
                color: AppColors.textPrimary,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasMultipleComponents
                        ? 'Meal with ${widget.components.length} components'
                        : widget.foodName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hasMultipleComponents
                        ? 'Review each component below'
                        : _canUseWeight && _enteredGrams != null
                            ? '${_enteredGrams!.toStringAsFixed(0)} g portion'
                            : '${_quantity.toStringAsFixed(1)} serving',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortionCard(ThemeData theme) {
    if (_hasMultipleComponents) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Portions for this meal',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter the edible weight for each detected item. Items without a catalog weight will use one serving and remain approximate.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (final component in widget.components)
                _buildComponentPortionField(theme, component),
            ],
          ),
        ),
      );
    }

    if (!_canUseWeight) {
      return Card(
        color: AppColors.surfaceAlt,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'A catalog serving weight is not available for this result. You can still log one serving, or edit the food and choose a catalog item with a measured serving size.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final reference = widget.servingGrams!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Portion weight',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter the edible portion for a more accurate nutrition total. Catalog reference: ${reference.toStringAsFixed(0)} g per serving.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portionGramsController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'How many grams?',
                suffixText: 'g',
                prefixIcon: Icon(Icons.scale_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final grams in <double>[100, 150, 200])
                  OutlinedButton(
                    onPressed: () {
                      _portionGramsController.text = grams.toStringAsFixed(0);
                      setState(() {});
                    },
                    child: Text('${grams.toStringAsFixed(0)} g'),
                  ),
                OutlinedButton(
                  onPressed: () {
                    _portionGramsController.text = reference.toStringAsFixed(0);
                    setState(() {});
                  },
                  child: const Text('1 serving'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentPortionField(
    ThemeData theme,
    ScanComponent component,
  ) {
    final controller = _componentGramsControllers[component.componentId];
    final reference = component.referenceGrams;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_componentRoleLabel(component.roleCode)}: ${component.foodName}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (reference == null || controller == null)
            Text(
              'Serving weight unavailable; one catalog serving will be used.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Portion weight',
                suffixText: 'g',
                prefixIcon: Icon(Icons.scale_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final grams in <double>[100, 150, 200, reference])
                  OutlinedButton(
                    onPressed: () {
                      controller.text = grams.toStringAsFixed(0);
                      setState(() {});
                    },
                    child: Text(
                      grams == reference
                          ? '1 serving'
                          : '${grams.toStringAsFixed(0)} g',
                    ),
                  ),
              ],
            ),
          ],
        ],
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

  Widget _buildNutritionGrid(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutrition',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildNutrientCell(
                  theme,
                  'Calories',
                  Formatters.formatCalories(_displayCalories),
                ),
                const SizedBox(width: 12),
                _buildNutrientCell(
                  theme,
                  'Protein',
                  Formatters.formatMacro(_displayProtein),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildNutrientCell(
                  theme,
                  'Carbs',
                  Formatters.formatMacro(_displayCarbs),
                ),
                const SizedBox(width: 12),
                _buildNutrientCell(
                  theme,
                  'Fat',
                  Formatters.formatMacro(_displayFat),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientCell(ThemeData theme, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
                fontSize: 18,
                fontWeight: FontWeight.bold,
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

  Widget _buildMealInfoCard(ThemeData theme) {
    final now = DateTime.now();
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final hour12 =
        now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final timeStr =
        'Today, $hour12:${now.minute.toString().padLeft(2, '0')} $period';
    final mealLabel =
        widget.mealType[0].toUpperCase() + widget.mealType.substring(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Meal: ',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  mealLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Time: ',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  timeStr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddToLogButton(ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _handleSave,
      icon: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textPrimary,
              ),
            )
          : const Icon(Icons.check_circle_outline),
      label: Text(_isSaving ? 'Saving...' : 'Add to Log'),
    );
  }

  Widget _buildEditDetailsButton(ThemeData theme) {
    return OutlinedButton.icon(
      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Edit Details'),
    );
  }

  Widget _buildErrorRetry(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _handleSave,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
