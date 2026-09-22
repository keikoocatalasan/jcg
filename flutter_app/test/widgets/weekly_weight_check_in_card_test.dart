import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/weight_tracking/weekly_weight_check_in.dart';

void main() {
  testWidgets('shows the weekly prompt and calls the log action',
      (tester) async {
    var tapped = false;
    final now = DateTime.utc(2026, 9, 21, 12);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyWeightCheckInCard(
            lastLoggedAt: now.subtract(const Duration(days: 7)),
            now: now,
            onLogWeight: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Weekly weight check-in'), findsOneWidget);
    expect(find.textContaining('calorie and macro targets'), findsOneWidget);
    await tester.tap(find.text('Log weight'));
    expect(tapped, isTrue);
  });

  testWidgets('hides the prompt until the full week has passed',
      (tester) async {
    final now = DateTime.utc(2026, 9, 21, 12);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyWeightCheckInCard(
            lastLoggedAt: now.subtract(const Duration(days: 6)),
            now: now,
            onLogWeight: () {},
          ),
        ),
      ),
    );

    expect(find.text('Weekly weight check-in'), findsNothing);
  });

  testWidgets('prompts a new user to enter a first weight', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyWeightCheckInCard(
            lastLoggedAt: null,
            now: DateTime.utc(2026, 9, 21),
            onLogWeight: () {},
          ),
        ),
      ),
    );

    expect(find.text('Start your weight check-ins'), findsOneWidget);
  });
}
