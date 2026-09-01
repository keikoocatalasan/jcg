import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/constants/food_taxonomy.dart';

class ScoredFood {
  final Food food;
  final double finalScore;
  final double affordabilityScore;
  final double proteinFitScore;
  final double calorieFitScore;
  final double macroBalanceScore;
  final double goalMatchScore;
  final double mealTypeScore;
  final double overBudgetPenalty;
  final String reasonText;

  const ScoredFood({
    required this.food,
    required this.finalScore,
    required this.affordabilityScore,
    required this.proteinFitScore,
    required this.calorieFitScore,
    required this.macroBalanceScore,
    required this.goalMatchScore,
    required this.mealTypeScore,
    required this.overBudgetPenalty,
    required this.reasonText,
  });
}

class RecommendationEngine {
  RecommendationEngine._();

  static const int _maxResults = 10;

  static const Map<String, List<String>> _allergenCategoryMap = {
    'milk': [],
    'egg': [],
    'gluten': ['Bread and Pastry'],
    'peanut': [],
    'tree_nut': [],
    'soy': ['Legumes and Tofu'],
    'fish': ['Seafood'],
    'shellfish': ['Seafood'],
    'wheat': ['Bread and Pastry'],
    'sesame': [],
  };

  static const Map<String, List<String>> _allergenNameKeywords = {
    'milk': ['milk', 'cheese', 'cream', 'butter', 'yogurt', 'dairy'],
    'egg': ['egg', 'eggs'],
    'gluten': [
      'gluten',
      'wheat',
      'flour',
      'bread',
      'pasta',
      'noodle',
      'spaghetti',
      'macaroni'
    ],
    'peanut': ['peanut'],
    'tree_nut': [
      'almond',
      'cashew',
      'walnut',
      'pecan',
      'macadamia',
      'hazelnut',
      'pistachio'
    ],
    'soy': ['soy', 'tofu', 'soya', 'miso'],
    'fish': [
      'fish',
      'tilapia',
      'bangus',
      'tuna',
      'salmon',
      'mackerel',
      'galunggong'
    ],
    'shellfish': [
      'shrimp',
      'crab',
      'lobster',
      'prawn',
      'shellfish',
      'alimango',
      'hipon'
    ],
    'wheat': ['wheat', 'flour', 'bread', 'pasta', 'noodle'],
    'sesame': ['sesame'],
  };

  static const Map<String, List<String>> _restrictionExcludeCategories = {
    'vegetarian': ['Meat and Poultry', 'Seafood'],
    'vegan': ['Meat and Poultry', 'Seafood', 'Dairy and Eggs'],
    'low_carb': [
      'Rice and Grains',
      'Bread and Pastry',
      'Snacks and Desserts',
    ],
    'low_fat': [],
  };

  static const Map<String, List<String>> _restrictionNameKeywords = {
    'halal': ['pork', 'bacon', 'ham', 'lechon'],
    'no_pork': ['pork', 'bacon', 'ham', 'lechon', 'liempo'],
    'no_beef': ['beef', 'baka', 'corned beef'],
    'lactose_intolerant': [
      'milk',
      'cheese',
      'cream',
      'butter',
      'yogurt',
    ],
    'gluten_free': [
      'gluten',
      'wheat',
      'flour',
      'bread',
      'pasta',
      'noodle',
    ],
    'vegetarian': [],
    'vegan': [],
    'keto': [],
    'low_carb': [],
    'low_fat': [],
  };

