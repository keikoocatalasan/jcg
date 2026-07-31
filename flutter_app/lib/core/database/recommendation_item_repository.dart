import 'base_repository.dart';

class RecommendationItem {
  final String recommendationItemId;
  final String sessionId;
  final String foodId;
  final String? linkedMealLogId;
  final String? linkedMealPlanId;
  final int rankNumber;
  final double finalScore;
  final double affordabilityScore;
  final double proteinFitScore;
  final double calorieFitScore;
  final double macroBalanceScore;
  final double goalMatchScore;
  final double mealTypeScore;
  final double overBudgetPenalty;
  final String? reasonText;
  final bool wasAccepted;
  final String? acceptedAt;
  final String syncStatus;

  RecommendationItem({
    required this.recommendationItemId,
    required this.sessionId,
    required this.foodId,
    this.linkedMealLogId,
    this.linkedMealPlanId,
    required this.rankNumber,
    required this.finalScore,
    required this.affordabilityScore,
    required this.proteinFitScore,
    required this.calorieFitScore,
    required this.macroBalanceScore,
    required this.goalMatchScore,
    required this.mealTypeScore,
    required this.overBudgetPenalty,
    this.reasonText,
    required this.wasAccepted,
    this.acceptedAt,
    required this.syncStatus,
  });
}

class RecommendationItemRepository extends BaseRepository<RecommendationItem> {
  RecommendationItemRepository(super._dbProvider);

  @override
  String get tableName => 'recommendation_items';

  @override
  String get pkColumn => 'recommendation_item_id';

  @override
  RecommendationItem fromMap(Map<String, dynamic> map) {
    return RecommendationItem(
      recommendationItemId: map['recommendation_item_id'] as String,
      sessionId: map['session_id'] as String,
      foodId: map['food_id'] as String,
      linkedMealLogId: map['linked_meal_log_id'] as String?,
      linkedMealPlanId: map['linked_meal_plan_id'] as String?,
      rankNumber: map['rank_number'] as int,
      finalScore: (map['final_score'] as num).toDouble(),
      affordabilityScore: (map['affordability_score'] as num).toDouble(),
      proteinFitScore: (map['protein_fit_score'] as num).toDouble(),
      calorieFitScore: (map['calorie_fit_score'] as num).toDouble(),
      macroBalanceScore: (map['macro_balance_score'] as num).toDouble(),
      goalMatchScore: (map['goal_match_score'] as num).toDouble(),
      mealTypeScore: (map['meal_type_score'] as num).toDouble(),
      overBudgetPenalty: (map['over_budget_penalty'] as num).toDouble(),
      reasonText: map['reason_text'] as String?,
      wasAccepted: map['was_accepted'] == 1,
      acceptedAt: map['accepted_at'] as String?,
      syncStatus: map['sync_status'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap(RecommendationItem entity) {
    return {
      'recommendation_item_id': entity.recommendationItemId,
      'session_id': entity.sessionId,
      'food_id': entity.foodId,
      'linked_meal_log_id': entity.linkedMealLogId,
      'linked_meal_plan_id': entity.linkedMealPlanId,
      'rank_number': entity.rankNumber,
      'final_score': entity.finalScore,
      'affordability_score': entity.affordabilityScore,
      'protein_fit_score': entity.proteinFitScore,
      'calorie_fit_score': entity.calorieFitScore,
      'macro_balance_score': entity.macroBalanceScore,
      'goal_match_score': entity.goalMatchScore,
      'meal_type_score': entity.mealTypeScore,
      'over_budget_penalty': entity.overBudgetPenalty,
      'reason_text': entity.reasonText,
      'was_accepted': entity.wasAccepted ? 1 : 0,
      'accepted_at': entity.acceptedAt,
      'sync_status': entity.syncStatus,
    };
  }

  Future<List<RecommendationItem>> queryBySession(String sessionId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'rank_number',
    );
    return results.map(fromMap).toList();
  }

  Future<int> markAccepted(String itemId,
      {String? linkedMealLogId, String? linkedMealPlanId}) async {
    final db = await database;
    final values = <String, dynamic>{
      'was_accepted': 1,
      'accepted_at': DateTime.now().toIso8601String(),
    };
    if (linkedMealLogId != null) {
      values['linked_meal_log_id'] = linkedMealLogId;
    }
    if (linkedMealPlanId != null) {
      values['linked_meal_plan_id'] = linkedMealPlanId;
    }
    return db.update(
      tableName,
      values,
      where: 'recommendation_item_id = ?',
      whereArgs: [itemId],
    );
  }
}
