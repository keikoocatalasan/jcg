import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

void main() {
  test('maps application review status and credential details', () {
    final application = NutritionistApplication.fromMap({
      'application_id': 'application-1',
      'user_id': 'user-1',
      'credential_name': 'Sample Dietitian',
      'license_number': 'RND-12345',
      'credential_document_path': 'auth-user/document.jpg',
      'profession': 'Nutritionist-Dietitian',
      'prc_license_expiration_date': '2030-01-31',
      'status': 'pending',
      'submitted_at': '2026-09-21T01:00:00Z',
      'reviewed_at': null,
      'review_note': null,
      'rejection_reason': null,
      'suspension_reason': null,
      'revalidation_required': false,
    });

    expect(application.applicationId, 'application-1');
    expect(application.credentialName, 'Sample Dietitian');
    expect(application.status, 'pending');
    expect(application.isVerified, isFalse);
    expect(application.prcLicenseExpirationDate, DateTime(2030, 1, 31));
    expect(application.isExpired, isFalse);
    expect(application.reviewedAt, isNull);
  });

  test('verified application with past expiration is treated as expired', () {
    final application = NutritionistApplication.fromMap({
      'application_id': 'application-2',
      'user_id': 'user-1',
      'credential_name': 'Sample Dietitian',
      'license_number': 'RND-12345',
      'credential_document_path': 'auth-user/document.jpg',
      'profession': 'Nutritionist-Dietitian',
      'prc_license_expiration_date': '2020-01-01',
      'status': 'verified',
      'submitted_at': '2026-09-21T01:00:00Z',
      'reviewed_at': '2026-09-21T02:00:00Z',
      'review_note': null,
      'rejection_reason': null,
      'suspension_reason': null,
      'revalidation_required': false,
    });

    expect(application.isVerified, isTrue);
    expect(application.isExpired, isTrue);
  });

  test('maps food serving and macro feedback independently', () {
    final review = FoodNutritionistReview.fromMap({
      'review_id': 'review-1',
      'serving_assessment': 'watch_portion',
      'macro_assessment': 'needs_recheck',
      'comment': 'Please verify the listed portion.',
      'decision': null,
      'review_note': null,
      'source_type': null,
      'source_name': null,
      'updated_at': '2026-09-21T01:00:00Z',
    });

    expect(review.servingAssessment, 'watch_portion');
    expect(review.macroAssessment, 'needs_recheck');
    expect(review.comment, contains('portion'));
    expect(review.isLegacy, isTrue);
  });

  test('maps verification decision reviews as non-legacy', () {
    final review = FoodNutritionistReview.fromMap({
      'review_id': 'review-2',
      'serving_assessment': null,
      'macro_assessment': null,
      'comment': null,
      'decision': 'verified',
      'review_note': 'Checked against PhilFCT.',
      'source_type': 'philfct',
      'source_name': 'PhilFCT',
      'updated_at': '2026-09-21T01:00:00Z',
    });

    expect(review.decision, 'verified');
    expect(review.reviewNote, 'Checked against PhilFCT.');
    expect(review.isLegacy, isFalse);
  });

  test('catalog entry derives per-100 g values from the serving', () {
    final entry = NutritionistCatalogEntry.fromMap({
      'food_id': 'food-1',
      'food_name': 'Chicken Adobo',
      'category_name': 'Meat',
      'serving_id': 'serving-1',
      'serving_label': '1 cup',
      'serving_grams': 150,
      'calories': 360,
      'protein_g': 30,
      'carbs_g': 12,
      'fat_g': 18,
      'verification_status': 'verified',
      'verified_at': '2026-09-21T01:00:00Z',
      'nutrition_source_type': 'philfct',
      'nutrition_source_name': 'PhilFCT',
      'source_checked_at': '2026-09-20',
    });

    expect(entry.caloriesPer100g, closeTo(240, 0.01));
    expect(entry.proteinPer100g, closeTo(20, 0.01));
    expect(entry.verificationLabel, 'Nutrition data verified');
    expect(entry.sourceType, 'philfct');
  });

  test('maps dashboard kpis including credential warnings', () {
    final kpis = NutritionistDashboardKpis.fromJson({
      'unreviewed': 12,
      'in_review': 3,
      'verified': 40,
      'needs_revision': 2,
      'rejected': 1,
      'open_reports': 4,
      'my_reviews_7d': 6,
      'credential_expires_on': '2027-01-31',
      'credential_expired': false,
      'revalidation_required': true,
    });

    expect(kpis.unreviewed, 12);
    expect(kpis.verified, 40);
    expect(kpis.openReports, 4);
    expect(kpis.myReviewsThisWeek, 6);
    expect(kpis.credentialExpiresOn, DateTime(2027, 1, 31));
    expect(kpis.credentialExpired, isFalse);
    expect(kpis.revalidationRequired, isTrue);
  });

  test('maps food reports without exposing reporter details', () {
    final report = FoodReport.fromMap({
      'report_id': 'report-1',
      'food_id': 'food-1',
      'issue_type': 'incorrect_nutrition',
      'description': 'Calories look too low.',
      'status': 'open',
      'resolution_note': null,
      'created_at': '2026-09-21T01:00:00Z',
      'resolved_at': null,
      'food': {'food_name': 'Chicken Adobo'},
    });

    expect(report.foodName, 'Chicken Adobo');
    expect(report.issueLabel, 'Incorrect calories/macros');
    expect(report.status, 'open');
  });

  test('maps nutritionist action history entries', () {
    final entry = NutritionistActionEntry.fromMap({
      'action': 'review_verified',
      'entity_type': 'food_nutrition_profile',
      'entity_id': 'profile-1',
      'reason': 'Checked against PhilFCT.',
      'new_values': {'calories_per_100g': 240},
      'created_at': '2026-09-21T01:00:00Z',
    });

    expect(entry.action, 'review_verified');
    expect(entry.entityId, 'profile-1');
    expect(entry.newValues?['calories_per_100g'], 240);
  });
}
