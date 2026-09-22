import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';
import 'package:jcg_fitness/features/nutritionist/screens/nutritionist_application_screen.dart';

NutritionistApplication sampleApplication(String status) =>
    NutritionistApplication(
      applicationId: 'application-1',
      userId: 'user-1',
      credentialName: 'Sample Dietitian',
      licenseNumber: 'RND-12345',
      credentialDocumentPath: 'auth-user/credential.jpg',
      status: status,
      submittedAt: DateTime.utc(2026, 9, 21),
      reviewedAt: status == 'pending' ? null : DateTime.utc(2026, 9, 21),
      reviewNote: null,
    );

void main() {
  testWidgets('approved applicant sees reviewer access status', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionistApplicationProvider.overrideWith(
            (ref) async => sampleApplication('approved'),
          ),
        ],
        child: const MaterialApp(home: NutritionistApplicationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Application approved'), findsOneWidget);
    expect(
        find.text(
            'You can now submit nutrition reviews on official food entries while online.'),
        findsOneWidget);
  });

  testWidgets('pending application shows wait state instead of resubmission',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionistApplicationProvider.overrideWith(
            (ref) async => sampleApplication('pending'),
          ),
        ],
        child: const MaterialApp(home: NutritionistApplicationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waiting for admin review'), findsOneWidget);
    expect(find.text('Submit for review'), findsNothing);
  });

  testWidgets('new applicant sees the credential application form',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionistApplicationProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: NutritionistApplicationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apply to review food information'), findsOneWidget);
    expect(find.text('Name shown on credential'), findsOneWidget);
    expect(find.text('License or registration number'), findsOneWidget);
    expect(find.text('Choose credential image'), findsOneWidget);
  });
}
