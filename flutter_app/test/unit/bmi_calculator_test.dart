import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/body_metrics/bmi_calculator.dart';

void main() {
  group('BMI calculation', () {
    test('calculates from kilograms and centimetres', () {
      final result = BmiCalculator.calculate(
        weightKg: 70,
        heightCm: 175,
        ageYears: 30,
      );

      expect(result, isNotNull);
      expect(result!.bmi, closeTo(22.857142857, 0.000001));
      expect(result.adultCategory, AdultBmiCategory.normalRange);
    });

    test('does not assign adult categories below age 20', () {
      final result = BmiCalculator.calculate(
        weightKg: 55,
        heightCm: 160,
        ageYears: 19,
      );

      expect(result, isNotNull);
      expect(result!.bmi, closeTo(21.484375, 0.000001));
      expect(result.adultCategory, isNull);
    });

    test('age 20 is eligible for an adult category', () {
      final result = BmiCalculator.calculate(
        weightKg: 70,
        heightCm: 175,
        ageYears: 20,
      );

      expect(result?.adultCategory, AdultBmiCategory.normalRange);
    });

    test('profile fallback is retained in the result provenance', () {
      final result = BmiCalculator.calculate(
        weightKg: 70,
        heightCm: 175,
        ageYears: 30,
        usedProfileWeight: true,
      );

      expect(result?.usedProfileWeight, isTrue);
      expect(result?.measuredAt, isNull);
    });

    test('rejects out-of-range, zero, NaN, and infinite measurements', () {
      expect(
        BmiCalculator.calculate(weightKg: 0, heightCm: 170, ageYears: 30),
        isNull,
      );
      expect(
        BmiCalculator.calculate(weightKg: 70, heightCm: 0, ageYears: 30),
        isNull,
      );
      expect(
        BmiCalculator.calculate(
            weightKg: double.nan, heightCm: 170, ageYears: 30),
        isNull,
      );
      expect(
        BmiCalculator.calculate(
            weightKg: 70, heightCm: double.infinity, ageYears: 30),
        isNull,
      );
      expect(
        BmiCalculator.calculate(weightKg: 19, heightCm: 170, ageYears: 30),
        isNull,
      );
      expect(
        BmiCalculator.calculate(weightKg: 70, heightCm: 251, ageYears: 30),
        isNull,
      );
    });
  });

  group('adult BMI categories', () {
    test('uses exact adult boundary values before display rounding', () {
      expect(BmiCalculator.classifyAdult(18.499), AdultBmiCategory.underweight);
      expect(BmiCalculator.classifyAdult(18.5), AdultBmiCategory.normalRange);
      expect(BmiCalculator.classifyAdult(24.999), AdultBmiCategory.normalRange);
      expect(BmiCalculator.classifyAdult(25), AdultBmiCategory.overweight);
      expect(BmiCalculator.classifyAdult(29.999), AdultBmiCategory.overweight);
      expect(BmiCalculator.classifyAdult(30), AdultBmiCategory.obesity);
    });
  });
}
