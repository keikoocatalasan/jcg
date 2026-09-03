import 'dart:typed_data';

class LocalDishRecognition {
  final String modelLabel;
  final String foodName;
  final double confidence;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double estimatedCostPhp;
  final double? servingGrams;

  const LocalDishRecognition({
    required this.modelLabel,
    required this.foodName,
    required this.confidence,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.estimatedCostPhp,
    this.servingGrams,
  });
}

class LocalFoodRecognitionService {
  static const modelName = 'jcg_two_dish_classifier';
  static const modelVersion = 'two-dish-v1';
  static const confidentThreshold = 0.95;
  static const confidentMarginThreshold = 0.20;

  static bool isConfident(List<LocalDishRecognition> results) {
    if (results.isEmpty || results.first.confidence < confidentThreshold) {
      return false;
    }
    final runnerUp = results.length > 1 ? results[1].confidence : 0.0;
    return results.first.confidence - runnerUp >= confidentMarginThreshold;
  }

  Future<List<LocalDishRecognition>> recognizeFile(String imagePath) {
    throw UnsupportedError('On-device vision is available on Android and iOS.');
  }

  Future<List<LocalDishRecognition>> recognizeBytes(Uint8List bytes) {
    throw UnsupportedError('On-device vision is available on Android and iOS.');
  }

  void close() {}
}
