import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/core/widgets/nutrition_verification_badge.dart';

Widget _host(String status, {bool verbose = false}) {
  return MaterialApp(
    home: Scaffold(
      body: NutritionVerificationBadge(status: status, verbose: verbose),
    ),
  );
}

void main() {
  testWidgets('verified shows the positive badge', (tester) async {
    await tester.pumpWidget(_host('verified'));
    expect(find.text('Verified'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });

  testWidgets('verbose verified label is explicit about the reviewer',
      (tester) async {
    await tester.pumpWidget(_host('verified', verbose: true));
    expect(find.text('Nutrition data verified'), findsOneWidget);
  });

  testWidgets('unreviewed is shown as unverified, not hidden',
      (tester) async {
    await tester.pumpWidget(_host('unreviewed'));
    expect(find.text('Unverified'), findsOneWidget);
  });

  testWidgets('needs revision and rejected carry warning states',
      (tester) async {
    await tester.pumpWidget(_host('needs_revision'));
    expect(find.text('Needs revision'), findsOneWidget);

    await tester.pumpWidget(_host('rejected'));
    expect(find.text('Rejected'), findsOneWidget);
  });
}
