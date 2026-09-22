import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/admin/screens/admin_nutritionist_applications_screen.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

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

  testWidgets('approval is disabled when the private credential cannot load',
      (tester) async {
    final application = NutritionistApplication(
      applicationId: 'application-1',
      userId: 'user-1',
      credentialName: 'Sample Nutritionist',
      licenseNumber: 'RD-12345',
      credentialDocumentPath: 'auth-user-1/credential.jpg',
      status: 'pending',
      submittedAt: DateTime.utc(2026, 9, 21),
      reviewedAt: null,
      reviewNote: null,
    );

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

    final approve = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Approve reviewer'),
    );
    final reject = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Reject'),
    );
    expect(approve.onPressed, isNull);
    expect(reject.onPressed, isNotNull);
  });
}
