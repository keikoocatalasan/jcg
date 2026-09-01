import '../models/profile.dart';
import 'base_repository.dart';

class ProfileRepository extends BaseRepository<Profile> {
  ProfileRepository(super.dbProvider);

  @override
  String get tableName => 'profiles';

  @override
  String get pkColumn => 'user_id';

  @override
  Profile fromMap(Map<String, dynamic> map) {
    return Profile(
      userId: map['user_id'] as String,
      authUserId: map['auth_user_id'] as String,
      roleCode: map['role_code'] as String?,
      accountStatusCode: map['account_status_code'] as String?,
      nickname: map['nickname'] as String?,
      sexCode: map['sex_code'] as String?,
      age: map['age'] as int?,
      heightCm: (map['height_cm'] as num?)?.toDouble(),
      currentWeightKg: (map['current_weight_kg'] as num?)?.toDouble(),
      targetWeightKg: (map['target_weight_kg'] as num?)?.toDouble(),
      activityLevelCode: map['activity_level_code'] as String?,
      fitnessGoalCode: map['fitness_goal_code'] as String?,
      dailyBudgetPhp: (map['daily_budget_php'] as num?)?.toDouble(),
      onboardingCompleted: (map['onboarding_completed'] as int) == 1,
      allergies: map['allergies'] as String?,
      dietaryRestrictions: map['dietary_restrictions'] as String?,
      disclaimerAccepted: (map['disclaimer_accepted'] as int) == 1,
      disclaimerVersion: map['disclaimer_version'] as String?,
      syncStatus: map['sync_status'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap(Profile entity) {
    return {
      'user_id': entity.userId,
      'auth_user_id': entity.authUserId,
      'role_code': entity.roleCode,
      'account_status_code': entity.accountStatusCode,
      'nickname': entity.nickname,
      'sex_code': entity.sexCode,
      'age': entity.age,
      'height_cm': entity.heightCm,
      'current_weight_kg': entity.currentWeightKg,
      'target_weight_kg': entity.targetWeightKg,
      'activity_level_code': entity.activityLevelCode,
      'fitness_goal_code': entity.fitnessGoalCode,
      'daily_budget_php': entity.dailyBudgetPhp,
      'onboarding_completed': entity.onboardingCompleted ? 1 : 0,
      'allergies': entity.allergies,
      'dietary_restrictions': entity.dietaryRestrictions,
      'disclaimer_accepted': entity.disclaimerAccepted ? 1 : 0,
      'disclaimer_version': entity.disclaimerVersion,
      'sync_status': entity.syncStatus,
      'created_at': entity.createdAt,
      'updated_at': entity.updatedAt,
    };
  }

  Future<Profile?> readByUserId(String userId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'auth_user_id = ?',
      whereArgs: [userId],
    );
    if (results.isEmpty) return null;
    return fromMap(results.first);
  }

  Future<int> updateOnboardingComplete(String userId) async {
    final db = await database;
    return db.update(
      tableName,
      {'onboarding_completed': 1},
      where: 'auth_user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> updateBudget(String userId, double budget) async {
    final db = await database;
    return db.update(
      tableName,
      {'daily_budget_php': budget},
      where: 'auth_user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> updateGoal(String userId, String goalCode) async {
    final db = await database;
    return db.update(
      tableName,
      {'fitness_goal_code': goalCode},
      where: 'auth_user_id = ?',
      whereArgs: [userId],
    );
  }
}
