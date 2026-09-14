import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/ai_scanner/local_food_recognition_service.dart';

LocalDishRecognition result(double confidence) => LocalDishRecognition(
      modelLabel: 'test',
      foodName: 'Test dish',
      confidence: confidence,
      calories: 0,
      proteinG: 0,
      carbsG: 0,
      fatG: 0,
      estimatedCostPhp: 0,
    );

void main() {
  test('local auto-accept requires a high score and a clear margin', () {
    expect(
      LocalFoodRecognitionService.isConfident([
        result(0.97),
        result(0.03),
      ]),
      isTrue,
    );
    expect(
      LocalFoodRecognitionService.isConfident([
        result(0.79),
        result(0.12),
      ]),
      isFalse,
    );
    expect(
      LocalFoodRecognitionService.isConfident([
        result(0.94),
        result(0.84),
      ]),
      isFalse,
    );
    expect(
      LocalFoodRecognitionService.isConfident([
        result(0.84),
        result(0.10),
      ]),
      isTrue,
    );
  });

  test('an empty local result cannot be auto-accepted', () {
    expect(LocalFoodRecognitionService.isConfident([]), isFalse);
  });

  test('the explicit unknown class cannot be auto-accepted', () {
    expect(
      LocalFoodRecognitionService.isConfident([
        LocalDishRecognition(
          modelLabel: 'unknown_or_unsupported',
          foodName: 'Unknown or unsupported food',
          confidence: 0.99,
          calories: 0,
          proteinG: 0,
          carbsG: 0,
          fatG: 0,
          estimatedCostPhp: 0,
        ),
        result(0.01),
      ]),
      isFalse,
    );
  });
}
