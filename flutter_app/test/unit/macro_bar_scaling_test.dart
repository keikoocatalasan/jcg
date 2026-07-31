import 'package:flutter_test/flutter_test.dart';

/// Tests for food quantity scaling formulas used across the app.
///
/// Scaling formula: when a food has known nutrients per serving and a user
/// specifies quantity Q, the scaled values are:
///   scaledNutrient = nutrientPerServing * Q
///
/// The MacroBar widget uses the ratio formula:
///   ratio = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0
///
/// This covers quantity scaling for meal logging, meal planning, and
/// AI scan confirmation where quantity multipliers are applied.

double scaleNutrient(double perServing, double quantity) {
  return perServing * quantity;
}

double scaleCalories(double perServing, double quantity) {
  return perServing * quantity;
}

double scaleCost(double pricePerServing, double quantity) {
  return pricePerServing * quantity;
}

double progressRatio(double current, double target) {
  if (target <= 0) return 0.0;
  return (current / target).clamp(0.0, 1.0);
}

double reverseScaleServing(double scaledNutrient, double perServing) {
  if (perServing <= 0) return 0.0;
  return scaledNutrient / perServing;
}

void main() {
  group('Quantity Scaling', () {
    test('scales protein correctly with quantity 2', () {
      // Food has 53g protein per serving, quantity = 2
      expect(scaleNutrient(53.0, 2.0), closeTo(106.0, 0.01));
    });

    test('scales protein correctly with quantity 0.5', () {
      // Food has 53g protein per serving, quantity = 0.5
      expect(scaleNutrient(53.0, 0.5), closeTo(26.5, 0.01));
    });

    test('scales calories with quantity 3', () {
      expect(scaleCalories(284.0, 3.0), closeTo(852.0, 0.01));
    });

    test('scales cost with quantity 1.5', () {
      expect(scaleCost(55.0, 1.5), closeTo(82.5, 0.01));
    });

    test('zero quantity yields zero', () {
      expect(scaleNutrient(100.0, 0.0), 0.0);
    });

    test('unit quantity returns same value', () {
      expect(scaleNutrient(53.0, 1.0), 53.0);
    });

    test('reverse scale derives original quantity', () {
      const originalQty = 2.5;
      const perServing = 53.0;
      final scaled = scaleNutrient(perServing, originalQty);
      final derivedQty = reverseScaleServing(scaled, perServing);
      expect(derivedQty, closeTo(originalQty, 0.001));
    });
  });

  group('MacroBar Progress Ratio', () {
    test('zero target returns zero ratio', () {
      expect(progressRatio(50.0, 0.0), 0.0);
    });

    test('negative target returns zero ratio', () {
      expect(progressRatio(50.0, -100.0), 0.0);
    });

    test('current equals target returns 1.0', () {
      expect(progressRatio(100.0, 100.0), 1.0);
    });

    test('current half of target returns 0.5', () {
      expect(progressRatio(50.0, 100.0), 0.5);
    });

    test('current exceeds target clamps to 1.0', () {
      expect(progressRatio(150.0, 100.0), 1.0);
    });

    test('current is zero returns 0.0', () {
      expect(progressRatio(0.0, 100.0), 0.0);
    });

    test('both zero returns 0.0', () {
      expect(progressRatio(0.0, 0.0), 0.0);
    });
  });

  group('Multi-Nutrient Scaling (Meal Log)', () {
    test('scale all macros for a meal with quantity 2', () {
      const perServing = {
        'calories': 284.0,
        'protein_g': 53.0,
        'carbs_g': 0.0,
        'fat_g': 6.0,
      };
      const quantity = 2.0;

      final scaled = perServing.map(
        (key, value) => MapEntry(key, value * quantity),
      );

      expect(scaled['calories'], closeTo(568.0, 0.01));
      expect(scaled['protein_g'], closeTo(106.0, 0.01));
      expect(scaled['carbs_g'], closeTo(0.0, 0.01));
      expect(scaled['fat_g'], closeTo(12.0, 0.01));
    });

    test('scale half serving of rice (cooked)', () {
      // 1 serving rice = 200 calories, 45g carbs, 4g protein, 0.4g fat
      const riceServing = {
        'calories': 200.0,
        'protein_g': 4.0,
        'carbs_g': 45.0,
        'fat_g': 0.4,
      };
      const quantity = 0.5;

      final scaled = riceServing.map(
        (key, value) => MapEntry(key, value * quantity),
      );

      expect(scaled['calories'], closeTo(100.0, 0.01));
      expect(scaled['carbs_g'], closeTo(22.5, 0.01));
      expect(scaled['protein_g'], closeTo(2.0, 0.01));
      expect(scaled['fat_g'], closeTo(0.2, 0.01));
    });
  });

  group('Budget Scaling', () {
    test('scale food cost by quantity', () {
      expect(scaleCost(35.0, 3.0), closeTo(105.0, 0.01));
    });

    test('scale budget proportionally for partial serving', () {
      expect(scaleCost(80.0, 0.25), closeTo(20.0, 0.01));
    });
  });

  group('Edge Cases', () {
    test('very large quantity does not overflow', () {
      // Quantity = 1000, nutrient = 0.5g per serving
      final result = scaleNutrient(0.5, 1000.0);
      expect(result, closeTo(500.0, 0.01));
    });

    test('reverse scaling with zero per-serving returns 0', () {
      expect(reverseScaleServing(100.0, 0.0), 0.0);
    });

    test('negative quantity returns negative scaled value', () {
      // Not expected in UI, but formula should be consistent
      expect(scaleNutrient(50.0, -1.0), -50.0);
    });
  });
}
