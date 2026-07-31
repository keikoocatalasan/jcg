import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/app/app_colors.dart';

void main() {
  group('semantic color contrast', () {
    test('light body text pairings meet WCAG AA', () {
      const colors = AppSemanticColors.light;
      _expectBodyContrast('primary text / background', colors.textPrimary,
          colors.background, 8.24);
      _expectBodyContrast(
          'primary text / surface', colors.textPrimary, colors.surface, 8.78);
      _expectBodyContrast('primary text / tinted layer', colors.textPrimary,
          colors.backgroundAlt, 7.18);
      _expectBodyContrast('secondary text / surface', colors.textSecondary,
          colors.surface, 6.87);
      _expectBodyContrast(
          'primary action label', colors.onPrimary, colors.primary, 7.57);
      _expectBodyContrast('error label', colors.onError, colors.error, 7.53);
    });

    test('dark body text pairings meet WCAG AA', () {
      const colors = AppSemanticColors.dark;
      _expectBodyContrast('primary text / background', colors.textPrimary,
          colors.background, 8.78);
      _expectBodyContrast('secondary text / background', colors.textSecondary,
          colors.background, 7.18);
      _expectBodyContrast(
          'primary action label', colors.onPrimary, colors.primary, 7.57);
      _expectBodyContrast('error label', colors.onError, colors.error, 8.90);
    });

    test('interactive icon pairings meet the 3:1 threshold', () {
      const light = AppSemanticColors.light;
      const dark = AppSemanticColors.dark;
      _expectIconContrast('light primary icon', light.onPrimary, light.primary);
      _expectIconContrast('dark primary icon', dark.onPrimary, dark.primary);
      _expectIconContrast(
          'light secondary icon', light.textSecondary, light.surface);
      _expectIconContrast(
          'dark secondary icon', dark.textSecondary, dark.background);
    });
  });
}

void _expectBodyContrast(
  String pairing,
  Color foreground,
  Color background,
  double documentedRatio,
) {
  final ratio = _contrastRatio(foreground, background);
  expect(ratio, greaterThanOrEqualTo(4.5), reason: pairing);
  expect(ratio, closeTo(documentedRatio, 0.02),
      reason: '$pairing documentation drifted');
}

void _expectIconContrast(String pairing, Color foreground, Color background) {
  expect(_contrastRatio(foreground, background), greaterThanOrEqualTo(3),
      reason: pairing);
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
