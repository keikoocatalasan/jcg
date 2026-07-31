import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/core/sync/sync_initial_pull.dart';
import 'package:jcg_fitness/core/utils/date_helper.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/features/onboarding/onboarding_completion_provider.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_engine.dart';

String _onboardingStateKey(String userId) => 'onboarding_state_$userId';

class OnboardingState {
  final String nickname;
  final String sexCode;
  final int age;
  final double heightCm;
  final double currentWeightKg;
  final double? targetWeightKg;
  final String activityLevelCode;
  final String fitnessGoalCode;
  final double dailyBudgetPhp;
  final List<String> allergies;
  final List<String> dietaryRestrictions;
  final bool disclaimerAccepted;
  final String? disclaimerVersion;
  final bool isSubmitting;
  final String? error;
  final int currentStepIndex;

  static const _unset = Object();

  const OnboardingState({
    this.nickname = '',
    this.sexCode = 'male',
    this.age = 25,
    this.heightCm = 170,
    this.currentWeightKg = 70,
    this.targetWeightKg,
    this.activityLevelCode = 'moderate',
    this.fitnessGoalCode = 'maintenance',
    this.dailyBudgetPhp = 300,
    this.allergies = const [],
    this.dietaryRestrictions = const [],
    this.disclaimerAccepted = false,
    this.disclaimerVersion,
    this.isSubmitting = false,
    this.error,
    this.currentStepIndex = 0,
  });

