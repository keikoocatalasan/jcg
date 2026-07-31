class NutritionTarget {
  final String targetId;
  final String userId;
  final String? formulaVersionCode;
  final String? fitnessGoalCode;
  final String? sourceWeightLogId;
  final double? bmr;
  final double? tdee;
  final double? calorieTarget;
  final double? proteinTargetG;
  final double? carbsTargetG;
  final double? fatTargetG;
  final double? waterTargetMl;
  final double? dailyBudgetPhp;
  final String? effectiveFrom;
  final String? effectiveTo;
  final bool isActive;
  final String? syncStatus;
  final String? createdAt;

  String get pkColumn => 'target_id';

  NutritionTarget({
    required this.targetId,
    required this.userId,
    this.formulaVersionCode,
    this.fitnessGoalCode,
    this.sourceWeightLogId,
    this.bmr,
    this.tdee,
    this.calorieTarget,
    this.proteinTargetG,
    this.carbsTargetG,
    this.fatTargetG,
    this.waterTargetMl,
    this.dailyBudgetPhp,
    this.effectiveFrom,
    this.effectiveTo,
    this.isActive = true,
    this.syncStatus,
    this.createdAt,
  });

  NutritionTarget copyWith({
    String? targetId,
    String? userId,
    String? formulaVersionCode,
    String? fitnessGoalCode,
    String? sourceWeightLogId,
    double? bmr,
    double? tdee,
    double? calorieTarget,
    double? proteinTargetG,
    double? carbsTargetG,
    double? fatTargetG,
    double? waterTargetMl,
    double? dailyBudgetPhp,
    String? effectiveFrom,
    String? effectiveTo,
    bool? isActive,
    String? syncStatus,
    String? createdAt,
  }) {
    return NutritionTarget(
      targetId: targetId ?? this.targetId,
      userId: userId ?? this.userId,
      formulaVersionCode: formulaVersionCode ?? this.formulaVersionCode,
      fitnessGoalCode: fitnessGoalCode ?? this.fitnessGoalCode,
      sourceWeightLogId: sourceWeightLogId ?? this.sourceWeightLogId,
      bmr: bmr ?? this.bmr,
      tdee: tdee ?? this.tdee,
      calorieTarget: calorieTarget ?? this.calorieTarget,
      proteinTargetG: proteinTargetG ?? this.proteinTargetG,
      carbsTargetG: carbsTargetG ?? this.carbsTargetG,
      fatTargetG: fatTargetG ?? this.fatTargetG,
      waterTargetMl: waterTargetMl ?? this.waterTargetMl,
      dailyBudgetPhp: dailyBudgetPhp ?? this.dailyBudgetPhp,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      isActive: isActive ?? this.isActive,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
