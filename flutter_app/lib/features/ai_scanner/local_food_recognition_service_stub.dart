class LocalDishRecognition {
  final String modelLabel;
  final String foodName;
  final double confidence;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double estimatedCostPhp;

  const LocalDishRecognition({
    required this.modelLabel,
    required this.foodName,
    required this.confidence,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.estimatedCostPhp,
  });
}

class LocalFoodRecognitionService {
  static const confidentThreshold = 0.68;

  Future<List<LocalDishRecognition>> recognizeFile(String imagePath) {
    throw UnsupportedError('On-device vision is available on Android and iOS.');
  }

  void close() {}
}
