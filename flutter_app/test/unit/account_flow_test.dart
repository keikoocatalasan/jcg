import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/auth/account_flow_provider.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

NutritionistApplication application({
  String status = 'pending',
  DateTime? expiration,
  bool revalidationRequired = false,
}) {
  return NutritionistApplication(
    applicationId: 'application-1',
    userId: 'user-1',
    credentialName: 'Sample Dietitian',
    licenseNumber: 'RND-12345',
    credentialDocumentPath: 'auth-user/credential.jpg',
    profession: 'Nutritionist-Dietitian',
    prcLicenseExpirationDate: expiration ?? DateTime(2030, 1, 31),
    status: status,
    submittedAt: DateTime.utc(2026, 9, 22),
    reviewedAt: status == 'pending' ? null : DateTime.utc(2026, 9, 22),
    reviewNote: null,
    rejectionReason: null,
    suspensionReason: null,
    revalidationRequired: revalidationRequired,
  );
}

void main() {
  test('no intent and no application stays in the consumer flow', () {
    expect(
      resolveNutritionistLanding(hasIntent: false, application: null),
      NutritionistLanding.none,
    );
  });

  test('intent without an application lands on the application step', () {
    expect(
      resolveNutritionistLanding(hasIntent: true, application: null),
      NutritionistLanding.application,
    );
  });

  test('pending, rejected, and suspended applications land on the status step',
      () {
    for (final status in ['pending', 'rejected', 'suspended']) {
      expect(
        resolveNutritionistLanding(
          hasIntent: true,
          application: application(status: status),
        ),
        NutritionistLanding.application,
        reason: status,
      );
    }
  });

  test('verified with a future expiration lands in the workspace', () {
    expect(
      resolveNutritionistLanding(
        hasIntent: true,
        application: application(status: 'verified'),
      ),
      NutritionistLanding.workspace,
    );
  });

  test('verified with an expired credential falls back to the status step',
      () {
    expect(
      resolveNutritionistLanding(
        hasIntent: true,
        application: application(
          status: 'verified',
          expiration: DateTime(2020, 1, 1),
        ),
      ),
      NutritionistLanding.application,
    );
  });

  test('an existing application routes even without registration intent', () {
    expect(
      resolveNutritionistLanding(
        hasIntent: false,
        application: application(status: 'verified'),
      ),
      NutritionistLanding.workspace,
      reason: 'accounts that applied from settings must keep their flow',
    );
  });

  test('landing routes map to the dedicated screens', () {
    expect(landingRoute(NutritionistLanding.workspace), '/nutritionist');
    expect(
      landingRoute(NutritionistLanding.application),
      '/nutritionist-application',
    );
  });
}
