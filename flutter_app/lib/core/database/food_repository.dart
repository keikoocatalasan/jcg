import 'base_repository.dart';

class Food {
  final String foodId;
  final String categoryName;
  final String? subcategory;
  final String? ownerUserId;
  final String foodName;
  final String normalizedName;
  final bool isLocalFood;
  final bool isOfficial;
  final bool isActive;
  final String? servingId;
  final String? servingLabel;
  final double? servingGrams;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double estimatedPricePhp;
  final bool isDeleted;
  final String syncStatus;
  final String createdAt;
  final String updatedAt;

  const Food({
    required this.foodId,
    required this.categoryName,
    this.subcategory,
    this.ownerUserId,
    required this.foodName,
    required this.normalizedName,
    this.isLocalFood = false,
    this.isOfficial = false,
    this.isActive = true,
    this.servingId,
    this.servingLabel,
    this.servingGrams,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.estimatedPricePhp,
    this.isDeleted = false,
    this.syncStatus = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Food.fromMap(Map<String, dynamic> map) {
    return Food(
      foodId: map['food_id'] as String,
      categoryName: map['category_name'] as String,
      subcategory: map['subcategory'] as String?,
      ownerUserId: map['owner_user_id'] as String?,
      foodName: map['food_name'] as String,
      normalizedName: map['normalized_name'] as String,
      isLocalFood: (map['is_local_food'] as int) == 1,
      isOfficial: (map['is_official'] as int) == 1,
      isActive: (map['is_active'] as int) == 1,
      servingId: map['serving_id'] as String?,
      servingLabel: map['serving_label'] as String?,
      servingGrams: (map['serving_grams'] as num?)?.toDouble(),
      calories: (map['calories'] as num).toDouble(),
      proteinG: (map['protein_g'] as num).toDouble(),
      carbsG: (map['carbs_g'] as num).toDouble(),
      fatG: (map['fat_g'] as num).toDouble(),
      estimatedPricePhp: (map['estimated_price_php'] as num).toDouble(),
      isDeleted: (map['is_deleted'] as int) == 1,
      syncStatus: map['sync_status'] as String? ?? 'synced',
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'food_id': foodId,
      'category_name': categoryName,
      'subcategory': subcategory,
      'owner_user_id': ownerUserId,
      'food_name': foodName,
      'normalized_name': normalizedName,
      'is_local_food': isLocalFood ? 1 : 0,
      'is_official': isOfficial ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'serving_id': servingId,
      'serving_label': servingLabel,
      'serving_grams': servingGrams,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'estimated_price_php': estimatedPricePhp,
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class FoodRepository extends BaseRepository<Food> {
  FoodRepository(super.dbProvider);

  @override
  String get tableName => 'foods';

  @override
  String get pkColumn => 'food_id';

  @override
  Food fromMap(Map<String, dynamic> map) => Food.fromMap(map);

  @override
  Map<String, dynamic> toMap(Food entity) => entity.toMap();

  Future<List<Food>> searchByName(
    String query, {
    String? category,
    bool? localOnly,
  }) async {
    final db = await database;
    final conditions = <String>['normalized_name LIKE ?'];
    final args = <String>['%$query%'];

    if (category != null) {
      conditions.add('category_name = ?');
      args.add(category);
    }

    if (localOnly == true) {
      conditions.add('is_local_food = 1');
    }

    final where = conditions.join(' AND ');
    final results = await db.query(
      tableName,
      where: where,
      whereArgs: args,
    );
    return results.map(fromMap).toList();
  }

  Future<List<Food>> readActiveOfficial() async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'is_official = 1 AND is_active = 1 AND is_deleted = 0',
    );
    return results.map(fromMap).toList();
  }

  Future<List<Food>> readByOwner(String userId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'owner_user_id = ?',
      whereArgs: [userId],
    );
    return results.map(fromMap).toList();
  }

  Future<int> softDelete(String foodId) async {
    final db = await database;
    return db.update(
      tableName,
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'food_id = ?',
      whereArgs: [foodId],
    );
  }
}
