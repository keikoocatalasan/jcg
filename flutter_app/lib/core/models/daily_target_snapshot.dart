class DailyTargetSnapshot {
  final String snapshotId;
  final String userId;
  final String nutritionTargetId;
  final String targetDate;
  final double? calorieTargetSnapshot;
  final double? proteinTargetGSnapshot;
  final double? carbsTargetGSnapshot;
  final double? fatTargetGSnapshot;
  final double? waterTargetMlSnapshot;
  final double? dailyBudgetPhpSnapshot;
  final String? syncStatus;
  final String? createdAt;

  String get pkColumn => 'snapshot_id';

  DailyTargetSnapshot({
    required this.snapshotId,
    required this.userId,
    required this.nutritionTargetId,
    required this.targetDate,
    this.calorieTargetSnapshot,
    this.proteinTargetGSnapshot,
    this.carbsTargetGSnapshot,
    this.fatTargetGSnapshot,
    this.waterTargetMlSnapshot,
    this.dailyBudgetPhpSnapshot,
    this.syncStatus,
    this.createdAt,
  });
}