  OnboardingState copyWith({
    String? nickname,
    String? sexCode,
    int? age,
    double? heightCm,
    double? currentWeightKg,
    Object? targetWeightKg = _unset,
    String? activityLevelCode,
    String? fitnessGoalCode,
    double? dailyBudgetPhp,
    List<String>? allergies,
    List<String>? dietaryRestrictions,
    bool? disclaimerAccepted,
    String? disclaimerVersion,
    bool? isSubmitting,
    Object? error = _unset,
    int? currentStepIndex,
  }) {
    return OnboardingState(
      nickname: nickname ?? this.nickname,
      sexCode: sexCode ?? this.sexCode,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      targetWeightKg: targetWeightKg == _unset
          ? this.targetWeightKg
          : targetWeightKg as double?,
      activityLevelCode: activityLevelCode ?? this.activityLevelCode,
      fitnessGoalCode: fitnessGoalCode ?? this.fitnessGoalCode,
      dailyBudgetPhp: dailyBudgetPhp ?? this.dailyBudgetPhp,
      allergies: allergies ?? this.allergies,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      disclaimerAccepted: disclaimerAccepted ?? this.disclaimerAccepted,
      disclaimerVersion: disclaimerVersion ?? this.disclaimerVersion,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error == _unset ? this.error : error as String?,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'sexCode': sexCode,
        'age': age,
        'heightCm': heightCm,
        'currentWeightKg': currentWeightKg,
        'targetWeightKg': targetWeightKg,
        'activityLevelCode': activityLevelCode,
        'fitnessGoalCode': fitnessGoalCode,
        'dailyBudgetPhp': dailyBudgetPhp,
        'allergies': allergies,
        'dietaryRestrictions': dietaryRestrictions,
        'disclaimerAccepted': disclaimerAccepted,
        'disclaimerVersion': disclaimerVersion,
        'currentStepIndex': currentStepIndex,
      };

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    return OnboardingState(
      nickname: json['nickname'] as String? ?? '',
      sexCode: json['sexCode'] as String? ?? 'male',
      age: json['age'] as int? ?? 25,
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170,
      currentWeightKg: (json['currentWeightKg'] as num?)?.toDouble() ?? 70,
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      activityLevelCode: json['activityLevelCode'] as String? ?? 'moderate',
      fitnessGoalCode: json['fitnessGoalCode'] as String? ?? 'maintenance',
      dailyBudgetPhp: (json['dailyBudgetPhp'] as num?)?.toDouble() ?? 300,
      allergies: (json['allergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      dietaryRestrictions: (json['dietaryRestrictions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      disclaimerAccepted: json['disclaimerAccepted'] as bool? ?? false,
      disclaimerVersion: json['disclaimerVersion'] as String?,
      currentStepIndex: json['currentStepIndex'] as int? ?? 0,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  final Ref _ref;

  OnboardingController(Ref ref)
      : _ref = ref,
        super(
          OnboardingState(
            nickname: ref
                    .read(supabaseClientProvider)
                    .auth
                    .currentUser
                    ?.userMetadata?['username'] as String? ??
                '',
          ),
        ) {
    _loadSavedState();
  }

  String? get _userId =>
      _ref.read(supabaseClientProvider).auth.currentUser?.id;

  Future<void> _loadSavedState() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_onboardingStateKey(userId));
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final saved = OnboardingState.fromJson(json);
        if (saved.currentStepIndex > state.currentStepIndex) {
          state = saved;
        } else if (saved.currentStepIndex >= 0) {
          state = state.copyWith(
            nickname: saved.nickname.isNotEmpty ? saved.nickname : state.nickname,
            sexCode: saved.sexCode,
            age: saved.age,
            heightCm: saved.heightCm,
            currentWeightKg: saved.currentWeightKg,
            targetWeightKg: saved.targetWeightKg,
            activityLevelCode: saved.activityLevelCode,
            fitnessGoalCode: saved.fitnessGoalCode,
            dailyBudgetPhp: saved.dailyBudgetPhp,
            allergies: saved.allergies,
            dietaryRestrictions: saved.dietaryRestrictions,
            disclaimerAccepted: saved.disclaimerAccepted,
            disclaimerVersion: saved.disclaimerVersion,
            currentStepIndex: saved.currentStepIndex,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _persistState() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _onboardingStateKey(userId),
        jsonEncode(state.toJson()),
      );
    } catch (_) {}
  }

  void setNickname(String value) {
    state = state.copyWith(nickname: value);
    _persistState();
  }

  void setSex(String value) {
    state = state.copyWith(sexCode: value);
    _persistState();
  }

  void setAge(int value) {
    state = state.copyWith(age: value);
    _persistState();
  }

  void setHeight(double value) {
    state = state.copyWith(heightCm: value);
    _persistState();
  }

  void setCurrentWeight(double value) {
    state = state.copyWith(currentWeightKg: value);
    _persistState();
  }

  void setTargetWeight(double? value) {
    state = state.copyWith(targetWeightKg: value);
    _persistState();
  }

  void setActivityLevel(String value) {
    state = state.copyWith(activityLevelCode: value);
    _persistState();
  }

  void setFitnessGoal(String value) {
    state = state.copyWith(fitnessGoalCode: value);
    _persistState();
  }

  void setDailyBudget(double value) {
    state = state.copyWith(dailyBudgetPhp: value);
    _persistState();
  }

  void setAllergies(List<String> value) {
    state = state.copyWith(allergies: value);
    _persistState();
  }

  void setDietaryRestrictions(List<String> value) {
    state = state.copyWith(dietaryRestrictions: value);
    _persistState();
  }

  void setDisclaimerAccepted(bool value) {
    state = state.copyWith(disclaimerAccepted: value);
    _persistState();
  }

  void setDisclaimerVersion(String? value) {
    state = state.copyWith(disclaimerVersion: value);
    _persistState();
  }

  void advanceStep(int stepIndex) {
    if (stepIndex > state.currentStepIndex) {
      state = state.copyWith(currentStepIndex: stepIndex);
      _persistState();
    }
  }

  void clearError() => state = state.copyWith(error: null);

  Future<void> _clearSavedState() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingStateKey(userId));
    } catch (_) {}
  }

  Future<void> submitOnboarding() async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final session = _ref.read(supabaseClientProvider).auth.currentSession;
      if (session == null) {
        state = state.copyWith(
          isSubmitting: false,
          error: 'No active session. Please log in again.',
        );
        return;
      }
      final userId = session.user.id;

      final s = state;
      final today = DateHelper.todayDate();
      final nowIso = DateHelper.nowUtc();

      final normalizedGoal =
          s.fitnessGoalCode == 'lean_bulk' ? 'lean' : s.fitnessGoalCode;
      final calculated = NutritionEngine.calculateAll(
        weightKg: s.currentWeightKg,
        heightCm: s.heightCm,
        age: s.age,
        sexCode: s.sexCode,
        activityLevelCode: s.activityLevelCode,
        fitnessGoalCode: normalizedGoal,
      );
      final bmr = calculated.bmr;
      final tdee = calculated.tdee;
      final calorieTarget = calculated.calorieTarget;
      final proteinTargetG = calculated.proteinG;
      final fatTargetG = calculated.fatG;
      final carbsTargetG = calculated.carbsG;
      final waterTargetMl = calculated.waterTargetMl.toDouble();

      final targetId = UuidHelper.generateUuid();
      final weightLogId = UuidHelper.generateUuid();
      final snapshotId = UuidHelper.generateUuid();

      final profileData = <String, dynamic>{
        'auth_user_id': userId,
        'nickname': s.nickname.trim(),
        'sex_code': s.sexCode,
        'age': s.age,
        'height_cm': s.heightCm,
        'current_weight_kg': s.currentWeightKg,
        'target_weight_kg': s.targetWeightKg,
        'activity_level_code': s.activityLevelCode,
        'fitness_goal_code': normalizedGoal,
        'daily_budget_php': s.dailyBudgetPhp,
        'onboarding_completed': 1,
        'allergies': s.allergies.join(','),
        'dietary_restrictions': s.dietaryRestrictions.join(','),
        'disclaimer_accepted': s.disclaimerAccepted ? 1 : 0,
        'disclaimer_version': s.disclaimerVersion ?? '1.0',
      };

      final weightLogData = <String, dynamic>{
        'weight_log_id': weightLogId,
        'weight_kg': s.currentWeightKg,
        'logged_at': nowIso,
      };

      final nutritionTargetData = <String, dynamic>{
        'target_id': targetId,
        'formula_version_code': 'mifflin_st_jeor_v1',
        'fitness_goal_code': normalizedGoal,
        'bmr': bmr.roundToDouble(),
        'tdee': tdee.roundToDouble(),
        'calorie_target': calorieTarget.roundToDouble(),
        'protein_target_g': proteinTargetG,
        'carbs_target_g': carbsTargetG,
        'fat_target_g': fatTargetG,
        'water_target_ml': waterTargetMl,
        'daily_budget_php': s.dailyBudgetPhp,
        'is_active': 1,
        'effective_from': today,
      };

      final dailySnapshotData = <String, dynamic>{
        'snapshot_id': snapshotId,
        'nutrition_target_id': targetId,
        'target_date': today,
        'calorie_target_snapshot': calorieTarget.roundToDouble(),
        'protein_target_g_snapshot': proteinTargetG,
        'carbs_target_g_snapshot': carbsTargetG,
        'fat_target_g_snapshot': fatTargetG,
        'water_target_ml_snapshot': waterTargetMl,
        'daily_budget_php_snapshot': s.dailyBudgetPhp,
      };

      final helper = LocalTransactionHelper(DatabaseProvider());
      await helper.completeOnboarding(
        userId: userId,
        profileData: profileData,
        nutritionTargetData: nutritionTargetData,
        dailySnapshotData: dailySnapshotData,
        weightLogData: weightLogData,
      );

      await SyncInitialPull.pullInitialData(DatabaseProvider());

      await _clearSavedState();
      await saveOnboardingComplete(userId, true);
      _ref.read(onboardingCompleteProvider.notifier).state = true;
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Failed to save onboarding data: ${e.toString()}',
      );
    }
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  return OnboardingController(ref);
});
