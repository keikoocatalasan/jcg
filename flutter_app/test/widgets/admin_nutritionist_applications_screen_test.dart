import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/admin/screens/admin_nutritionist_applications_screen.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

NutritionistApplication sampleApplication(
  String status, {
  DateTime? expiration,
}) =>
    NutritionistApplication(
      applicationId: 'application-1',
      userId: 'user-1',
      credentialName: 'Sample Nutritionist',
      licenseNumber: 'RD-12345',
      credentialDocumentPath: 'auth-user-1/credential.jpg',
      profession: 'Nutritionist-Dietitian',
      prcLicenseExpirationDate: expiration ?? DateTime.utc(2030, 1, 31),
      status: status,
      submittedAt: DateTime.utc(2026, 9, 21),
      reviewedAt: null,
      reviewNote: null,
      rejectionReason: null,
      suspensionReason: null,
      revalidationRequired: false,
    );

void main() {
  testWidgets('admin queue shows a helpful empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminNutritionistApplicationsProvider.overrideWith(
            (ref) async => const <NutritionistApplication>[],
          ),
        ],
        child: const MaterialApp(
          home: AdminNutritionistApplicationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No applications yet'), findsOneWidget);
    expect(find.text('Nutritionist credentials'), findsOneWidget);
  });

  testWidgets('verification is disabled when the private credential cannot load',
      (tester) async {
    final application = sampleApplication('pending');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminNutritionistApplicationsProvider.overrideWith(
            (ref) async => [application],
          ),
          nutritionistCredentialSignedUrlProvider.overrideWith(
            (ref, path) async => throw StateError('credential unavailable'),
          ),
        ],
        child: const MaterialApp(
          home: AdminNutritionistApplicationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final verify = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Verify nutritionist'),
    );
    final reject = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Reject'),
    );
    expect(verify.onPressed, isNull);
    expect(reject.onPressed, isNotNull);
  });

  testWidgets('verified applications offer suspend and hide verification',
      (tester) async {
    final application = sampleApplication('verified');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminNutritionistApplicationsProvider.overrideWith(
            (ref) async => [application],
          ),
          nutritionistCredentialSignedUrlProvider.overrideWith(
            (ref, path) async => 'https://example.invalid/credential.jpg',
          ),
        ],
        child: const MaterialApp(
          home: AdminNutritionistApplicationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('Suspend access'), findsOneWidget);
    expect(find.text('Verify nutritionist'), findsNothing);
  });
}
