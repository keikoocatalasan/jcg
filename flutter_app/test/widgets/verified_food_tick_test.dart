import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/food_database/food_provider.dart';
import 'package:jcg_fitness/features/food_database/widgets/verified_food_tick.dart';

Widget _host(String? foodId, {Set<String> verified = const {'food-1'}}) {
  return ProviderScope(
    overrides: [
      verifiedFoodIdsProvider.overrideWith((ref) async => verified),
    ],
    child: MaterialApp(
      home: Scaffold(body: VerifiedFoodTick(foodId: foodId)),
    ),
  );
}

void main() {
  testWidgets('shows the tick for a verified food id', (tester) async {
    await tester.pumpWidget(_host('food-1'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });

  testWidgets('hides the tick for an unverified food id', (tester) async {
    await tester.pumpWidget(_host('food-2'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });

  testWidgets('hides the tick when no food is linked', (tester) async {
    await tester.pumpWidget(_host(null));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });
}
