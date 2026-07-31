import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/core/database/ai_scan_feedback_repository.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
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

  double get _adjustedCalories => widget.calories * _quantity;
  double get _adjustedProtein => widget.proteinG * _quantity;
  double get _adjustedCarbs => widget.carbsG * _quantity;
  double get _adjustedFat => widget.fatG * _quantity;
  double get _adjustedCost => widget.estimatedCostPhp * _quantity;

  Future<void> _saveLog() async {
    setState(() => _isSaving = true);

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in')),
          );
        }
        return;
      }

      final mealLogId = UuidHelper.generateUuid();
      final now = DateTime.now().toUtc().toIso8601String();

      final mealLogData = <String, dynamic>{
        'meal_log_id': mealLogId,
        'user_id': user.id,
        'food_id': widget.foodId,
        'meal_type_code': widget.mealType,
        'log_source_code': 'ai_scanner',
        'food_name_snapshot': widget.foodName,
        'serving_grams_snapshot': 0,
        'quantity': _quantity,
        'calories_snapshot': _adjustedCalories,
        'protein_g_snapshot': _adjustedProtein,
        'carbs_g_snapshot': _adjustedCarbs,
        'fat_g_snapshot': _adjustedFat,
        'cost_php_snapshot': _adjustedCost,
        'logged_at': now,
        'is_deleted': 0,
      };

      final helper = LocalTransactionHelper(DatabaseProvider());
      await helper.createMealLog(mealLogData);

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
        quantity: _quantity,
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
                    widget.foodName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_quantity.toStringAsFixed(1)} serving',
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
                  Formatters.formatCalories(_adjustedCalories),
                ),
                const SizedBox(width: 12),
                _buildNutrientCell(
                  theme,
                  'Protein',
                  Formatters.formatMacro(_adjustedProtein),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildNutrientCell(
                  theme,
                  'Carbs',
                  Formatters.formatMacro(_adjustedCarbs),
                ),
                const SizedBox(width: 12),
                _buildNutrientCell(
                  theme,
                  'Fat',
                  Formatters.formatMacro(_adjustedFat),
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
