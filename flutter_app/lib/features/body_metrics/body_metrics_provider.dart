import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/features/body_metrics/bmi_calculator.dart';
import 'package:jcg_fitness/features/profile_settings/profile_provider.dart';
import 'package:jcg_fitness/features/weight_tracking/weight_provider.dart';

/// Current BMI uses the newest locally available weigh-in, falling back to the
/// profile's current weight when an account has no weight-log entry yet.
final bodyMetricsProvider = FutureProvider<BmiResult?>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return null;

  final latestWeight = await ref.watch(latestWeightProvider.future);
  final profileWeight = latestWeight == null;
  final weightKg = latestWeight?.weightKg ?? profile.currentWeightKg;
  final heightCm = profile.heightCm;
  if (weightKg == null || heightCm == null) return null;

  return BmiCalculator.calculate(
    weightKg: weightKg,
    heightCm: heightCm,
    ageYears: profile.age,
    measuredAt: latestWeight?.loggedAt,
    usedProfileWeight: profileWeight,
  );
});
