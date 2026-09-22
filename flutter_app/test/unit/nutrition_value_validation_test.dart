import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

void main() {
  test('plausible values produce no warnings', () {
    final warnings = assessPer100gValues(
      calories: 240,
      protein: 20,
      carbs: 10,
      fat: 14,
    );
    expect(warnings, isEmpty);
  });

  test('negative or non-finite values produce a severe warning', () {
    final warnings = assessPer100gValues(
      calories: 240,
      protein: -1,
      carbs: 10,
      fat: 14,
    );
    expect(warnings, hasLength(1));
    expect(warnings.first.message, contains('zero or greater'));
  });

  test('macro grams above 100 g per 100 g are flagged', () {
    final warnings = assessPer100gValues(
      calories: 400,
      protein: 60,
      carbs: 40,
      fat: 30,
    );
    expect(
      warnings.any((warning) => warning.message.contains('exceed 100 g')),
      isTrue,
    );
  });

  test('energy mismatch above 35 percent is flagged', () {
    final warnings = assessPer100gValues(
      calories: 500,
      protein: 5,
      carbs: 5,
      fat: 5,
    );
    expect(
      warnings.any((warning) => warning.message.contains('4/4/9')),
      isTrue,
    );
  });

  test('zero calories does not trigger an energy warning', () {
    final warnings = assessPer100gValues(
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
    );
    expect(warnings, isEmpty);
  });
}