  static List<ScoredFood> generate({
    required double remainingBudget,
    required int remainingCalories,
    required double remainingProtein,
    required double remainingCarbs,
    required double remainingFat,
    required String fitnessGoalCode,
    required String? mealTypeCode,
    required List<String> allergies,
    required List<String> dietaryRestrictions,
    required List<Food> availableFoods,
    double? minimumPricePhp,
    double? maximumPricePhp,
    bool highProteinOnly = false,
    bool lowCostOnly = false,
  }) {
    final safeBudget = remainingBudget.clamp(0.0, double.infinity);
    final safeCalories = remainingCalories.clamp(0, 2147483647);
    final safeProtein = remainingProtein.clamp(0.0, double.infinity);
    final safeCarbs = remainingCarbs.clamp(0.0, double.infinity);
    final safeFat = remainingFat.clamp(0.0, double.infinity);

    final safeMinimumPrice = minimumPricePhp?.clamp(0.0, double.infinity);
    final safeMaximumPrice = maximumPricePhp?.clamp(0.0, double.infinity);

    final filtered = availableFoods.where((food) {
      return !_conflictsWithAllergies(food, allergies) &&
          !_conflictsWithRestrictions(food, dietaryRestrictions) &&
          _calcMealTypeSuitable(food, mealTypeCode) &&
          (safeMinimumPrice == null ||
              food.estimatedPricePhp >= safeMinimumPrice) &&
          (safeMaximumPrice == null ||
              food.estimatedPricePhp <= safeMaximumPrice) &&
          (!highProteinOnly || food.proteinG >= 15);
    }).toList();

    final scored = filtered.map((food) {
      return _scoreFood(
        food: food,
        remainingBudget: safeBudget,
        remainingCalories: safeCalories,
        remainingProtein: safeProtein,
        remainingCarbs: safeCarbs,
        remainingFat: safeFat,
        fitnessGoalCode: fitnessGoalCode,
        mealTypeCode: mealTypeCode,
      );
    }).toList();

    if (lowCostOnly) {
      scored.removeWhere((item) => item.affordabilityScore < 0.7);
    }

    scored.sort((a, b) => b.finalScore.compareTo(a.finalScore));

    return scored.take(_maxResults).toList();
  }

  static bool _conflictsWithAllergies(Food food, List<String> allergies) {
    if (allergies.isEmpty) return false;
    final name = food.foodName.toLowerCase();
    final category = food.categoryName;

    for (final allergy in allergies) {
      final trimmedAllergy = FoodTaxonomy.normalizeAllergyCode(allergy);
      if (trimmedAllergy.isEmpty) continue;

      final categories = _allergenCategoryMap[trimmedAllergy] ?? [];
      if (categories.contains(category)) return true;

      final keywords = _allergenNameKeywords[trimmedAllergy] ?? [];
      for (final kw in keywords) {
        if (name.contains(kw)) return true;
      }
    }

    return false;
  }

  static bool _conflictsWithRestrictions(Food food, List<String> restrictions) {
    if (restrictions.isEmpty) return false;
    final name = food.foodName.toLowerCase();
    final category = food.categoryName;

    for (final restriction in restrictions) {
      final trimmed = FoodTaxonomy.normalizeRestrictionCode(restriction);
      if (trimmed.isEmpty) continue;

      final excludeCategories = _restrictionExcludeCategories[trimmed] ?? [];
      if (excludeCategories.contains(category)) return true;

      if ((trimmed == 'halal' || trimmed == 'no_pork') &&
          _isPorkRelated(name)) {
        return true;
      }

      if (trimmed == 'low_fat' && food.fatG > 10) return true;

      final keywords = _restrictionNameKeywords[trimmed] ?? [];
      for (final kw in keywords) {
        if (name.contains(kw)) return true;
      }
    }

    return false;
  }

  static bool _isPorkRelated(String name) {
    return name.contains('pork') ||
        name.contains('bacon') ||
        name.contains('ham') ||
        name.contains('lechon') ||
        name.contains('liempo');
  }

