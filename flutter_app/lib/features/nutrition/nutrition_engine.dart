class MacroSplit {
  final double proteinPct;
  final double carbsPct;
  final double fatPct;

  const MacroSplit({
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
  });
}

class MacroGrams {
  final double proteinG;
  final double carbsG;
  final double fatG;

  const MacroGrams({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

class NutritionTargetResult {
  final double bmr;
  final double tdee;
  final int calorieTarget;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final int waterTargetMl;

  const NutritionTargetResult({
    required this.bmr,
    required this.tdee,
    required this.calorieTarget,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.waterTargetMl,
  });
}

class NutritionEngine {
  NutritionEngine._();

  static const double _calPerGramProtein = 4;
  static const double _calPerGramCarbs = 4;
  static const double _calPerGramFat = 9;

  static const Map<String, double> _activityMultipliers = {
    'sedentary': 1.20,
    'light': 1.375,
    'moderate': 1.55,
    'active': 1.725,
    'very_active': 1.90,
  };

  static const Map<String, int> _goalAdjustments = {
    'cutting': -400,
    'maintenance': 0,
    'bulking': 400,
    'lean': 200,
    'lean_bulk': 200,
    'gain_weight': 500,
  };

  static const Map<String, MacroSplit> _macroSplits = {
    'cutting': MacroSplit(proteinPct: 30, carbsPct: 45, fatPct: 25),
    'maintenance': MacroSplit(proteinPct: 25, carbsPct: 50, fatPct: 25),
    'bulking': MacroSplit(proteinPct: 30, carbsPct: 50, fatPct: 20),
    'lean': MacroSplit(proteinPct: 30, carbsPct: 45, fatPct: 25),
    'lean_bulk': MacroSplit(proteinPct: 30, carbsPct: 45, fatPct: 25),
    'gain_weight': MacroSplit(proteinPct: 25, carbsPct: 55, fatPct: 20),
  };

  static const double _waterPerKgMl = 35;

  static double calculateBMR(
    double weightKg,
    double heightCm,
    int age,
    String sexCode,
  ) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    if (sexCode == 'female') {
      return base - 161;
    }
    return base + 5;
  }

  static double calculateTDEE(double bmr, String activityLevelCode) {
    final multiplier = _activityMultipliers[activityLevelCode] ?? 1.20;
    return bmr * multiplier;
  }

  static int getGoalCalorieAdjustment(String fitnessGoalCode) {
    return _goalAdjustments[fitnessGoalCode] ?? 0;
  }

  static MacroSplit getMacroSplit(String fitnessGoalCode) {
    return _macroSplits[fitnessGoalCode] ??
        const MacroSplit(proteinPct: 25, carbsPct: 50, fatPct: 25);
  }

  static MacroGrams calculateMacroGrams(
    double totalCalories,
    MacroSplit split,
  ) {
    final proteinCal = totalCalories * split.proteinPct / 100;
    final carbsCal = totalCalories * split.carbsPct / 100;
    final fatCal = totalCalories * split.fatPct / 100;

    return MacroGrams(
      proteinG: proteinCal / _calPerGramProtein,
      carbsG: carbsCal / _calPerGramCarbs,
      fatG: fatCal / _calPerGramFat,
    );
  }

  static int calculateWaterTarget(double weightKg) {
    final raw = weightKg * _waterPerKgMl;
    return (raw / 100).floor() * 100;
  }

  static NutritionTargetResult calculateAll({
    required double weightKg,
    required double heightCm,
    required int age,
    required String sexCode,
    required String activityLevelCode,
    required String fitnessGoalCode,
  }) {
    final bmr = calculateBMR(weightKg, heightCm, age, sexCode);
    final tdee = calculateTDEE(bmr, activityLevelCode);
    final adjustment = getGoalCalorieAdjustment(fitnessGoalCode);
    final calorieTarget = (tdee + adjustment).round().clamp(1200, 5000);
    final split = getMacroSplit(fitnessGoalCode);
    final grams = calculateMacroGrams(calorieTarget.toDouble(), split);
    final water = calculateWaterTarget(weightKg);

    return NutritionTargetResult(
      bmr: bmr,
      tdee: tdee,
      calorieTarget: calorieTarget,
      proteinG: grams.proteinG,
      carbsG: grams.carbsG,
      fatG: grams.fatG,
      waterTargetMl: water,
    );
  }
}
