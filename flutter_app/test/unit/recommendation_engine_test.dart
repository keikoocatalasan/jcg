import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/features/recommendations/recommendation_engine.dart';

Food _food({
  String foodId = 'f1',
  String categoryName = 'Meat and Poultry',
  String foodName = 'Chicken Breast',
  double calories = 284,
  double proteinG = 53,
  double carbsG = 0,
  double fatG = 6,
  double estimatedPricePhp = 55,
}) {
  return Food(
    foodId: foodId,
    categoryName: categoryName,
    foodName: foodName,
    normalizedName: foodName.toLowerCase(),
    calories: calories,
    proteinG: proteinG,
    carbsG: carbsG,
    fatG: fatG,
    estimatedPricePhp: estimatedPricePhp,
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  group('affordability_score', () {
    test('food cost equal to budget gives score 0', () {
      final food = _food(estimatedPricePhp: 100);
      // We test via generate -> inspect affordabilityScore
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 100,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food],
      );

      expect(results.length, 1);
      // affordability = 1 - (100/100).clamp(0,1) = 1 - 1 = 0
      expect(results.first.affordabilityScore, closeTo(0.0, 0.001));
    });

    test('free food gives max affordability score', () {
      final food = _food(estimatedPricePhp: 0);
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 100,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food],
      );
      // affordability = 1 - (0/100).clamp(0,1) = 1
      expect(results.first.affordabilityScore, closeTo(1.0, 0.001));
    });

    test('food cost exceeds budget caps at 0', () {
      final food = _food(estimatedPricePhp: 200);
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 100,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food],
      );
      // affordability = 1 - min(200/100, 1) = 1 - 1 = 0
      expect(results.first.affordabilityScore, closeTo(0.0, 0.001));
    });

    test('half-price food gives 0.5 score', () {
      final food = _food(estimatedPricePhp: 50);
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 100,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food],
      );
      // affordability = 1 - (50/100) = 0.5
      expect(results.first.affordabilityScore, closeTo(0.5, 0.001));
    });

    test('zero budget defaults divisor to 1', () {
      final food = _food(estimatedPricePhp: 10);
      final results = RecommendationEngine.generate(
        remainingBudget: 0,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 100,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food],
      );
      // divisor = max(0,1) => 1
      // affordability = 1 - min(10/1, 1) = 1 - 1 = 0
      expect(results.first.affordabilityScore, closeTo(0.0, 0.001));
    });
  });

  group('protein_fit_score', () {
    test('exact protein match gives score 1', () {
      final food = _food(proteinG: 50);
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 100,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food],
      );
      // fit = 1 - |50-50|/50 = 1
      expect(results.first.proteinFitScore, closeTo(1.0, 0.001));
    });

    test('zero remaining protein defaults divisor to 1', () {
      final food = _food(proteinG: 10);
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 0,
        remainingCarbs: 100,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food],
      );
      // divisor = max(0,1) => 1
      // fit = 1 - |10-0|/1 = 1 - 1 = 0 BUT clamped to [0,1] = 0
      // Actually |10-0|/1 = 10, clamped to 1, so fit = 1 - 1 = 0
      expect(results.first.proteinFitScore, closeTo(0.0, 0.001));
    });
  });

  group('final_score with all components', () {
    test('perfect food scores 0.90 before penalty', () {
      final food = _food(
        estimatedPricePhp: 50,
        proteinG: 50,
        calories: 500,
        carbsG: 60,
        fatG: 20,
        categoryName: 'Meat and Poultry',
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: 'lunch',
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food, _food(foodId: 'f2', foodName: 'Rice')],
      );
      final r = results.firstWhere((f) => f.food.foodId == 'f1');

      // affordability = 1 - 50/100 = 0.5
      expect(r.affordabilityScore, closeTo(0.5, 0.001));
      // proteinFit = 1 - |50-50|/50 = 1.0
      expect(r.proteinFitScore, closeTo(1.0, 0.001));
      // calorieFit = 1 - |500-500|/500 = 1.0
      expect(r.calorieFitScore, closeTo(1.0, 0.001));
      // carbsFit = 1 - |60-60|/60 = 1.0
      // fatFit = 1 - |20-20|/20 = 1.0
      // macroBalance = (1+1+1)/3 = 1.0
      expect(r.macroBalanceScore, closeTo(1.0, 0.001));
      // goalMatch (maintenance): protein=53 (typo in meat at top, wait let me recheck)
      // maintenance: protein/calories is not relevant. The logic: max-min <= 50
      // protein=50, carbs=60, fat=20 => max=60, min=20, diff=40 <= 50 => true
      expect(r.goalMatchScore, closeTo(1.0, 0.001));
      // mealType: lunch includes 'Meat and Poultry' => true
      expect(r.mealTypeScore, closeTo(1.0, 0.001));
      // overBudgetPenalty: 50 <= 100 => 0
      expect(r.overBudgetPenalty, closeTo(0.0, 0.001));
      // final = 0.30*0.5 + 0.25*1.0 + 0.20*1.0 + 0.15*1.0 + 0.05*1.0 + 0.05*1.0 - 0
      //        = 0.15 + 0.25 + 0.20 + 0.15 + 0.05 + 0.05 = 0.85
      expect(r.finalScore, closeTo(0.85, 0.001));
    });

    test('over-budget food gets penalty', () {
      final food = _food(estimatedPricePhp: 150);
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food],
      );
      expect(results.first.overBudgetPenalty, closeTo(0.25, 0.001));
      expect(results.first.finalScore, closeTo(0.2356, 0.001));
    });

    test('results sorted descending by finalScore', () {
      final cheap = _food(
        foodId: 'cheap',
        estimatedPricePhp: 10,
        proteinG: 50,
        calories: 500,
      );
      final expensive = _food(
        foodId: 'expensive',
        estimatedPricePhp: 200,
        proteinG: 50,
        calories: 500,
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [expensive, cheap],
      );
      expect(results[0].food.foodId, 'cheap');
      expect(results[1].food.foodId, 'expensive');
    });

    test('returns at most 10 results', () {
      final foods = List.generate(
        15,
        (i) => _food(
          foodId: 'f$i',
          estimatedPricePhp: 50.0,
          proteinG: 50,
          calories: 500,
        ),
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: foods,
      );
      expect(results.length, 10);
    });
  });

  group('allergy filtering', () {
    test('milk allergy excludes foods with milk in the name', () {
      final milk = _food(
        foodId: 'milk',
        categoryName: 'Dairy and Eggs',
        foodName: 'Fresh Milk',
      );
      final chicken = _food(
        foodId: 'chicken',
        categoryName: 'Meat and Poultry',
        foodName: 'Chicken Breast',
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: ['milk'],
        dietaryRestrictions: [],
        availableFoods: [milk, chicken],
      );
      expect(results.any((r) => r.food.foodId == 'milk'), false);
      expect(results.any((r) => r.food.foodId == 'chicken'), true);
    });

    test('peanut allergy excludes food with peanut in name', () {
      final peanutButter = _food(
        foodId: 'pb',
        foodName: 'Peanut Butter',
        categoryName: 'Snacks and Desserts',
      );
      final apple = _food(
        foodId: 'apple',
        foodName: 'Apple',
        categoryName: 'Fruits',
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: ['peanut'],
        dietaryRestrictions: [],
        availableFoods: [peanutButter, apple],
      );
      expect(results.any((r) => r.food.foodId == 'pb'), false);
      expect(results.any((r) => r.food.foodId == 'apple'), true);
    });

    test('no allergies returns all foods', () {
      final milk = _food(
        foodId: 'milk',
        categoryName: 'Dairy and Eggs',
        foodName: 'Fresh Milk',
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [milk],
      );
      expect(results.length, 1);
    });

    test('gluten allergy excludes Bread and Pastry category', () {
      final bread = _food(
        foodId: 'bread',
        categoryName: 'Bread and Pastry',
        foodName: 'Whole Wheat Bread',
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: ['gluten'],
        dietaryRestrictions: [],
        availableFoods: [bread],
      );
      expect(results, isEmpty);
    });

    test('shellfish allergy excludes food with shrimp in name', () {
      final shrimp = _food(
        foodId: 'shrimp',
        foodName: 'Shrimp Sinigang',
        categoryName: 'Seafood',
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: ['shellfish'],
        dietaryRestrictions: [],
        availableFoods: [shrimp],
      );
      expect(results, isEmpty);
    });
  });

  group('over-budget penalty', () {
    test('penalty of 0.25 applied when food exceeds budget', () {
      final food = _food(estimatedPricePhp: 101);
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food],
      );
      expect(results.first.overBudgetPenalty, 0.25);
    });

    test('no penalty when food equals budget exactly', () {
      final food = _food(estimatedPricePhp: 100);
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food],
      );
      expect(results.first.overBudgetPenalty, 0.0);
    });
  });

  group('dietary restrictions filtering', () {
    test('vegetarian excludes Meat and Seafood categories', () {
      final chicken = _food(
        foodId: 'chicken',
        categoryName: 'Meat and Poultry',
        foodName: 'Chicken Breast',
      );
      final tofu = _food(
        foodId: 'tofu',
        categoryName: 'Vegetables',
        foodName: 'Tofu',
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: ['vegetarian'],
        availableFoods: [chicken, tofu],
      );
      expect(results.any((r) => r.food.foodId == 'chicken'), false);
      expect(results.any((r) => r.food.foodId == 'tofu'), true);
    });

    test('halal excludes pork-related food names', () {
      final bacon = _food(
        foodId: 'bacon',
        foodName: 'Bacon Strips',
        categoryName: 'Meat and Poultry',
      );
      final beef = _food(
        foodId: 'beef',
        foodName: 'Beef Tapa',
        categoryName: 'Meat and Poultry',
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: ['halal'],
        availableFoods: [bacon, beef],
      );
      expect(results.any((r) => r.food.foodId == 'bacon'), false);
      expect(results.any((r) => r.food.foodId == 'beef'), true);
    });

    test('vegan excludes Meat, Seafood, and Dairy and Eggs categories', () {
      final egg = _food(
        foodId: 'egg',
        categoryName: 'Dairy and Eggs',
        foodName: 'Egg',
      );
      final fruit = _food(
        foodId: 'apple',
        categoryName: 'Fruits',
        foodName: 'Apple',
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: ['vegan'],
        availableFoods: [egg, fruit],
      );
      expect(results.any((r) => r.food.foodId == 'egg'), false);
      expect(results.any((r) => r.food.foodId == 'apple'), true);
    });
  });

  group('meal type scoring', () {
    test('breakfast food scores 1.0 for breakfast meal type', () {
      final cereal = _food(
        foodId: 'cereal',
        categoryName: 'Bread and Pastry',
        foodName: 'Oatmeal',
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: 'breakfast',
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [cereal],
      );
      expect(results.first.mealTypeScore, closeTo(1.0, 0.001));
    });

    test('non-breakfast food is excluded by breakfast filter', () {
      final meat = _food(
        foodId: 'meat',
        categoryName: 'Meat and Poultry',
        foodName: 'Beef',
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: 'breakfast',
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [meat],
      );
      expect(results, isEmpty);
    });

    test('explicit meal tags override category fallback', () {
      final breakfastMeat = _food(
        foodId: 'tocino',
        categoryName: 'Meat and Poultry',
        foodName: 'Pork Tocino',
      );
      final tagged = Food(
        foodId: breakfastMeat.foodId,
        categoryName: breakfastMeat.categoryName,
        foodName: breakfastMeat.foodName,
        normalizedName: breakfastMeat.normalizedName,
        calories: breakfastMeat.calories,
        proteinG: breakfastMeat.proteinG,
        carbsG: breakfastMeat.carbsG,
        fatG: breakfastMeat.fatG,
        estimatedPricePhp: breakfastMeat.estimatedPricePhp,
        mealTypeCodes: const ['breakfast'],
        createdAt: breakfastMeat.createdAt,
        updatedAt: breakfastMeat.updatedAt,
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: 'breakfast',
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [tagged],
      );
      expect(results.single.mealTypeScore, 1);
    });
  });

  group('hard recommendation filters', () {
    test('budget range is applied before the top-ten result cap', () {
      final expensive = List.generate(
        10,
        (index) => _food(
          foodId: 'expensive-$index',
          foodName: 'Expensive $index',
          estimatedPricePhp: 80,
          proteinG: 50,
          calories: 500,
        ),
      );
      final affordable = _food(
        foodId: 'affordable',
        foodName: 'Affordable Meal',
        estimatedPricePhp: 25,
        proteinG: 5,
        calories: 100,
      );
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        maximumPricePhp: 30,
        availableFoods: [...expensive, affordable],
      );
      expect(results.map((item) => item.food.foodId), ['affordable']);
    });

    test('display-name restrictions are normalized to canonical codes', () {
      final meat = _food(foodName: 'Chicken Adobo');
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: ['Vegetarian'],
        availableFoods: [meat],
      );
      expect(results, isEmpty);
    });
  });

  group('reason text', () {
    test('over budget with high affordability gives specific reason', () {
      final food = _food(estimatedPricePhp: 101, proteinG: 50);
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food],
      );
      expect(
        results.first.reasonText,
        'Over budget; consider smaller portion or alternative',
      );
    });

    test('best value for affordable high-protein food', () {
      final food = _food(estimatedPricePhp: 15, proteinG: 50);
      final results = RecommendationEngine.generate(
        remainingBudget: 100,
        remainingCalories: 500,
        remainingProtein: 50,
        remainingCarbs: 60,
        remainingFat: 20,
        fitnessGoalCode: 'maintenance',
        mealTypeCode: null,
        allergies: [],
        dietaryRestrictions: [],
        availableFoods: [food],
      );
      expect(results.first.reasonText,
          'Best value: affordable with excellent protein fit');
    });
  });
}
