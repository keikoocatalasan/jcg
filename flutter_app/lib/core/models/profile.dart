class Profile {
  final String userId;
  final String authUserId;
  final String? roleCode;
  final String? accountStatusCode;
  final String? nickname;
  final String? sexCode;
  final int? age;
  final double? heightCm;
  final double? currentWeightKg;
  final double? targetWeightKg;
  final String? activityLevelCode;
  final String? fitnessGoalCode;
  final double? dailyBudgetPhp;
  final bool onboardingCompleted;
  final String? allergies;
  final String? dietaryRestrictions;
  final bool disclaimerAccepted;
  final String? disclaimerVersion;
  final String? syncStatus;
  final String? createdAt;
  final String? updatedAt;

  String get pkColumn => 'user_id';

  Profile({
    required this.userId,
    required this.authUserId,
    this.roleCode,
    this.accountStatusCode,
    this.nickname,
    this.sexCode,
    this.age,
    this.heightCm,
    this.currentWeightKg,
    this.targetWeightKg,
    this.activityLevelCode,
    this.fitnessGoalCode,
    this.dailyBudgetPhp,
    this.onboardingCompleted = false,
    this.allergies,
    this.dietaryRestrictions,
    this.disclaimerAccepted = false,
    this.disclaimerVersion,
    this.syncStatus,
    this.createdAt,
    this.updatedAt,
  });
}
