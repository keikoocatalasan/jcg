import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const nutritionistCredentialBucket = 'nutritionist-credentials-private';

const nutritionistProfession = 'Nutritionist-Dietitian';

const nutritionistSourceTypes = <String, String>{
  'philfct': 'DOST-FNRI PhilFCT',
  'manufacturer_label': 'Manufacturer nutrition label',
  'recognized_source': 'Other recognized food-composition source',
  'recipe_estimate': 'Recipe-based estimate',
  'legacy_internal': 'Internal legacy record',
  'unknown': 'Unknown / source missing',
};

const nutritionistIssueTypes = <String, String>{
  'wrong_food': 'Wrong food identified',
  'incorrect_nutrition': 'Incorrect calories/macros',
  'wrong_serving': 'Wrong serving/food data',
  'duplicate_food': 'Duplicate food',
  'missing_food': 'Missing food',
  'other': 'Other food-data issue',
};

const nutritionistVerificationLabels = <String, String>{
  'unreviewed': 'Unreviewed',
  'in_review': 'In review',
  'verified': 'Nutrition data verified',
  'needs_revision': 'Needs revision',
  'rejected': 'Rejected',
  'archived': 'Archived',
};

class NutritionistApplication {
  final String applicationId;
  final String userId;
  final String credentialName;
  final String licenseNumber;
  final String credentialDocumentPath;
  final String profession;
  final DateTime? prcLicenseExpirationDate;
  final String status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final String? rejectionReason;
  final String? suspensionReason;
  final bool revalidationRequired;

  const NutritionistApplication({
    required this.applicationId,
    required this.userId,
    required this.credentialName,
    required this.licenseNumber,
    required this.credentialDocumentPath,
    required this.profession,
    required this.prcLicenseExpirationDate,
    required this.status,
    required this.submittedAt,
    required this.reviewedAt,
    required this.reviewNote,
    required this.rejectionReason,
    required this.suspensionReason,
    required this.revalidationRequired,
  });

  bool get isVerified => status == 'verified';

  bool get isExpired {
    final expiration = prcLicenseExpirationDate;
    if (expiration == null) return false;
    return expiration.isBefore(DateTime.now());
  }

