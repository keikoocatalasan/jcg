import 'base_repository.dart';

class AiScanPrediction {
  final String predictionId;
  final String scanId;
  final String? foodId;
  final String predictedFoodName;
  final double confidence;
  final int rankNumber;
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? estimatedCostPhp;
  final String syncStatus;

  AiScanPrediction({
    required this.predictionId,
    required this.scanId,
    this.foodId,
    required this.predictedFoodName,
    required this.confidence,
    required this.rankNumber,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.estimatedCostPhp,
    required this.syncStatus,
  });
}

class AiScanPredictionRepository extends BaseRepository<AiScanPrediction> {
  AiScanPredictionRepository(super._dbProvider);

  @override
  String get tableName => 'ai_scan_predictions';

  @override
  String get pkColumn => 'prediction_id';

  @override
  AiScanPrediction fromMap(Map<String, dynamic> map) {
    return AiScanPrediction(
      predictionId: map['prediction_id'] as String,
      scanId: map['scan_id'] as String,
      foodId: map['food_id'] as String?,
      predictedFoodName: map['predicted_food_name'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      rankNumber: map['rank_number'] as int,
      calories: (map['calories'] as num?)?.toDouble(),
      proteinG: (map['protein_g'] as num?)?.toDouble(),
      carbsG: (map['carbs_g'] as num?)?.toDouble(),
      fatG: (map['fat_g'] as num?)?.toDouble(),
      estimatedCostPhp: (map['estimated_cost_php'] as num?)?.toDouble(),
      syncStatus: map['sync_status'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap(AiScanPrediction entity) {
    return {
      'prediction_id': entity.predictionId,
      'scan_id': entity.scanId,
      'food_id': entity.foodId,
      'predicted_food_name': entity.predictedFoodName,
      'confidence': entity.confidence,
      'rank_number': entity.rankNumber,
      'calories': entity.calories,
      'protein_g': entity.proteinG,
      'carbs_g': entity.carbsG,
      'fat_g': entity.fatG,
      'estimated_cost_php': entity.estimatedCostPhp,
      'sync_status': entity.syncStatus,
    };
  }

  Future<List<AiScanPrediction>> queryByScan(String scanId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'scan_id = ?',
      whereArgs: [scanId],
      orderBy: 'rank_number',
    );
    return results.map(fromMap).toList();
  }
}
