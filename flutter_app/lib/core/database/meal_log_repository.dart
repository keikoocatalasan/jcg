import 'base_repository.dart';

class MealLog {
  final String mealLogId;
  final String userId;
  final String? foodId;
  final String mealTypeCode;
  final String logSourceCode;
  final String foodNameSnapshot;
  final double servingGramsSnapshot;
  final double quantity;
  final double caloriesSnapshot;
  final double proteinGsnapshot;
  final double carbsGsnapshot;
  final double fatGsnapshot;
  final double costPhpSnapshot;
  final String loggedAt;
  final bool isDeleted;
  final String syncStatus;
  final String createdAt;
  final String updatedAt;

  const MealLog({
    required this.mealLogId,
    required this.userId,
    this.foodId,
    required this.mealTypeCode,
    required this.logSourceCode,
    required this.foodNameSnapshot,
    required this.servingGramsSnapshot,
    required this.quantity,
    required this.caloriesSnapshot,
    required this.proteinGsnapshot,
    required this.carbsGsnapshot,
    required this.fatGsnapshot,
    required this.costPhpSnapshot,
    required this.loggedAt,
    this.isDeleted = false,
    this.syncStatus = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  factory MealLog.fromMap(Map<String, dynamic> map) {
    return MealLog(
      mealLogId: map['meal_log_id'] as String,
      userId: map['user_id'] as String,
      foodId: map['food_id'] as String?,
      mealTypeCode: map['meal_type_code'] as String,
      logSourceCode: map['log_source_code'] as String,
      foodNameSnapshot: map['food_name_snapshot'] as String,
      servingGramsSnapshot: (map['serving_grams_snapshot'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      caloriesSnapshot: (map['calories_snapshot'] as num).toDouble(),
      proteinGsnapshot: (map['protein_g_snapshot'] as num).toDouble(),
      carbsGsnapshot: (map['carbs_g_snapshot'] as num).toDouble(),
      fatGsnapshot: (map['fat_g_snapshot'] as num).toDouble(),
      costPhpSnapshot: (map['cost_php_snapshot'] as num).toDouble(),
      loggedAt: map['logged_at'] as String,
      isDeleted: (map['is_deleted'] as int) == 1,
      syncStatus: map['sync_status'] as String? ?? 'synced',
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'meal_log_id': mealLogId,
      'user_id': userId,
      'food_id': foodId,
      'meal_type_code': mealTypeCode,
      'log_source_code': logSourceCode,
      'food_name_snapshot': foodNameSnapshot,
      'serving_grams_snapshot': servingGramsSnapshot,
      'quantity': quantity,
      'calories_snapshot': caloriesSnapshot,
      'protein_g_snapshot': proteinGsnapshot,
      'carbs_g_snapshot': carbsGsnapshot,
      'fat_g_snapshot': fatGsnapshot,
      'cost_php_snapshot': costPhpSnapshot,
      'logged_at': loggedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class MealLogRepository extends BaseRepository<MealLog> {
  MealLogRepository(super.dbProvider);

  @override
  String get tableName => 'meal_logs';

  @override
  String get pkColumn => 'meal_log_id';

  @override
  MealLog fromMap(Map<String, dynamic> map) => MealLog.fromMap(map);

  @override
  Map<String, dynamic> toMap(MealLog entity) => entity.toMap();

  Future<List<MealLog>> queryByUserAndDate(
    String userId,
    String date,
  ) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where:
          "user_id = ? AND is_deleted = 0 AND date(logged_at, 'localtime') = ?",
      whereArgs: [userId, date],
    );
    return results.map(fromMap).toList();
  }

  Future<List<MealLog>> queryByUserAndDateRange(
    String userId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where:
          "user_id = ? AND is_deleted = 0 AND date(logged_at, 'localtime') BETWEEN ? AND ?",
      whereArgs: [userId, startDate, endDate],
    );
    return results.map(fromMap).toList();
  }

  Future<List<MealLog>> queryTodayByUser(String userId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where:
          "user_id = ? AND is_deleted = 0 AND date(logged_at, 'localtime') = date('now', 'localtime')",
      whereArgs: [userId],
    );
    return results.map(fromMap).toList();
  }

  Future<int> softDelete(String id) async {
    final db = await database;
    return db.update(
      tableName,
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'meal_log_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> hardDelete(String id) async {
    final db = await database;
    return db.delete(
      tableName,
      where: 'meal_log_id = ?',
      whereArgs: [id],
    );
  }
}