  static ScoredFood _scoreFood({
    required Food food,
    required double remainingBudget,
    required int remainingCalories,
    required double remainingProtein,
    required double remainingCarbs,
    required double remainingFat,
    required String fitnessGoalCode,
    required String? mealTypeCode,
  }) {
    final affordabilityScore =
        _calcAffordability(food.estimatedPricePhp, remainingBudget);
    final proteinFitScore =
        _calcFitScore(food.proteinG, remainingProtein.toDouble());
    final calorieFitScore =
        _calcFitScore(food.calories, remainingCalories.toDouble());
    final carbsFitScore = _calcFitScore(food.carbsG, remainingCarbs);
    final fatFitScore = _calcFitScore(food.fatG, remainingFat);

    final macroBalanceScore =
        (proteinFitScore + carbsFitScore + fatFitScore) / 3;

    final goalMatchScore = _calcGoalMatch(food, fitnessGoalCode) ? 1.00 : 0.50;
    final mealTypeScore =
        _calcMealTypeSuitable(food, mealTypeCode) ? 1.00 : 0.50;

    final overBudgetPenalty =
        food.estimatedPricePhp > remainingBudget ? 0.25 : 0.00;

    final finalScore = 0.30 * affordabilityScore +
        0.25 * proteinFitScore +
        0.20 * calorieFitScore +
        0.15 * macroBalanceScore +
        0.05 * goalMatchScore +
        0.05 * mealTypeScore -
        overBudgetPenalty;

    final reasonText = _generateReason(
      affordabilityScore: affordabilityScore,
      proteinFitScore: proteinFitScore,
      calorieFitScore: calorieFitScore,
      macroBalanceScore: macroBalanceScore,
      goalMatchScore: goalMatchScore,
      mealTypeScore: mealTypeScore,
      overBudgetPenalty: overBudgetPenalty,
    );

    return ScoredFood(
      food: food,
      finalScore: finalScore,
      affordabilityScore: affordabilityScore,
      proteinFitScore: proteinFitScore,
      calorieFitScore: calorieFitScore,
      macroBalanceScore: macroBalanceScore,
      goalMatchScore: goalMatchScore,
      mealTypeScore: mealTypeScore,
      overBudgetPenalty: overBudgetPenalty,
      reasonText: reasonText,
    );
  }

  static double _calcAffordability(double foodCost, double remainingBudget) {
    final divisor = remainingBudget >= 1 ? remainingBudget : 1;
    return 1 - (foodCost / divisor).clamp(0, 1);
  }

  static double _calcFitScore(double foodValue, double remainingValue) {
    final divisor = remainingValue >= 1 ? remainingValue : 1;
    return 1 - ((foodValue - remainingValue).abs() / divisor).clamp(0, 1);
  }

  static bool _calcGoalMatch(Food food, String goalCode) {
    switch (goalCode) {
      case 'cutting':
        return food.proteinG / food.calories.max(1.0) >= 0.035 &&
            food.estimatedPricePhp <= 100;
      case 'maintenance':
        final values = [food.proteinG, food.carbsG, food.fatG];
        final maxV = values.reduce((a, b) => a > b ? a : b);
        final minV = values.reduce((a, b) => a < b ? a : b);
        return (maxV - minV) <= 50;
      case 'bulking':
        return food.calories >= 300 && food.proteinG >= 15;
      case 'lean':
      case 'lean_bulk':
        return food.proteinG >= 15 &&
            food.calories >= 200 &&
            food.calories <= 500;
      case 'gain_weight':
        final costPerCalorie = food.estimatedPricePhp / food.calories.max(1.0);
        return costPerCalorie <= 0.5 && food.calories >= 200;
      default:
        return false;
    }
  }

  static bool _calcMealTypeSuitable(Food food, String? mealTypeCode) {
    if (mealTypeCode == null || mealTypeCode.isEmpty) return true;
    return FoodTaxonomy.suitableMealTypes(
      categoryName: food.categoryName,
      explicitCodes: food.mealTypeCodes,
    ).contains(mealTypeCode);
  }

  static String _generateReason({
    required double affordabilityScore,
    required double proteinFitScore,
    required double calorieFitScore,
    required double macroBalanceScore,
    required double goalMatchScore,
    required double mealTypeScore,
    required double overBudgetPenalty,
  }) {
    if (overBudgetPenalty > 0) {
      if (affordabilityScore >= 0.7) {
        return 'Slightly over budget but affordable with strong protein match';
      }
      return 'Over budget; consider smaller portion or alternative';
    }

    if (affordabilityScore >= 0.8) {
      if (proteinFitScore >= 0.8) {
        return 'Best value: affordable with excellent protein fit';
      }
      return 'Budget-friendly option';
    }

    if (proteinFitScore >= 0.85) {
      return 'Top protein match for your remaining needs';
    }

    if (calorieFitScore >= 0.85) {
      return 'Calorie-perfect fit for your remaining allowance';
    }

    if (macroBalanceScore >= 0.7) {
      return 'Balanced macronutrient profile';
    }

    if (proteinFitScore >= 0.6 && affordabilityScore >= 0.5) {
      return 'Good protein-to-cost value';
    }

    return 'Decent all-around match';
  }
}

extension _DoubleMax on double {
  double max(double other) => this > other ? this : other;
}
