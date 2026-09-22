import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/features/meal_logging/screens/food_search_sheet.dart';

void main() {
  testWidgets('renders and selects a matching add-on search result',
      (tester) async {
    const tomato = Food(
      foodId: 'local-food-tomato-raw',
      categoryName: 'Vegetables',
      foodName: 'Tomato (Kamatis, raw)',
      normalizedName: 'tomato kamatis raw',
      isLocalFood: true,
      isOfficial: true,
      servingId: 'local-food-tomato-raw-serving',
      servingLabel: '1 medium tomato (123g)',
      servingGrams: 123,
      calories: 22,
      proteinG: 1.1,
      carbsG: 4.8,
      fatG: 0.2,
      estimatedPricePhp: 10,
      mealTypeCodes: ['breakfast', 'lunch', 'dinner', 'snack'],
      syncStatus: 'synced',
      createdAt: '2026-09-21T00:00:00Z',
      updatedAt: '2026-09-21T00:00:00Z',
    );

    Food? selectedFood;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isOnlineProvider.overrideWithValue(true)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => FoodSearchSheet(
                        onFoodSelected: (food) => selectedFood = food,
                        searchFoods: (query, mealType) async {
                          expect(query, 'tomato');
                          expect(mealType, 'lunch');
                          return [tomato];
                        },
                      ),
                    );
                  },
                  child: const Text('Open food search'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open food search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tomato');
    await tester.pumpAndSettle();

    expect(find.text('Search Results'), findsOneWidget);
    expect(find.text('Tomato (Kamatis, raw)'), findsOneWidget);
    expect(find.text('1 results'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(find.text('Tomato (Kamatis, raw)'), findsOneWidget);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    expect(selectedFood?.foodId, tomato.foodId);
  });
}