  factory NutritionistApplication.fromMap(Map<String, dynamic> map) {
    return NutritionistApplication(
      applicationId: map['application_id'] as String,
      userId: map['user_id'] as String,
      credentialName: map['credential_name'] as String,
      licenseNumber: map['license_number'] as String,
      credentialDocumentPath: map['credential_document_path'] as String,
      profession: map['profession'] as String? ?? nutritionistProfession,
      prcLicenseExpirationDate: DateTime.tryParse(
          map['prc_license_expiration_date'] as String? ?? ''),
      status: map['status'] as String? ?? 'pending',
      submittedAt: DateTime.tryParse(map['submitted_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: DateTime.tryParse(map['reviewed_at'] as String? ?? ''),
      reviewNote: map['review_note'] as String?,
      rejectionReason: map['rejection_reason'] as String?,
      suspensionReason: map['suspension_reason'] as String?,
      revalidationRequired: map['revalidation_required'] == true,
    );
  }
}

class FoodNutritionistReview {
  final String reviewId;
  final String? servingAssessment;
  final String? macroAssessment;
  final String? comment;
  final String? decision;
  final String? reviewNote;
  final String? sourceType;
  final String? sourceName;
  final DateTime updatedAt;

  const FoodNutritionistReview({
    required this.reviewId,
    required this.servingAssessment,
    required this.macroAssessment,
    required this.comment,
    required this.decision,
    required this.reviewNote,
    required this.sourceType,
    required this.sourceName,
    required this.updatedAt,
  });

  bool get isLegacy => decision == null && servingAssessment != null;

  factory FoodNutritionistReview.fromMap(Map<String, dynamic> map) {
    return FoodNutritionistReview(
      reviewId: map['review_id'] as String,
      servingAssessment: map['serving_assessment'] as String?,
      macroAssessment: map['macro_assessment'] as String?,
      comment: map['comment'] as String?,
      decision: map['decision'] as String?,
      reviewNote: map['review_note'] as String?,
      sourceType: map['source_type'] as String?,
      sourceName: map['source_name'] as String?,
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class NutritionistCatalogEntry {
  final String foodId;
  final String foodName;
  final String categoryName;
  final String servingId;
  final String servingLabel;
  final double servingGrams;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String verificationStatus;
  final String? sourceType;
  final String? sourceName;
  final DateTime? sourceCheckedAt;
  final DateTime? verifiedAt;

  const NutritionistCatalogEntry({
    required this.foodId,
    required this.foodName,
    required this.categoryName,
    required this.servingId,
    required this.servingLabel,
    required this.servingGrams,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.verificationStatus,
    required this.sourceType,
    required this.sourceName,
    required this.sourceCheckedAt,
    required this.verifiedAt,
  });

  double get caloriesPer100g =>
      servingGrams > 0 ? calories / servingGrams * 100 : 0;
  double get proteinPer100g =>
      servingGrams > 0 ? proteinG / servingGrams * 100 : 0;
  double get carbsPer100g => servingGrams > 0 ? carbsG / servingGrams * 100 : 0;
  double get fatPer100g => servingGrams > 0 ? fatG / servingGrams * 100 : 0;

  String get verificationLabel =>
      nutritionistVerificationLabels[verificationStatus] ?? 'Unreviewed';

  factory NutritionistCatalogEntry.fromMap(Map<String, dynamic> map) {
    return NutritionistCatalogEntry(
      foodId: map['food_id'] as String,
      foodName: map['food_name'] as String,
      categoryName: map['category_name'] as String? ?? 'Uncategorized',
      servingId: map['serving_id'] as String,
      servingLabel: map['serving_label'] as String? ?? '1 serving',
      servingGrams: (map['serving_grams'] as num?)?.toDouble() ?? 0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0,
      proteinG: (map['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (map['carbs_g'] as num?)?.toDouble() ?? 0,
      fatG: (map['fat_g'] as num?)?.toDouble() ?? 0,
      verificationStatus: map['verification_status'] as String? ?? 'unreviewed',
      sourceType: map['nutrition_source_type'] as String?,
      sourceName: map['nutrition_source_name'] as String?,
      sourceCheckedAt:
          DateTime.tryParse(map['source_checked_at'] as String? ?? ''),
      verifiedAt: DateTime.tryParse(map['verified_at'] as String? ?? ''),
    );
  }
}

class NutritionistDashboardKpis {
  final int unreviewed;
  final int inReview;
  final int verified;
  final int needsRevision;
  final int rejected;
  final int openReports;
  final int myReviewsThisWeek;
  final DateTime? credentialExpiresOn;
  final bool credentialExpired;
  final bool revalidationRequired;

  const NutritionistDashboardKpis({
    required this.unreviewed,
    required this.inReview,
    required this.verified,
    required this.needsRevision,
    required this.rejected,
    required this.openReports,
    required this.myReviewsThisWeek,
    required this.credentialExpiresOn,
    required this.credentialExpired,
    required this.revalidationRequired,
  });

  factory NutritionistDashboardKpis.fromJson(Map<String, dynamic> json) {
    return NutritionistDashboardKpis(
      unreviewed: (json['unreviewed'] as num?)?.toInt() ?? 0,
      inReview: (json['in_review'] as num?)?.toInt() ?? 0,
      verified: (json['verified'] as num?)?.toInt() ?? 0,
      needsRevision: (json['needs_revision'] as num?)?.toInt() ?? 0,
      rejected: (json['rejected'] as num?)?.toInt() ?? 0,
      openReports: (json['open_reports'] as num?)?.toInt() ?? 0,
      myReviewsThisWeek: (json['my_reviews_7d'] as num?)?.toInt() ?? 0,
      credentialExpiresOn:
          DateTime.tryParse(json['credential_expires_on'] as String? ?? ''),
      credentialExpired: json['credential_expired'] == true,
      revalidationRequired: json['revalidation_required'] == true,
    );
  }
}

class FoodReport {
  final String reportId;
  final String foodId;
  final String? foodName;
  final String issueType;
  final String? description;
  final String status;
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const FoodReport({
    required this.reportId,
    required this.foodId,
    required this.foodName,
    required this.issueType,
    required this.description,
    required this.status,
    required this.resolutionNote,
    required this.createdAt,
    required this.resolvedAt,
  });

  String get issueLabel => nutritionistIssueTypes[issueType] ?? issueType;

  factory FoodReport.fromMap(Map<String, dynamic> map) {
    final food = map['food'];
    return FoodReport(
      reportId: map['report_id'] as String,
      foodId: map['food_id'] as String,
      foodName:
          food is Map<String, dynamic> ? food['food_name'] as String? : null,
      issueType: map['issue_type'] as String? ?? 'other',
      description: map['description'] as String?,
      status: map['status'] as String? ?? 'open',
      resolutionNote: map['resolution_note'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      resolvedAt: DateTime.tryParse(map['resolved_at'] as String? ?? ''),
    );
  }
}

class NutritionistActionEntry {
  final String action;
  final String entityType;
  final String? entityId;
  final String? reason;
  final Map<String, dynamic>? newValues;
  final DateTime createdAt;

  const NutritionistActionEntry({
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.reason,
    required this.newValues,
    required this.createdAt,
  });

  factory NutritionistActionEntry.fromMap(Map<String, dynamic> map) {
    return NutritionistActionEntry(
      action: map['action'] as String? ?? 'review',
      entityType: map['entity_type'] as String? ?? 'food_nutrition_profile',
      entityId: map['entity_id'] as String?,
      reason: map['reason'] as String?,
      newValues: map['new_values'] is Map<String, dynamic>
          ? map['new_values'] as Map<String, dynamic>
          : null,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class NutritionistCatalogQuery {
  final String? search;
  final String? status;
  final int page;

  const NutritionistCatalogQuery({this.search, this.status, this.page = 0});

  @override
  bool operator ==(Object other) =>
      other is NutritionistCatalogQuery &&
      other.search == search &&
      other.status == status &&
      other.page == page;

  @override
  int get hashCode => Object.hash(search, status, page);
}

class NutritionReviewWarning {
  final String message;

  const NutritionReviewWarning(this.message);
}

/// Deterministic review-assistance checks for per-100 g values. These are
/// warnings only; they never replace professional review or auto-reject data.
List<NutritionReviewWarning> assessPer100gValues({
  required double calories,
  required double protein,
  required double carbs,
  required double fat,
}) {
  final warnings = <NutritionReviewWarning>[];
  final values = [calories, protein, carbs, fat];
  if (values.any((value) => !value.isFinite || value < 0)) {
    warnings.add(const NutritionReviewWarning(
      'Values must be zero or greater and cannot be infinite.',
    ));
    return warnings;
  }

  final macroSum = protein + carbs + fat;
  if (macroSum > 110) {
    warnings.add(const NutritionReviewWarning(
      'Protein, carbohydrate, and fat exceed 100 g per 100 g.',
    ));
  }

  if (calories > 0) {
    final estimated = protein * 4 + carbs * 4 + fat * 9;
    if ((estimated - calories).abs() / calories > 0.35) {
      warnings.add(const NutritionReviewWarning(
        'Stored calories differ from the 4/4/9 estimate; check the source.',
      ));
    }
  }
  return warnings;
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
    required DateTime prcLicenseExpirationDate,
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
          'p_prc_license_expiration_date':
              _formatDate(prcLicenseExpirationDate),
          'p_profession': nutritionistProfession,
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
          'review_id, serving_assessment, macro_assessment, comment, '
          'decision, review_note, source_type, source_name, updated_at, '
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

  static const _catalogColumns =
      'food_id, food_name, category_name, serving_id, serving_label, '
      'serving_grams, calories, protein_g, carbs_g, fat_g, '
      'verification_status, verified_at, nutrition_source_type, '
      'nutrition_source_name, source_checked_at';

  Future<List<NutritionistCatalogEntry>> fetchCatalog({
    String? search,
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    if (AppConfig.isLocalTestMode) return const [];
    var builder = _supabase.from('food_catalog').select(_catalogColumns).eq(
          'is_official',
          true,
        );
    final trimmed = search?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      builder = builder.ilike('food_name', '%$trimmed%');
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      builder = builder.eq('verification_status', status);
    }
    final rows = await builder
        .order('food_name', ascending: true)
        .range(page * pageSize, page * pageSize + pageSize - 1);
    return rows
        .map((row) =>
            NutritionistCatalogEntry.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<NutritionistCatalogEntry?> fetchCatalogEntry({
    required String foodId,
    required String servingId,
  }) async {
    if (AppConfig.isLocalTestMode) return null;
    final row = await _supabase
        .from('food_catalog')
        .select(_catalogColumns)
        .eq('food_id', foodId)
        .eq('serving_id', servingId)
        .maybeSingle();
    return row == null
        ? null
        : NutritionistCatalogEntry.fromMap(Map<String, dynamic>.from(row));
  }

  Future<NutritionistCatalogEntry?> fetchPrimaryServingEntry(
      String foodId) async {
    if (AppConfig.isLocalTestMode) return null;
    final row = await _supabase
        .from('food_catalog')
        .select(_catalogColumns)
        .eq('food_id', foodId)
        .limit(1)
        .maybeSingle();
    return row == null
        ? null
        : NutritionistCatalogEntry.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Map<String, dynamic>> beginReview({
    required String foodId,
    required String servingId,
  }) async {
    final result = await _supabase.rpc(
      'nutritionist_begin_review',
      params: {
        'p_food_id': foodId,
        'p_serving_id': servingId,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> submitReview({
    required String reviewId,
    required String decision,
    String? reviewNote,
    String? sourceType,
    String? sourceName,
    String? sourceReference,
    DateTime? sourceCheckedAt,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
  }) async {
    final result = await _supabase.rpc(
      'nutritionist_submit_review',
      params: {
        'p_review_id': reviewId,
        'p_decision': decision,
        'p_review_note': reviewNote,
        'p_source_type': sourceType,
        'p_source_name': sourceName,
        'p_source_reference': sourceReference,
        'p_source_checked_at':
            sourceCheckedAt == null ? null : _formatDate(sourceCheckedAt),
        'p_calories_per_100g': caloriesPer100g,
        'p_protein_per_100g': proteinPer100g,
        'p_carbs_per_100g': carbsPer100g,
        'p_fat_per_100g': fatPer100g,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> cancelReview({required String reviewId}) async {
    await _supabase.rpc(
      'nutritionist_cancel_review',
      params: {'p_review_id': reviewId},
    );
  }

  Future<void> archiveFood({
    required String foodId,
    required String reason,
  }) async {
    await _supabase.rpc(
      'nutritionist_archive_food',
      params: {
        'p_food_id': foodId,
        'p_reason': reason,
      },
    );
  }

  Future<FoodReport> submitFoodReport({
    required String foodId,
    required String issueType,
    String? description,
    String? servingId,
  }) async {
    final result = await _supabase.rpc(
      'submit_food_report',
      params: {
        'p_food_id': foodId,
        'p_issue_type': issueType,
        'p_description': description,
        'p_serving_id': servingId,
      },
    );
    return FoodReport.fromMap(Map<String, dynamic>.from(result as Map));
  }

  Future<List<FoodReport>> getReports({String? status}) async {
    if (AppConfig.isLocalTestMode) return const [];
    var builder = _supabase.from('food_report').select(
          'report_id, food_id, issue_type, description, status, '
          'resolution_note, created_at, resolved_at, '
          'food:food_item(food_name)',
        );
    if (status != null && status.isNotEmpty && status != 'all') {
      builder = builder.eq('status', status);
    }
    final rows = await builder.order('created_at', ascending: false).limit(100);
    return rows
        .map((row) => FoodReport.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> resolveReport({
    required String reportId,
    required String status,
    String? note,
  }) async {
    await _supabase.rpc(
      'nutritionist_resolve_food_report',
      params: {
        'p_report_id': reportId,
        'p_status': status,
        'p_note': note,
      },
    );
  }

  Future<NutritionistDashboardKpis> getDashboardKpis() async {
    if (AppConfig.isLocalTestMode) {
      throw StateError('The nutritionist workspace is online-only.');
    }
    final result = await _supabase.rpc('nutritionist_dashboard_kpis');
    return NutritionistDashboardKpis.fromJson(
        Map<String, dynamic>.from(result as Map));
  }

  Future<List<NutritionistActionEntry>> getMyHistory({int limit = 50}) async {
    if (AppConfig.isLocalTestMode) return const [];
    final userId = await _currentAppUserId();
    if (userId == null) return const [];
    final rows = await _supabase
        .from('nutritionist_action_log')
        .select(
            'action, entity_type, entity_id, reason, new_values, created_at')
        .eq('actor_user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map((row) =>
            NutritionistActionEntry.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
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

final verifiedNutritionistProvider = FutureProvider<bool>((ref) async {
  final application = await ref.watch(nutritionistApplicationProvider.future);
  return application != null &&
      application.isVerified &&
      !application.isExpired;
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

final foodVerificationProvider =
    FutureProvider.family<NutritionistCatalogEntry?, (String, String)>(
        (ref, foodServing) async {
  if (AppConfig.isLocalTestMode) return null;
  return ref.read(nutritionistServiceProvider).fetchCatalogEntry(
        foodId: foodServing.$1,
        servingId: foodServing.$2,
      );
});

final nutritionistDashboardProvider =
    FutureProvider<NutritionistDashboardKpis>((ref) async {
  return ref.read(nutritionistServiceProvider).getDashboardKpis();
});

final nutritionistCatalogProvider = FutureProvider.family<
    List<NutritionistCatalogEntry>, NutritionistCatalogQuery>((ref, query) {
  return ref.read(nutritionistServiceProvider).fetchCatalog(
        search: query.search,
        status: query.status,
        page: query.page,
      );
});

final nutritionistReportsProvider =
    FutureProvider.family<List<FoodReport>, String?>((ref, status) {
  return ref.read(nutritionistServiceProvider).getReports(status: status);
});

final nutritionistHistoryProvider =
    FutureProvider<List<NutritionistActionEntry>>((ref) {
  return ref.read(nutritionistServiceProvider).getMyHistory();
});
