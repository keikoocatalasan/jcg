import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/weight_tracking/weekly_weight_check_in.dart';

void main() {
  group('isWeeklyWeightCheckInDue', () {
    final now = DateTime.utc(2026, 9, 21, 12);

    test('asks for the first weigh-in when there is no saved weight', () {
      expect(
        isWeeklyWeightCheckInDue(lastLoggedAt: null, now: now),
        isTrue,
      );
    });

    test('does not remind before seven full days have passed', () {
      expect(
        isWeeklyWeightCheckInDue(
          lastLoggedAt: now.subtract(const Duration(days: 6, hours: 23)),
          now: now,
        ),
        isFalse,
      );
    });

    test('reminds at exactly seven days', () {
      expect(
        isWeeklyWeightCheckInDue(
          lastLoggedAt: now.subtract(const Duration(days: 7)),
          now: now,
        ),
        isTrue,
      );
    });

    test('does not remind for a future-dated entry', () {
      expect(
        isWeeklyWeightCheckInDue(
          lastLoggedAt: now.add(const Duration(minutes: 1)),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
