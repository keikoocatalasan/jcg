import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_engine.dart';

void main() {
  group('BMR Calculation', () {
    test('male BMR formula', () {
      // BMR = 10 × 70 + 6.25 × 175 - 5 × 25 + 5 = 1673.75
      expect(
        NutritionEngine.calculateBMR(70, 175, 25, 'male'),
        closeTo(1673.75, 0.01),
      );
    });

    test('female BMR formula', () {
      // BMR = 10 × 55 + 6.25 × 160 - 5 × 30 - 161 = 1239.00
      expect(
        NutritionEngine.calculateBMR(55, 160, 30, 'female'),
        closeTo(1239.0, 0.01),
      );
    });

    test('male BMR with edge weight and height', () {
      // BMR = 10 × 20 + 6.25 × 250 - 5 × 80 + 5 = 1367.50
      expect(
        NutritionEngine.calculateBMR(20, 250, 80, 'male'),
        closeTo(1367.5, 0.01),
      );
    });

    test('female BMR with minimum age and weight', () {
      // BMR = 10 × 20 + 6.25 × 100 - 5 × 13 - 161 = 599.00
      expect(
        NutritionEngine.calculateBMR(20, 100, 13, 'female'),
        closeTo(599.0, 0.01),
      );
    });

    test('unknown sex code defaults to male formula', () {
      expect(
        NutritionEngine.calculateBMR(70, 175, 25, 'unknown'),
        closeTo(1673.75, 0.01),
      );
    });
  });

  group('TDEE', () {
    test('sedentary multiplier', () {
      final tdee = NutritionEngine.calculateTDEE(1668.75, 'sedentary');
      // 1668.75 × 1.20 = 2002.50
      expect(tdee, closeTo(2002.50, 0.01));
    });

    test('light activity multiplier', () {
      final tdee = NutritionEngine.calculateTDEE(1668.75, 'light');
      // 1668.75 × 1.375 = 2294.53
      expect(tdee, closeTo(2294.53, 0.01));
    });

    test('moderate activity multiplier', () {
      // 1668.75 × 1.55 = 2586.56
      expect(
        NutritionEngine.calculateTDEE(1668.75, 'moderate'),
        closeTo(2586.56, 0.01),
      );
    });

    test('active multiplier', () {
      // 1668.75 × 1.725 = 2878.59
      expect(
        NutritionEngine.calculateTDEE(1668.75, 'active'),
        closeTo(2878.59, 0.01),
      );
    });

    test('very active multiplier', () {
      // 1668.75 × 1.90 = 3170.63
      expect(
        NutritionEngine.calculateTDEE(1668.75, 'very_active'),
        closeTo(3170.63, 0.01),
      );
    });

    test('unknown activity level defaults to sedentary', () {
      expect(
        NutritionEngine.calculateTDEE(1668.75, 'unknown'),
        closeTo(2002.50, 0.01),
      );
    });
  });

  group('Goal Calorie Adjustments', () {
    test('cutting returns -400', () {
      expect(NutritionEngine.getGoalCalorieAdjustment('cutting'), -400);
    });

    test('maintenance returns 0', () {
      expect(NutritionEngine.getGoalCalorieAdjustment('maintenance'), 0);
    });

    test('bulking returns 400', () {
      expect(NutritionEngine.getGoalCalorieAdjustment('bulking'), 400);
    });

    test('lean returns 200', () {
      expect(NutritionEngine.getGoalCalorieAdjustment('lean'), 200);
    });

    test('gain_weight returns 500', () {
      expect(NutritionEngine.getGoalCalorieAdjustment('gain_weight'), 500);
    });

    test('unknown goal returns 0', () {
      expect(NutritionEngine.getGoalCalorieAdjustment('unknown'), 0);
    });
  });

  group('Macro Split', () {
    test('cutting returns 30/45/25 split', () {
      final split = NutritionEngine.getMacroSplit('cutting');
      expect(split.proteinPct, 30);
      expect(split.carbsPct, 45);
      expect(split.fatPct, 25);
    });

    test('maintenance returns 25/50/25 split', () {
      final split = NutritionEngine.getMacroSplit('maintenance');
      expect(split.proteinPct, 25);
      expect(split.carbsPct, 50);
      expect(split.fatPct, 25);
    });

    test('bulking returns 30/50/20 split', () {
      final split = NutritionEngine.getMacroSplit('bulking');
      expect(split.proteinPct, 30);
      expect(split.carbsPct, 50);
      expect(split.fatPct, 20);
    });

    test('lean returns 30/45/25 split', () {
      final split = NutritionEngine.getMacroSplit('lean');
      expect(split.proteinPct, 30);
      expect(split.carbsPct, 45);
      expect(split.fatPct, 25);
    });

    test('gain_weight returns 25/55/20 split', () {
      final split = NutritionEngine.getMacroSplit('gain_weight');
      expect(split.proteinPct, 25);
      expect(split.carbsPct, 55);
      expect(split.fatPct, 20);
    });

    test('unknown goal returns default 25/50/25 split', () {
      final split = NutritionEngine.getMacroSplit('unknown');
      expect(split.proteinPct, 25);
      expect(split.carbsPct, 50);
      expect(split.fatPct, 25);
    });
  });

  group('Macro Gram Conversion', () {
    test('convert 2000 kcal cutting split to grams', () {
      const split = MacroSplit(proteinPct: 30, carbsPct: 45, fatPct: 25);
      final grams = NutritionEngine.calculateMacroGrams(2000, split);
      // Protein: 2000 × 0.30 / 4 = 150g
      // Carbs: 2000 × 0.45 / 4 = 225g
      // Fat: 2000 × 0.25 / 9 = 55.56g
      expect(grams.proteinG, closeTo(150.0, 0.01));
      expect(grams.carbsG, closeTo(225.0, 0.01));
      expect(grams.fatG, closeTo(55.56, 0.01));
    });

    test('convert 1500 kcal maintenance split to grams', () {
      const split = MacroSplit(proteinPct: 25, carbsPct: 50, fatPct: 25);
      final grams = NutritionEngine.calculateMacroGrams(1500, split);
      // Protein: 1500 × 0.25 / 4 = 93.75g
      // Carbs: 1500 × 0.50 / 4 = 187.50g
      // Fat: 1500 × 0.25 / 9 = 41.67g
      expect(grams.proteinG, closeTo(93.75, 0.01));
      expect(grams.carbsG, closeTo(187.50, 0.01));
      expect(grams.fatG, closeTo(41.67, 0.01));
    });

    test('zero calories returns zero grams', () {
      const split = MacroSplit(proteinPct: 30, carbsPct: 45, fatPct: 25);
      final grams = NutritionEngine.calculateMacroGrams(0, split);
      expect(grams.proteinG, 0.0);
      expect(grams.carbsG, 0.0);
      expect(grams.fatG, 0.0);
    });

    test('bulking 2800 kcal split to grams', () {
      const split = MacroSplit(proteinPct: 30, carbsPct: 50, fatPct: 20);
      final grams = NutritionEngine.calculateMacroGrams(2800, split);
      // Protein: 2800 × 0.30 / 4 = 210g
      // Carbs: 2800 × 0.50 / 4 = 350g
      // Fat: 2800 × 0.20 / 9 = 62.22g
      expect(grams.proteinG, closeTo(210.0, 0.01));
      expect(grams.carbsG, closeTo(350.0, 0.01));
      expect(grams.fatG, closeTo(62.22, 0.01));
    });
  });

  group('Water Target', () {
    test('70 kg person gets 2450 ml', () {
      // 70 × 35 = 2450, rounds to 2400
      expect(NutritionEngine.calculateWaterTarget(70), 2400);
    });

    test('55 kg person gets 1925 rounded to 1900 ml', () {
      expect(NutritionEngine.calculateWaterTarget(55), 1900);
    });

    test('100 kg person gets 3500 ml', () {
      // 100 × 35 = 3500, stays 3500
      expect(NutritionEngine.calculateWaterTarget(100), 3500);
    });

    test('zero weight returns 0', () {
      expect(NutritionEngine.calculateWaterTarget(0), 0);
    });
  });

  group('calculateAll Integration', () {
    test('male cutting at 70kg, 175cm, 25, sedentary', () {
      final result = NutritionEngine.calculateAll(
        weightKg: 70,
        heightCm: 175,
        age: 25,
        sexCode: 'male',
        activityLevelCode: 'sedentary',
        fitnessGoalCode: 'cutting',
      );
      // BMR = 1673.75
      // TDEE = 2008.50
      // adjustment = -400
      // calorieTarget = round(2008.50 - 400) = 1609
      // Split: 30/45/25
      // Protein: 1609 × 0.30 / 4 = 120.675g
      // Carbs: 1609 × 0.45 / 4 = 181.0125g
      // Fat: 1609 × 0.25 / 9 = 44.6944g
      // Water: 2400ml
      expect(result.bmr, closeTo(1673.75, 0.01));
      expect(result.tdee, closeTo(2008.50, 0.01));
      expect(result.calorieTarget, 1609);
      expect(result.proteinG, closeTo(120.68, 0.1));
      expect(result.carbsG, closeTo(181.01, 0.1));
      expect(result.fatG, closeTo(44.69, 0.1));
      expect(result.waterTargetMl, 2400);
    });

    test('female bulking at 55kg, 160cm, 30, moderate', () {
      final result = NutritionEngine.calculateAll(
        weightKg: 55,
        heightCm: 160,
        age: 30,
        sexCode: 'female',
        activityLevelCode: 'moderate',
        fitnessGoalCode: 'bulking',
      );
      // BMR female = 1239
      // TDEE = 1239 × 1.55 = 1920.45
      // adjustment = +400
      // calorieTarget = round(1920.45 + 400) = 2320
      expect(result.bmr, closeTo(1239.0, 0.01));
      expect(result.tdee, closeTo(1920.45, 0.01));
      expect(result.calorieTarget, 2320);
      expect(result.waterTargetMl, 1900);
    });

    test('male maintenance at 80kg, 180cm, 35, active', () {
      final result = NutritionEngine.calculateAll(
        weightKg: 80,
        heightCm: 180,
        age: 35,
        sexCode: 'male',
        activityLevelCode: 'active',
        fitnessGoalCode: 'maintenance',
      );
      // BMR = 10×80 + 6.25×180 - 5×35 + 5 = 800 + 1125 - 175 + 5 = 1755
      // TDEE = 1755 × 1.725 = 3027.375
      // no adjustment
      // calorieTarget = 3027
      expect(result.bmr, closeTo(1755.0, 0.01));
      expect(result.tdee, closeTo(3027.38, 0.01));
      expect(result.calorieTarget, 3027);
      expect(result.waterTargetMl, 2800);
    });

    test('calorie target is clamped consistently at the safe bounds', () {
      final low = NutritionEngine.calculateAll(
        weightKg: 20,
        heightCm: 100,
        age: 80,
        sexCode: 'female',
        activityLevelCode: 'sedentary',
        fitnessGoalCode: 'cutting',
      );
      final high = NutritionEngine.calculateAll(
        weightKg: 300,
        heightCm: 250,
        age: 13,
        sexCode: 'male',
        activityLevelCode: 'very_active',
        fitnessGoalCode: 'bulking',
      );

      expect(low.calorieTarget, 1200);
      expect(high.calorieTarget, 5000);
      expect(low.proteinG, closeTo(90, 0.01));
      expect(high.proteinG, closeTo(375, 0.01));
    });
  });
}
