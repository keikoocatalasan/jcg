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
      profession: 'Nutritionist-Dietitian',
      prcLicenseExpirationDate: DateTime.utc(2030, 1, 31),
      status: status,
      submittedAt: DateTime.utc(2026, 9, 21),
      reviewedAt: status == 'pending' ? null : DateTime.utc(2026, 9, 21),
      reviewNote: null,
      rejectionReason: null,
      suspensionReason: null,
      revalidationRequired: false,
    );

void main() {
  testWidgets('verified applicant sees workspace access status',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionistApplicationProvider.overrideWith(
            (ref) async => sampleApplication('verified'),
          ),
        ],
        child: const MaterialApp(home: NutritionistApplicationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Professional verification complete'), findsOneWidget);
    expect(find.text('Open nutritionist workspace'), findsOneWidget);
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

    expect(find.text('Pending verification'), findsOneWidget);
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

    expect(find.text('Apply to verify food nutrition data'), findsOneWidget);
    expect(find.text('Name shown on credential'), findsOneWidget);
    expect(find.text('PRC license number'), findsOneWidget);
    expect(find.text('PRC license expiration date'), findsOneWidget);
    expect(find.text('Choose credential image'), findsOneWidget);
  });
}
