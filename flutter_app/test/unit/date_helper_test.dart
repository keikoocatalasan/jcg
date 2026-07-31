import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';

void main() {
  group('nowUtc', () {
    test('returns ISO 8601 UTC string', () {
      final result = DateHelper.nowUtc();
      expect(result.endsWith('Z'), true);
      expect(DateTime.tryParse(result), isNotNull);
    });
  });

  group('todayDate', () {
    test('returns yyyy-MM-dd format', () {
      final result = DateHelper.todayDate();
      expect(result, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });
  });

  group('parseDate', () {
    test('parses valid ISO date string', () {
      final result = DateHelper.parseDate('2026-06-13');
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 6);
      expect(result.day, 13);
    });

    test('parses ISO datetime string', () {
      final result = DateHelper.parseDate('2026-06-13T10:30:00Z');
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 6);
    });

    test('returns null for invalid input', () {
      expect(DateHelper.parseDate('not-a-date'), isNull);
    });

    test('returns null for empty string', () {
      expect(DateHelper.parseDate(''), isNull);
    });
  });

  group('formatDateTime', () {
    test('formats ISO string to readable datetime', () {
      final result = DateHelper.formatDateTime('2026-06-13T14:30:00');
      expect(result, contains('Jun'));
      expect(result, contains('13'));
      expect(result, contains('2026'));
      expect(result, contains('2:30'));
      expect(result, contains('PM'));
    });

    test('returns original string on parse failure', () {
      expect(DateHelper.formatDateTime('bad-date'), 'bad-date');
    });
  });

  group('formatDate', () {
    test('formats ISO string to readable date', () {
      final result = DateHelper.formatDate('2026-06-13');
      expect(result, contains('Jun'));
      expect(result, contains('13'));
      expect(result, contains('2026'));
    });

    test('returns original string on parse failure', () {
      expect(DateHelper.formatDate('bad-date'), 'bad-date');
    });
  });

  group('formatTime', () {
    test('formats ISO string to readable time', () {
      final result = DateHelper.formatTime('2026-06-13T08:05:00');
      expect(result, contains('8:05'));
      expect(result, contains('AM'));
    });

    test('formats afternoon time correctly', () {
      final result = DateHelper.formatTime('2026-06-13T15:45:00');
      expect(result, contains('3:45'));
      expect(result, contains('PM'));
    });

    test('returns original string on parse failure', () {
      expect(DateHelper.formatTime('bad-date'), 'bad-date');
    });
  });

  group('daysBetween', () {
    test('same day returns 0', () {
      expect(DateHelper.daysBetween('2026-06-13', '2026-06-13'), 0);
    });

    test('1 day apart returns 1', () {
      expect(DateHelper.daysBetween('2026-06-13', '2026-06-14'), 1);
    });

    test('7 days apart returns 7', () {
      expect(DateHelper.daysBetween('2026-06-13', '2026-06-20'), 7);
    });

    test('reverse order returns absolute value', () {
      expect(DateHelper.daysBetween('2026-06-20', '2026-06-13'), 7);
    });

    test('invalid start returns 0', () {
      expect(DateHelper.daysBetween('bad', '2026-06-13'), 0);
    });

    test('invalid end returns 0', () {
      expect(DateHelper.daysBetween('2026-06-13', 'bad'), 0);
    });
  });

  group('weekStart', () {
    test('returns Monday of the same week', () {
      // 2026-06-13 is a Saturday
      final result = DateHelper.weekStart('2026-06-13');
      // Monday of that week is 2026-06-08
      expect(result, '2026-06-08');
    });

    test('Monday itself returns itself', () {
      // 2026-06-08 is a Monday
      final result = DateHelper.weekStart('2026-06-08');
      expect(result, '2026-06-08');
    });

    test('Sunday returns previous Monday', () {
      // 2026-06-14 is a Sunday
      final result = DateHelper.weekStart('2026-06-14');
      expect(result, '2026-06-08');
    });

    test('invalid date returns original', () {
      expect(DateHelper.weekStart('bad-date'), 'bad-date');
    });
  });

  group('weekEnd', () {
    test('returns Sunday of the same week', () {
      // 2026-06-13 is a Saturday
      final result = DateHelper.weekEnd('2026-06-13');
      // Sunday of that week is 2026-06-14
      expect(result, '2026-06-14');
    });

    test('Monday returns Sunday of same week', () {
      // 2026-06-08 is a Monday
      final result = DateHelper.weekEnd('2026-06-08');
      expect(result, '2026-06-14');
    });

    test('Sunday returns itself', () {
      final result = DateHelper.weekEnd('2026-06-14');
      expect(result, '2026-06-14');
    });

    test('invalid date returns original', () {
      expect(DateHelper.weekEnd('bad-date'), 'bad-date');
    });
  });
}
