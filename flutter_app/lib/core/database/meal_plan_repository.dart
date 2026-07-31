import 'base_repository.dart';

class MealPlan {
  final String mealPlanId;
  final String userId;
  final String? foodId;
  final String mealTypeCode;
  final String statusCode;
  final String? convertedMealLogId;
  final String foodNameSnapshot;
  final double servingGramsSnapshot;
  final double quantity;
  final double caloriesSnapshot;
  final double proteinGsnapshot;
  final double carbsGsnapshot;
  final double fatGsnapshot;
  final double costPhpSnapshot;
  final String plannedDate;
  final String syncStatus;
  final String? createdAt;
  final String? updatedAt;

  MealPlan({
    required this.mealPlanId,
    required this.userId,
    this.foodId,
    required this.mealTypeCode,
    required this.statusCode,
    this.convertedMealLogId,
    required this.foodNameSnapshot,
    required this.servingGramsSnapshot,
    required this.quantity,
    required this.caloriesSnapshot,
    required this.proteinGsnapshot,
    required this.carbsGsnapshot,
    required this.fatGsnapshot,
    required this.costPhpSnapshot,
    required this.plannedDate,
    required this.syncStatus,
    this.createdAt,
    this.updatedAt,
  });
}

class MealPlanRepository extends BaseRepository<MealPlan> {
  MealPlanRepository(super._dbProvider);

  @override
  String get tableName => 'meal_plans';

  @override
  String get pkColumn => 'meal_plan_id';

  @override
  MealPlan fromMap(Map<String, dynamic> map) {
    return MealPlan(
      mealPlanId: map['meal_plan_id'] as String,
      userId: map['user_id'] as String,
      foodId: map['food_id'] as String?,
      mealTypeCode: map['meal_type_code'] as String,
      statusCode: map['status_code'] as String,
      convertedMealLogId: map['converted_meal_log_id'] as String?,
      foodNameSnapshot: map['food_name_snapshot'] as String,
      servingGramsSnapshot: (map['serving_grams_snapshot'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      caloriesSnapshot: (map['calories_snapshot'] as num).toDouble(),
      proteinGsnapshot: (map['protein_g_snapshot'] as num).toDouble(),
      carbsGsnapshot: (map['carbs_g_snapshot'] as num).toDouble(),
      fatGsnapshot: (map['fat_g_snapshot'] as num).toDouble(),
      costPhpSnapshot: (map['cost_php_snapshot'] as num).toDouble(),
      plannedDate: map['planned_date'] as String,
      syncStatus: map['sync_status'] as String,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap(MealPlan entity) {
    return {
      'meal_plan_id': entity.mealPlanId,
      'user_id': entity.userId,
      'food_id': entity.foodId,
      'meal_type_code': entity.mealTypeCode,
      'status_code': entity.statusCode,
      'converted_meal_log_id': entity.convertedMealLogId,
      'food_name_snapshot': entity.foodNameSnapshot,
      'serving_grams_snapshot': entity.servingGramsSnapshot,
      'quantity': entity.quantity,
      'calories_snapshot': entity.caloriesSnapshot,
      'protein_g_snapshot': entity.proteinGsnapshot,
      'carbs_g_snapshot': entity.carbsGsnapshot,
      'fat_g_snapshot': entity.fatGsnapshot,
      'cost_php_snapshot': entity.costPhpSnapshot,
      'planned_date': entity.plannedDate,
      'sync_status': entity.syncStatus,
      'created_at': entity.createdAt,
      'updated_at': entity.updatedAt,
    };
  }

  Future<List<MealPlan>> queryByUserAndDate(String userId, String date) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'user_id = ? AND planned_date = ?',
      whereArgs: [userId, date],
    );
    return results.map(fromMap).toList();
  }

  Future<List<MealPlan>> queryByUserAndWeek(
      String userId, String weekStart) async {
    final db = await database;
    final parsed = DateTime.parse(weekStart);
    final weekEnd = parsed.add(const Duration(days: 6));
    final weekEndStr =
        '${weekEnd.year}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}';
    final results = await db.query(
      tableName,
      where: 'user_id = ? AND planned_date >= ? AND planned_date <= ?',
      whereArgs: [userId, weekStart, weekEndStr],
    );
    return results.map(fromMap).toList();
  }

  Future<int> updateStatus(String id, String status,
      {String? convertedMealLogId}) async {
    final db = await database;
    final values = <String, dynamic>{'status_code': status};
    if (convertedMealLogId != null) {
      values['converted_meal_log_id'] = convertedMealLogId;
    }
    return db.update(
      tableName,
      values,
      where: 'meal_plan_id = ?',
      whereArgs: [id],
    );
  }
}
