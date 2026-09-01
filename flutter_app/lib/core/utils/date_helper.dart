import 'package:intl/intl.dart';

class DateHelper {
  DateHelper._();

  static String nowUtc() => DateTime.now().toUtc().toIso8601String();

  static String todayDate() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static DateTime? parseDate(String date) => DateTime.tryParse(date);

  static String formatDateTime(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    return DateFormat('MMM d, yyyy h:mm a').format(dt.toLocal());
  }

  static String formatDate(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    return DateFormat('MMM d, yyyy').format(dt.toLocal());
  }

  static String formatTime(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    return DateFormat('h:mm a').format(dt.toLocal());
  }

  static int daysBetween(String start, String end) {
    final from = DateTime.tryParse(start);
    final to = DateTime.tryParse(end);
    if (from == null || to == null) return 0;
    return to.difference(from).inDays.abs();
  }

  static String weekStart(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    final daysFromMonday = dt.weekday - DateTime.monday;
    final monday = dt.subtract(Duration(days: daysFromMonday));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  static String weekEnd(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    final daysFromMonday = dt.weekday - DateTime.monday;
    final monday = dt.subtract(Duration(days: daysFromMonday));
    final sunday = monday.add(const Duration(days: 6));
    return DateFormat('yyyy-MM-dd').format(sunday);
  }
}
