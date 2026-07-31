import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _numberFormat = NumberFormat('#,##0.00');
  static final _caloriesFormat = NumberFormat('#,##0');

  static String formatPhp(double value) => '₱${_numberFormat.format(value)}';

  static String formatCalories(double value) =>
      '${_caloriesFormat.format(value)} kcal';

  static String formatMacro(double value) => '${value.toStringAsFixed(1)}g';

  static String formatWeight(double value) => '${value.toStringAsFixed(1)} kg';

  static String formatWater(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)} L';
    }
    return '$value ml';
  }

  static String formatPercent(double value) => '${value.toStringAsFixed(0)}%';

  static String formatCount(int value) => _caloriesFormat.format(value);
}
