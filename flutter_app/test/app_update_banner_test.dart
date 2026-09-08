import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/core/network/app_release.dart';
import 'package:jcg_fitness/core/widgets/app_update_banner.dart';

void main() {
  testWidgets('shows an available release and permits dismissal',
      (tester) async {
    final release = AppRelease(
        '1.0.2',
        3,
        100,
        Uri.parse(
            'https://github.com/keikoocatalasan/jcg/releases/download/v1.0.2/JCG-Fitness.apk'),
        Uri.parse(
            'https://github.com/keikoocatalasan/jcg/releases/tag/v1.0.2'));
    await tester.pumpWidget(ProviderScope(overrides: [
      availableAppUpdateProvider.overrideWith((ref) async => release),
    ], child: const MaterialApp(home: Scaffold(body: AppUpdateBanner()))));
    await tester.pumpAndSettle();
    expect(find.text('JCG Fitness 1.0.2 is available'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pump();
    expect(find.text('JCG Fitness 1.0.2 is available'), findsNothing);
  });
  testWidgets('does not show an update when none is available', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      availableAppUpdateProvider.overrideWith((ref) async => null),
    ], child: const MaterialApp(home: Scaffold(body: AppUpdateBanner()))));
    await tester.pumpAndSettle();
    expect(find.text('View update'), findsNothing);
  });
}
