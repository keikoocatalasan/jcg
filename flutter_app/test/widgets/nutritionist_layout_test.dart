import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/features/admin/screens/admin_nutritionist_applications_screen.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';
import 'package:jcg_fitness/features/nutritionist/screens/nutritionist_application_screen.dart';
import 'package:jcg_fitness/features/nutritionist/widgets/nutritionist_dashboard_tab.dart';
import 'package:jcg_fitness/features/nutritionist/widgets/nutritionist_food_review_section.dart';
import 'package:jcg_fitness/features/nutritionist/widgets/nutritionist_history_tab.dart';
import 'package:jcg_fitness/features/nutritionist/widgets/nutritionist_profile_tab.dart';
import 'package:jcg_fitness/features/nutritionist/widgets/nutritionist_reports_tab.dart';

const _narrow = Size(320, 640);

NutritionistApplication _application({
  String status = 'pending',
  String credentialName = 'Juan Miguel Dela Cruz-Nutritionist',
  String licenseNumber = 'PRC-09814814-LICENSED',
}) {
  return NutritionistApplication(
    applicationId: 'application-1',
    userId: 'user-1',
    credentialName: credentialName,
    licenseNumber: licenseNumber,
    credentialDocumentPath: 'auth-user/long-credential-file-name.jpg',
    profession: 'Nutritionist-Dietitian',
    prcLicenseExpirationDate: DateTime(2030, 9, 26),
    status: status,
    submittedAt: DateTime.utc(2026, 9, 22),
    reviewedAt: status == 'pending' ? null : DateTime.utc(2026, 9, 22),
    reviewNote: null,
    rejectionReason: null,
    suspensionReason: null,
    revalidationRequired: false,
  );
}

NutritionistCatalogEntry _catalogEntry() {
  return const NutritionistCatalogEntry(
    foodId: 'food-1',
    foodName: 'Chicken Adobo with Rice and Boiled Egg (Extra Large Serving)',
    categoryName: 'Prepared Filipino Dishes',
    servingId: 'serving-1',
    servingLabel: '1 cup, cooked',
    servingGrams: 150,
    calories: 360,
    proteinG: 30,
    carbsG: 12,
    fatG: 18,
    verificationStatus: 'needs_revision',
    sourceType: 'philfct',
    sourceName:
        'DOST-FNRI Philippine Food Composition Tables 2024 Online Edition',
    sourceCheckedAt: null,
    verifiedAt: null,
  );
}

NutritionistDashboardKpis _kpis() {
  return const NutritionistDashboardKpis(
    unreviewed: 1234,
    inReview: 12,
    verified: 999,
    needsRevision: 57,
    rejected: 8,
    openReports: 23,
    myReviewsThisWeek: 100,
    credentialExpiresOn: null,
    credentialExpired: false,
    revalidationRequired: true,
  );
}

NutritionistActionEntry _actionEntry() {
  return NutritionistActionEntry(
    action: 'review_needs_revision',
    entityType: 'food_nutrition_profile',
    entityId: 'profile-1',
    reason:
        'The recorded calories do not match the referenced source after per-100 g normalization.',
    newValues: const {'calories_per_100g': 240},
    createdAt: DateTime.utc(2026, 9, 22),
  );
}

FoodReport _report() {
  return FoodReport(
    reportId: 'report-1',
    foodId: 'food-1',
    foodName: 'Chicken Adobo with Rice and Boiled Egg (Extra Large Serving)',
    issueType: 'incorrect_nutrition',
    description: 'Calories and protein look inconsistent.',
    status: 'in_review',
    resolutionNote: null,
    createdAt: DateTime.utc(2026, 9, 22),
    resolvedAt: null,
  );
}

