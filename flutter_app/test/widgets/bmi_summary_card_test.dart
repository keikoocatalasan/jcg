import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/body_metrics/bmi_calculator.dart';
import 'package:jcg_fitness/features/body_metrics/widgets/bmi_summary_card.dart';

void main() {
  testWidgets('adult result shows category and screening disclaimer',
      (tester) async {
    final result = BmiCalculator.calculate(
      weightKg: 70,
      heightCm: 175,
      ageYears: 30,
      measuredAt: '2026-09-20T10:00:00.000Z',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BmiSummaryCard(result: result)),
    ));

    expect(find.text('Body Mass Index (BMI)'), findsOneWidget);
    expect(find.text('22.9 kg/m²'), findsOneWidget);
    expect(find.text('Adult reference category: Normal range'), findsOneWidget);
    expect(find.byKey(const Key('bmi_disclaimer')), findsOneWidget);
  });

  testWidgets('under-20 result shows no adult category', (tester) async {
    final result = BmiCalculator.calculate(
      weightKg: 55,
      heightCm: 160,
      ageYears: 17,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BmiSummaryCard(result: result)),
    ));

    expect(find.text('21.5 kg/m²'), findsOneWidget);
    expect(find.byKey(const Key('adult_bmi_category')), findsNothing);
    expect(find.byKey(const Key('bmi_youth_note')), findsOneWidget);
  });

  testWidgets('missing measurements show an actionable empty state',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BmiSummaryCard(result: null)),
    ));

    expect(find.text('Add your height and weight to calculate BMI.'),
        findsOneWidget);
  });
}
