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
      'status': 'pending',
      'submitted_at': '2026-09-21T01:00:00Z',
      'reviewed_at': null,
      'review_note': null,
    });

    expect(application.applicationId, 'application-1');
    expect(application.credentialName, 'Sample Dietitian');
    expect(application.status, 'pending');
    expect(application.reviewedAt, isNull);
  });

  test('maps food serving and macro feedback independently', () {
    final review = FoodNutritionistReview.fromMap({
      'review_id': 'review-1',
      'serving_assessment': 'watch_portion',
      'macro_assessment': 'needs_recheck',
      'comment': 'Please verify the listed portion.',
      'updated_at': '2026-09-21T01:00:00Z',
    });

    expect(review.servingAssessment, 'watch_portion');
    expect(review.macroAssessment, 'needs_recheck');
    expect(review.comment, contains('portion'));
  });
}