Food _food() {
  return const Food(
    foodId: 'food-1',
    categoryName: 'Prepared Filipino Dishes',
    foodName: 'Chicken Adobo with Rice and Boiled Egg',
    normalizedName: 'chicken adobo with rice and boiled egg',
    isOfficial: true,
    servingId: 'serving-1',
    servingLabel: '1 cup',
    servingGrams: 150,
    calories: 360,
    proteinG: 30,
    carbsG: 12,
    fatG: 18,
    estimatedPricePhp: 0,
    createdAt: '2026-09-22T00:00:00Z',
    updatedAt: '2026-09-22T00:00:00Z',
  );
}

Widget _host(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      builder: (context, materialChild) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: materialChild!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

void _useNarrowScreen(WidgetTester tester) {
  tester.view.physicalSize = _narrow;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('dashboard tab fits a narrow screen with large counts',
      (tester) async {
    _useNarrowScreen(tester);
    await tester.pumpWidget(
      _host(
        const NutritionistDashboardTab(),
        overrides: [
          nutritionistDashboardProvider.overrideWith((ref) async => _kpis()),
          nutritionistCatalogProvider.overrideWith(
            (ref, query) async => [_catalogEntry()],
          ),
          nutritionistHistoryProvider
              .overrideWith((ref) async => [_actionEntry()]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unreviewed'), findsOneWidget);
  });

  testWidgets('reports tab fits a narrow screen with long food names',
      (tester) async {
    _useNarrowScreen(tester);
    await tester.pumpWidget(
      _host(
        const NutritionistReportsTab(),
        overrides: [
          nutritionistReportsProvider
              .overrideWith((ref, status) async => [_report()]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('IN REVIEW'), findsOneWidget);
  });

  testWidgets('history tab fits a narrow screen with long reasons',
      (tester) async {
    _useNarrowScreen(tester);
    await tester.pumpWidget(
      _host(
        const NutritionistHistoryTab(),
        overrides: [
          nutritionistHistoryProvider
              .overrideWith((ref) async => [_actionEntry()]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Requested revision'), findsOneWidget);
  });

  testWidgets('profile tab fits a narrow screen', (tester) async {
    _useNarrowScreen(tester);
    await tester.pumpWidget(
      _host(
        const NutritionistProfileTab(),
        overrides: [
          nutritionistApplicationProvider
              .overrideWith((ref) async => _application(status: 'verified')),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open food tracking'), findsOneWidget);
  });

  testWidgets('verification form fits a narrow screen', (tester) async {
    _useNarrowScreen(tester);
    await tester.pumpWidget(
      _host(
        const NutritionistApplicationScreen(),
        overrides: [
          nutritionistApplicationProvider.overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Upload your PRC ID / credential'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Upload your PRC ID / credential'), findsOneWidget);
  });

  testWidgets('admin queue fits a narrow screen with long credentials',
      (tester) async {
    _useNarrowScreen(tester);
    await tester.pumpWidget(
      _host(
        const AdminNutritionistApplicationsScreen(),
        overrides: [
          adminNutritionistApplicationsProvider
              .overrideWith((ref) async => [_application()]),
          nutritionistCredentialSignedUrlProvider.overrideWith(
            (ref, path) async => 'https://example.invalid/credential.jpg',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Verify nutritionist'), findsOneWidget);
  });

  testWidgets('food detail verification card fits a narrow screen',
      (tester) async {
    _useNarrowScreen(tester);
    await tester.pumpWidget(
      _host(
        SingleChildScrollView(
          child: NutritionistFoodReviewSection(food: _food(), isOnline: true),
        ),
        overrides: [
          verifiedNutritionistProvider.overrideWith((ref) async => true),
          foodVerificationProvider
              .overrideWith((ref, foodServing) async => _catalogEntry()),
          foodNutritionistReviewsProvider.overrideWith(
            (ref, foodServing) async => [
              FoodNutritionistReview(
                reviewId: 'review-1',
                servingAssessment: null,
                macroAssessment: null,
                comment: null,
                decision: 'needs_revision',
                reviewNote:
                    'The recorded calories do not match the referenced source after per-100 g normalization.',
                sourceType: 'philfct',
                sourceName: 'PhilFCT',
                updatedAt: DateTime.utc(2026, 9, 22),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open review'), findsOneWidget);
  });
}
