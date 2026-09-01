import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/database/recommendation_item_repository.dart';
import 'package:jcg_fitness/core/database/recommendation_session_repository.dart';
import 'package:jcg_fitness/core/database/sync_queue_repository.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';
import 'package:jcg_fitness/features/recommendations/recommendation_engine.dart';

class RecommendationRequest {
  final String? goalCode;
  final String? mealTypeCode;
  final double? minimumPricePhp;
  final double? maximumPricePhp;
  final bool highProteinOnly;
  final bool lowCostOnly;

  const RecommendationRequest({
    this.goalCode,
    this.mealTypeCode,
    this.minimumPricePhp,
    this.maximumPricePhp,
    this.highProteinOnly = false,
    this.lowCostOnly = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendationRequest &&
          goalCode == other.goalCode &&
          mealTypeCode == other.mealTypeCode &&
          minimumPricePhp == other.minimumPricePhp &&
          maximumPricePhp == other.maximumPricePhp &&
          highProteinOnly == other.highProteinOnly &&
          lowCostOnly == other.lowCostOnly;

  @override
  int get hashCode => Object.hash(
        goalCode,
        mealTypeCode,
        minimumPricePhp,
        maximumPricePhp,
        highProteinOnly,
        lowCostOnly,
      );
}

final recommendationProvider = FutureProvider.autoDispose
    .family<List<ScoredFood>, RecommendationRequest>((ref, request) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  final profileRepo = ref.watch(profileRepositoryProvider);
  final profile = await profileRepo.readByUserId(user.id);
  if (profile == null) return [];

  final dashboardData = await ref.watch(dashboardDataProvider.future);
  final foodRepo = FoodRepository(DatabaseProvider());
  final officialFoods = await foodRepo.readActiveOfficial();
  final localFoods = await foodRepo.readByOwner(profile.userId);

  return RecommendationEngine.generate(
    remainingBudget: (dashboardData.dailyBudget - dashboardData.spentBudget)
        .clamp(0.0, double.infinity),
    remainingCalories:
        (dashboardData.targetCalories - dashboardData.consumedCalories)
            .clamp(0, dashboardData.targetCalories),
    remainingProtein:
        (dashboardData.targetProtein - dashboardData.consumedProtein)
            .clamp(0.0, double.infinity),
    remainingCarbs: (dashboardData.targetCarbs - dashboardData.consumedCarbs)
        .clamp(0.0, double.infinity),
    remainingFat: (dashboardData.targetFat - dashboardData.consumedFat)
        .clamp(0.0, double.infinity),
    fitnessGoalCode:
        request.goalCode ?? profile.fitnessGoalCode ?? 'maintenance',
    mealTypeCode: request.mealTypeCode,
    minimumPricePhp: request.minimumPricePhp,
    maximumPricePhp: request.maximumPricePhp,
    highProteinOnly: request.highProteinOnly,
    lowCostOnly: request.lowCostOnly,
    allergies: _splitCodes(profile.allergies),
    dietaryRestrictions: _splitCodes(profile.dietaryRestrictions),
    availableFoods: [...officialFoods, ...localFoods],
  );
});

final recommendationRecorderProvider = Provider<RecommendationRecorder>((ref) {
  return RecommendationRecorder(ref);
});

class RecommendationRecorder {
  final Ref _ref;

  RecommendationRecorder(this._ref);

  Future<void> record(
    RecommendationRequest request,
    List<ScoredFood> results,
  ) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final profile = await _ref.read(profileRepositoryProvider).readByUserId(
          user.id,
        );
    if (profile == null) return;
    final dashboardData = await _ref.read(dashboardDataProvider.future);

    final now = DateHelper.nowUtc();
    final sessionId = UuidHelper.generateUuid();
    final session = RecommendationSession(
      sessionId: sessionId,
      userId: profile.userId,
      remainingBudgetPhp:
          (dashboardData.dailyBudget - dashboardData.spentBudget)
              .clamp(0.0, double.infinity),
      remainingCalories:
          (dashboardData.targetCalories - dashboardData.consumedCalories)
              .clamp(0, dashboardData.targetCalories),
      remainingProteinG:
          (dashboardData.targetProtein - dashboardData.consumedProtein)
              .clamp(0.0, double.infinity),
      remainingCarbsG: (dashboardData.targetCarbs - dashboardData.consumedCarbs)
          .clamp(0.0, double.infinity),
      remainingFatG: (dashboardData.targetFat - dashboardData.consumedFat)
          .clamp(0.0, double.infinity),
      mealTypeCode: request.mealTypeCode,
      fitnessGoalCode:
          request.goalCode ?? profile.fitnessGoalCode ?? 'maintenance',
      minimumPricePhp: request.minimumPricePhp,
      maximumPricePhp: request.maximumPricePhp,
      syncStatus: 'pending',
      generatedAt: now,
    );

    final db = await DatabaseProvider().database;
    final baseSequence = DateTime.now().microsecondsSinceEpoch;
    await db.transaction((transaction) async {
      final sessionMap = RecommendationSessionRepository(
        DatabaseProvider(),
      ).toMap(session);
      await transaction.insert('recommendation_sessions', sessionMap);
      await transaction.insert(
        'sync_queue',
        SyncQueueRepository(DatabaseProvider()).toMap(
          SyncQueueEntry(
            syncQueueId: UuidHelper.generateUuid(),
            userId: profile.userId,
            operationId: UuidHelper.generateOperationId(),
            entityTypeCode: 'recommendation_session',
            entityId: sessionId,
            operationCode: 'create',
            payloadJson: jsonEncode(sessionMap),
            clientSequence: baseSequence,
            createdAt: now,
          ),
        ),
      );

      for (var index = 0; index < results.length; index++) {
        final scored = results[index];
        final item = RecommendationItem(
          recommendationItemId: UuidHelper.generateUuid(),
          sessionId: sessionId,
          foodId: scored.food.foodId,
          rankNumber: index + 1,
          finalScore: scored.finalScore,
          affordabilityScore: scored.affordabilityScore,
          proteinFitScore: scored.proteinFitScore,
          calorieFitScore: scored.calorieFitScore,
          macroBalanceScore: scored.macroBalanceScore,
          goalMatchScore: scored.goalMatchScore,
          mealTypeScore: scored.mealTypeScore,
          overBudgetPenalty: scored.overBudgetPenalty,
          reasonText: scored.reasonText,
          wasAccepted: false,
          syncStatus: 'pending',
        );
        final itemMap = RecommendationItemRepository(
          DatabaseProvider(),
        ).toMap(item);
        await transaction.insert('recommendation_items', itemMap);
        await transaction.insert(
          'sync_queue',
          SyncQueueRepository(DatabaseProvider()).toMap(
            SyncQueueEntry(
              syncQueueId: UuidHelper.generateUuid(),
              userId: profile.userId,
              operationId: UuidHelper.generateOperationId(),
              entityTypeCode: 'recommendation_item',
              entityId: item.recommendationItemId,
              operationCode: 'create',
              payloadJson: jsonEncode(itemMap),
              clientSequence: baseSequence + index + 1,
              dependsOnEntityType: 'recommendation_session',
              dependsOnEntityId: sessionId,
              createdAt: now,
            ),
          ),
        );
      }
    });
    _ref.read(syncProvider.notifier).startSync();
  }
}

List<String> _splitCodes(String? value) => (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();
