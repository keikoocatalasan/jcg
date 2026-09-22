import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/core/database/weight_log_repository.dart';
import 'package:jcg_fitness/core/models/profile.dart';
import 'package:jcg_fitness/features/body_metrics/body_metrics_provider.dart';
import 'package:jcg_fitness/features/profile_settings/profile_provider.dart';
import 'package:jcg_fitness/features/weight_tracking/weight_provider.dart';

Profile testProfile({
  int? age = 30,
  double? currentWeightKg = 55,
  double? heightCm = 160,
}) =>
    Profile(
      userId: 'local-user',
      authUserId: 'auth-user',
      age: age,
      heightCm: heightCm,
      currentWeightKg: currentWeightKg,
    );

WeightLog testWeight(double kg) => WeightLog(
      weightLogId: 'weight-latest',
      userId: 'local-user',
      weightKg: kg,
      loggedAt: '2026-09-20T10:00:00.000Z',
      createdAt: '2026-09-20T10:00:00.000Z',
      updatedAt: '2026-09-20T10:00:00.000Z',
    );

void main() {
  test('prefers latest weight-log value over the profile fallback', () async {
    final container = ProviderContainer(overrides: [
      profileProvider.overrideWith((ref) async => testProfile()),
      latestWeightProvider.overrideWith((ref) async => testWeight(64)),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(bodyMetricsProvider.future);

    expect(result, isNotNull);
    expect(result!.weightKg, 64);
    expect(result.usedProfileWeight, isFalse);
    expect(result.measuredAt, '2026-09-20T10:00:00.000Z');
    expect(result.bmi, closeTo(25, 0.000001));
  });

  test('falls back to profile weight and withholds teen adult categories',
      () async {
    final container = ProviderContainer(overrides: [
      profileProvider.overrideWith((ref) async => testProfile(age: 17)),
      latestWeightProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(bodyMetricsProvider.future);

    expect(result, isNotNull);
    expect(result!.weightKg, 55);
    expect(result.usedProfileWeight, isTrue);
    expect(result.adultCategory, isNull);
  });

  test('returns no BMI if required profile measurements are missing', () async {
    final incomplete = Profile(
      userId: 'local-user',
      authUserId: 'auth-user',
      age: 30,
      heightCm: null,
      currentWeightKg: 55,
    );
    final container = ProviderContainer(overrides: [
      profileProvider.overrideWith((ref) async => incomplete),
      latestWeightProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(bodyMetricsProvider.future), isNull);
  });

  test('recomputes after latest weight and height providers are refreshed',
      () async {
    var currentHeightCm = 160.0;
    var latestWeightKg = 60.0;
    final container = ProviderContainer(overrides: [
      profileProvider.overrideWith(
        (ref) async => testProfile(heightCm: currentHeightCm),
      ),
      latestWeightProvider.overrideWith(
        (ref) async => testWeight(latestWeightKg),
      ),
    ]);
    addTearDown(container.dispose);

    final initial = await container.read(bodyMetricsProvider.future);
    expect(initial?.bmi, closeTo(23.4375, 0.000001));

    latestWeightKg = 65;
    container.invalidate(latestWeightProvider);
    final afterWeighIn = await container.read(bodyMetricsProvider.future);
    expect(afterWeighIn?.bmi, closeTo(25.390625, 0.000001));

    currentHeightCm = 170;
    container.invalidate(profileProvider);
    final afterHeightEdit = await container.read(bodyMetricsProvider.future);
    expect(afterHeightEdit?.bmi, closeTo(22.49134948, 0.000001));
  });
}
