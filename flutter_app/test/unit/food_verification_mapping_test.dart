import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';

Map<String, dynamic> _foodMap({String? verificationStatus}) {
  return {
    'food_id': 'food-1',
    'category_name': 'Prepared Filipino Dishes',
    'subcategory': null,
    'description': null,
    'owner_user_id': null,
    'food_name': 'Chicken Adobo',
    'normalized_name': 'chicken adobo',
    'is_local_food': 0,
    'is_official': 1,
    'is_active': 1,
    'serving_id': 'serving-1',
    'serving_label': '1 cup',
    'serving_grams': 150.0,
    'calories': 360.0,
    'protein_g': 30.0,
    'carbs_g': 12.0,
    'fat_g': 18.0,
    'estimated_price_php': 45.0,
    'meal_type_codes': 'lunch,dinner',
    'is_deleted': 0,
    'sync_status': 'synced',
    'verification_status': verificationStatus,
    'verified_at': verificationStatus == 'verified' ? '2026-09-22T13:26:00Z' : null,
    'nutrition_source_type':
        verificationStatus == 'verified' ? 'philfct' : null,
    'nutrition_source_name':
        verificationStatus == 'verified' ? 'PhilFCT' : null,
    'source_checked_at':
        verificationStatus == 'verified' ? '2026-09-20' : null,
    'created_at': '2026-09-22T00:00:00Z',
    'updated_at': '2026-09-22T00:00:00Z',
  };
}

void main() {
  test('reads nutrition verification metadata from the synced food record',
      () {
    final food = Food.fromMap(_foodMap(verificationStatus: 'verified'));

    expect(food.isNutritionVerified, isTrue);
    expect(food.verificationStatus, 'verified');
    expect(food.nutritionSourceType, 'philfct');
    expect(food.nutritionSourceName, 'PhilFCT');
    expect(food.sourceCheckedAt, '2026-09-20');
    expect(food.verifiedAt, '2026-09-22T13:26:00Z');
  });

  test('defaults missing verification metadata to unreviewed', () {
    final food = Food.fromMap(_foodMap());

    expect(food.isNutritionVerified, isFalse);
    expect(food.verificationStatus, 'unreviewed');
    expect(food.verifiedAt, isNull);
  });
}
