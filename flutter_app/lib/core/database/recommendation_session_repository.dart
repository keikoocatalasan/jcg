import 'base_repository.dart';

class RecommendationSession {
  final String sessionId;
  final String userId;
  final double remainingBudgetPhp;
  final int remainingCalories;
  final double remainingProteinG;
  final double remainingCarbsG;
  final double remainingFatG;
  final String syncStatus;
  final String? generatedAt;

  RecommendationSession({
    required this.sessionId,
    required this.userId,
    required this.remainingBudgetPhp,
    required this.remainingCalories,
    required this.remainingProteinG,
    required this.remainingCarbsG,
    required this.remainingFatG,
    required this.syncStatus,
    this.generatedAt,
  });
}

class RecommendationSessionRepository
    extends BaseRepository<RecommendationSession> {
  RecommendationSessionRepository(super._dbProvider);

  @override
  String get tableName => 'recommendation_sessions';

  @override
  String get pkColumn => 'session_id';

  @override
  RecommendationSession fromMap(Map<String, dynamic> map) {
    return RecommendationSession(
      sessionId: map['session_id'] as String,
      userId: map['user_id'] as String,
      remainingBudgetPhp: (map['remaining_budget_php'] as num).toDouble(),
      remainingCalories: map['remaining_calories'] as int,
      remainingProteinG: (map['remaining_protein_g'] as num).toDouble(),
      remainingCarbsG: (map['remaining_carbs_g'] as num).toDouble(),
      remainingFatG: (map['remaining_fat_g'] as num).toDouble(),
      syncStatus: map['sync_status'] as String,
      generatedAt: map['generated_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap(RecommendationSession entity) {
    return {
      'session_id': entity.sessionId,
      'user_id': entity.userId,
      'remaining_budget_php': entity.remainingBudgetPhp,
      'remaining_calories': entity.remainingCalories,
      'remaining_protein_g': entity.remainingProteinG,
      'remaining_carbs_g': entity.remainingCarbsG,
      'remaining_fat_g': entity.remainingFatG,
      'sync_status': entity.syncStatus,
      'generated_at': entity.generatedAt,
    };
  }
}
