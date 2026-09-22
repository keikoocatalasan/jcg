import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const nutritionistCredentialBucket = 'nutritionist-credentials-private';

class NutritionistApplication {
  final String applicationId;
  final String userId;
  final String credentialName;
  final String licenseNumber;
  final String credentialDocumentPath;
  final String status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewNote;

  const NutritionistApplication({
    required this.applicationId,
    required this.userId,
    required this.credentialName,
    required this.licenseNumber,
    required this.credentialDocumentPath,
    required this.status,
    required this.submittedAt,
    required this.reviewedAt,
    required this.reviewNote,
  });

  factory NutritionistApplication.fromMap(Map<String, dynamic> map) {
    return NutritionistApplication(
      applicationId: map['application_id'] as String,
      userId: map['user_id'] as String,
      credentialName: map['credential_name'] as String,
      licenseNumber: map['license_number'] as String,
      credentialDocumentPath: map['credential_document_path'] as String,
      status: map['status'] as String? ?? 'pending',
      submittedAt: DateTime.tryParse(map['submitted_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: DateTime.tryParse(map['reviewed_at'] as String? ?? ''),
      reviewNote: map['review_note'] as String?,
    );
  }
}

class FoodNutritionistReview {
  final String reviewId;
  final String servingAssessment;
  final String macroAssessment;
  final String? comment;
  final DateTime updatedAt;

  const FoodNutritionistReview({
    required this.reviewId,
    required this.servingAssessment,
    required this.macroAssessment,
    required this.comment,
    required this.updatedAt,
  });

  factory FoodNutritionistReview.fromMap(Map<String, dynamic> map) {
    return FoodNutritionistReview(
      reviewId: map['review_id'] as String,
      servingAssessment: map['serving_assessment'] as String,
      macroAssessment: map['macro_assessment'] as String,
      comment: map['comment'] as String?,
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class NutritionistService {
  final SupabaseClient _supabase;

  const NutritionistService(this._supabase);

  Future<String?> _currentAppUserId() async {
    final authUserId = _supabase.auth.currentUser?.id;
    if (authUserId == null) return null;
    final row = await _supabase
        .from('app_user')
        .select('user_id')
        .eq('auth_user_id', authUserId)
        .maybeSingle();
    return row?['user_id'] as String?;
  }

  Future<NutritionistApplication?> getMyApplication() async {
    if (AppConfig.isLocalTestMode) return null;
    final userId = await _currentAppUserId();
    if (userId == null) return null;
    final row = await _supabase
        .from('nutritionist_application')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null
        ? null
        : NutritionistApplication.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> submitApplication({
    required String credentialName,
    required String licenseNumber,
    required Uint8List documentBytes,
    required String mimeType,
    required String fileExtension,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Sign in before applying.');
    if (documentBytes.isEmpty) throw StateError('Choose a credential image.');
    if (documentBytes.length > 5 * 1024 * 1024) {
      throw StateError('The credential image must be 5 MB or smaller.');
    }

    final previous = await getMyApplication();
    final documentPath = '${user.id}/${const Uuid().v4()}.$fileExtension';
    await _supabase.storage.from(nutritionistCredentialBucket).uploadBinary(
          documentPath,
          documentBytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            cacheControl: '3600',
            upsert: false,
          ),
        );

    try {
      await _supabase.rpc(
        'submit_nutritionist_application',
        params: {
          'p_credential_name': credentialName.trim(),
          'p_license_number': licenseNumber.trim(),
          'p_credential_document_path': documentPath,
        },
      );
    } catch (_) {
      try {
        await _supabase.storage
            .from(nutritionistCredentialBucket)
            .remove([documentPath]);
      } catch (_) {
        // A failed cleanup leaves a private orphan, never a public credential.
      }
      rethrow;
    }

    final oldPath = previous?.credentialDocumentPath;
    if (oldPath != null && oldPath != documentPath) {
      try {
        await _supabase.storage
            .from(nutritionistCredentialBucket)
            .remove([oldPath]);
      } catch (_) {
        // Do not turn a successful resubmission into a reported failure.
      }
    }
  }

  Future<List<NutritionistApplication>> getApplicationsForAdmin() async {
    if (AppConfig.isLocalTestMode) return const [];
    final rows = await _supabase
        .from('nutritionist_application')
        .select()
        .order('submitted_at', ascending: false);
    return rows
        .map((row) =>
            NutritionistApplication.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> reviewApplication({
    required String applicationId,
    required String decision,
    String? note,
  }) async {
    if (AppConfig.isLocalTestMode) {
      throw StateError('Credential decisions require the connected service.');
    }
    await _supabase.rpc(
      'admin_review_nutritionist_application',
      params: {
        'p_application_id': applicationId,
        'p_decision': decision,
        'p_review_note': note,
      },
    );
  }

  Future<String> getCredentialSignedUrl(String path) {
    return _supabase.storage
        .from(nutritionistCredentialBucket)
        .createSignedUrl(path, 300);
  }

  Future<List<FoodNutritionistReview>> getFoodReviews({
    required String foodId,
    required String servingId,
  }) async {
    if (AppConfig.isLocalTestMode || _supabase.auth.currentUser == null) {
      return const [];
    }
    final rows = await _supabase
        .from('food_nutritionist_review')
        .select(
          'review_id, serving_assessment, macro_assessment, comment, updated_at, '
          'nutrition_profile:food_nutrition_profile!inner(is_active, effective_to)',
        )
        .eq('food_id', foodId)
        .eq('serving_id', servingId)
        .eq('nutrition_profile.is_active', true)
        .isFilter('nutrition_profile.effective_to', null)
        .order('updated_at', ascending: false)
        .limit(5);
    return rows
        .map((row) =>
            FoodNutritionistReview.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> submitFoodReview({
    required String foodId,
    required String servingId,
    required String servingAssessment,
    required String macroAssessment,
    String? comment,
  }) async {
    await _supabase.rpc(
      'submit_food_nutritionist_review',
      params: {
        'p_food_id': foodId,
        'p_serving_id': servingId,
        'p_serving_assessment': servingAssessment,
        'p_macro_assessment': macroAssessment,
        'p_comment': comment,
      },
    );
  }
}

final nutritionistServiceProvider = Provider<NutritionistService>((ref) {
  return NutritionistService(ref.read(supabaseClientProvider));
});

final nutritionistApplicationProvider =
    FutureProvider<NutritionistApplication?>((ref) async {
  if (AppConfig.isLocalTestMode) return null;
  return ref.read(nutritionistServiceProvider).getMyApplication();
});

final approvedNutritionistProvider = FutureProvider<bool>((ref) async {
  final application = await ref.watch(nutritionistApplicationProvider.future);
  return application?.status == 'approved';
});

final adminNutritionistApplicationsProvider =
    FutureProvider<List<NutritionistApplication>>((ref) async {
  if (AppConfig.isLocalTestMode) return const [];
  return ref.read(nutritionistServiceProvider).getApplicationsForAdmin();
});

final nutritionistCredentialSignedUrlProvider =
    FutureProvider.family<String, String>((ref, path) {
  return ref.read(nutritionistServiceProvider).getCredentialSignedUrl(path);
});

final foodNutritionistReviewsProvider =
    FutureProvider.family<List<FoodNutritionistReview>, (String, String)>(
        (ref, foodServing) async {
  if (AppConfig.isLocalTestMode) return const [];
  return ref.read(nutritionistServiceProvider).getFoodReviews(
        foodId: foodServing.$1,
        servingId: foodServing.$2,
      );
});
