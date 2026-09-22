import 'package:jcg_fitness/app/constants.dart';

enum AdultBmiCategory {
  underweight('Underweight'),
  normalRange('Normal range'),
  overweight('Overweight'),
  obesity('Obesity');

  const AdultBmiCategory(this.label);

  final String label;
}

class BmiResult {
  const BmiResult({
    required this.bmi,
    required this.weightKg,
    required this.heightCm,
    required this.ageYears,
    required this.measuredAt,
    required this.usedProfileWeight,
    required this.adultCategory,
  });

  final double bmi;
  final double weightKg;
  final double heightCm;
  final int? ageYears;
  final String? measuredAt;
  final bool usedProfileWeight;
  final AdultBmiCategory? adultCategory;

  bool get hasAdultInterpretation => adultCategory != null;
}

/// Calculates BMI as an informational screening measure.
///
/// Adult categories are intentionally withheld below age 20; this app does
/// not yet have the exact age-in-months or BMI-for-age reference needed for
/// youth interpretation.
class BmiCalculator {
  BmiCalculator._();

  static const adultCategoryMinimumAge = 20;

  static BmiResult? calculate({
    required double weightKg,
    required double heightCm,
    required int? ageYears,
    String? measuredAt,
    bool usedProfileWeight = false,
  }) {
    if (!weightKg.isFinite ||
        !heightCm.isFinite ||
        weightKg < AppConstants.minWeightKg ||
        weightKg > AppConstants.maxWeightKg ||
        heightCm < AppConstants.minHeightCm ||
        heightCm > AppConstants.maxHeightCm) {
      return null;
    }

    final heightM = heightCm / 100;
    final bmi = weightKg / (heightM * heightM);
    if (!bmi.isFinite || bmi <= 0) return null;

    final adultCategory =
        ageYears != null && ageYears >= adultCategoryMinimumAge
            ? classifyAdult(bmi)
            : null;

    return BmiResult(
      bmi: bmi,
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: ageYears,
      measuredAt: measuredAt,
      usedProfileWeight: usedProfileWeight,
      adultCategory: adultCategory,
    );
  }

  /// PSA-published standard adult bands: <18.5, 18.5–<25, 25–<30, and >=30.
  /// Classification uses the unrounded BMI; only the displayed number rounds.
  static AdultBmiCategory? classifyAdult(double bmi) {
    if (!bmi.isFinite || bmi <= 0) return null;
    if (bmi < 18.5) return AdultBmiCategory.underweight;
    if (bmi < 25) return AdultBmiCategory.normalRange;
    if (bmi < 30) return AdultBmiCategory.overweight;
    return AdultBmiCategory.obesity;
  }
}
