import 'package:sqflite/sqflite.dart';
import 'base_repository.dart';

class AiScanFeedback {
  final String feedbackId;
  final String scanId;
  final String? clientScanId;
  final String? selectedFoodId;
  final bool? wasHelpful;
  final String? feedbackText;
  final String? selectedPredictionId;
  final String? mealLogId;
  final String? confirmedFoodId;
  final double? quantity;
  final String? mealTypeCode;
  final String? correctionReason;
  final String? feedbackType;
  final String syncStatus;
  final String? createdAt;
  final String? confirmedAt;

  AiScanFeedback({
    required this.feedbackId,
    required this.scanId,
    this.clientScanId,
    this.selectedFoodId,
    this.wasHelpful,
    this.feedbackText,
    this.selectedPredictionId,
    this.mealLogId,
    this.confirmedFoodId,
    this.quantity,
    this.mealTypeCode,
    this.correctionReason,
    this.feedbackType,
    required this.syncStatus,
    this.createdAt,
    this.confirmedAt,
  });
}

class AiScanFeedbackRepository extends BaseRepository<AiScanFeedback> {
  AiScanFeedbackRepository(super._dbProvider);

  @override
  String get tableName => 'ai_scan_feedback';

  @override
  String get pkColumn => 'feedback_id';

  @override
  AiScanFeedback fromMap(Map<String, dynamic> map) {
    return AiScanFeedback(
      feedbackId: map['feedback_id'] as String,
      scanId: map['scan_id'] as String,
      clientScanId: map['client_scan_id'] as String?,
      selectedFoodId: map['selected_food_id'] as String?,
      wasHelpful:
          map['was_helpful'] == null ? null : (map['was_helpful'] as int) == 1,
      feedbackText: map['feedback_text'] as String?,
      selectedPredictionId: map['selected_prediction_id'] as String?,
      mealLogId: map['meal_log_id'] as String?,
      confirmedFoodId: map['confirmed_food_id'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble(),
      mealTypeCode: map['meal_type_code'] as String?,
      correctionReason: map['correction_reason'] as String?,
      feedbackType: map['feedback_type'] as String?,
      syncStatus: map['sync_status'] as String,
      createdAt: map['created_at'] as String?,
      confirmedAt: map['confirmed_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap(AiScanFeedback entity) {
    return {
      'feedback_id': entity.feedbackId,
      'scan_id': entity.scanId,
      'client_scan_id': entity.clientScanId,
      'selected_food_id': entity.selectedFoodId,
      'was_helpful':
          entity.wasHelpful == null ? null : (entity.wasHelpful! ? 1 : 0),
      'feedback_text': entity.feedbackText,
      'selected_prediction_id': entity.selectedPredictionId,
      'meal_log_id': entity.mealLogId,
      'confirmed_food_id': entity.confirmedFoodId,
      'quantity': entity.quantity,
      'meal_type_code': entity.mealTypeCode,
      'correction_reason': entity.correctionReason,
      'feedback_type': entity.feedbackType,
      'sync_status': entity.syncStatus,
      'created_at': entity.createdAt,
      'confirmed_at': entity.confirmedAt,
    };
  }

  Future<AiScanFeedback?> readByScanId(String scanId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'scan_id = ?',
      whereArgs: [scanId],
    );
    if (results.isEmpty) return null;
    return fromMap(results.first);
  }

  Future<AiScanFeedback> upsert(AiScanFeedback feedback) async {
    final db = await database;
    final map = toMap(feedback);
    await db.insert(
      tableName,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return feedback;
  }
}
