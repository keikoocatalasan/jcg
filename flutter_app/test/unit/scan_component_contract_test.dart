import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/ai_scanner/ai_scanner_provider.dart';

void main() {
  test('parses a mixed ulam and rice response without flattening components',
      () {
    final result = ScanResult.fromJson({
      'scan_id': 'scan-1',
      'client_scan_id': 'client-1',
      'status': 'low_confidence',
      'pipeline_version': 'scanner-v2',
      'needs_portion_input': true,
      'predictions': [
        {
          'food_id': 'food-adobo',
          'food_name': 'Chicken Adobo',
          'confidence': 0.59,
          'rank_number': 1,
          'serving_grams': 180,
        },
      ],
      'components': [
        {
          'component_id': 'scan-1:ulam',
          'role': 'ulam',
          'food_id': 'food-adobo',
          'food_name': 'Chicken Adobo',
          'confidence': 0.59,
          'reference_grams': 180,
        },
        {
          'component_id': 'scan-1:rice',
          'role': 'rice',
          'food_name': 'Cooked White Rice',
          'confidence': 0.59,
          'reference_grams': 150,
        },
      ],
    });

    expect(result.needsPortionInput, isTrue);
    expect(result.predictions.single.servingGrams, 180);
    expect(result.components, hasLength(2));
    expect(result.components[0].roleCode, 'ulam');
    expect(result.components[1].roleCode, 'rice');
    expect(result.components[1].referenceGrams, 150);
  });
}
