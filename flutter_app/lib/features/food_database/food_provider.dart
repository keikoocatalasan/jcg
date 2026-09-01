import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/database/sync_queue_repository.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';

class FoodSearchParams {
  final String query;
  final String? category;
  final bool localOnly;

  const FoodSearchParams({
    this.query = '',
    this.category,
    this.localOnly = false,
  });

  FoodSearchParams copyWith({
    String? query,
    String? category,
    bool? localOnly,
  }) {
    return FoodSearchParams(
      query: query ?? this.query,
      category: category ?? this.category,
      localOnly: localOnly ?? this.localOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodSearchParams &&
          query == other.query &&
          category == other.category &&
          localOnly == other.localOnly;

  @override
  int get hashCode => Object.hash(query, category, localOnly);
}

final foodSearchProvider =
    FutureProvider.autoDispose.family<List<Food>, FoodSearchParams>(
  (ref, params) async {
    if (params.query.length < 2) return [];
    final repo = FoodRepository(DatabaseProvider());
    return repo.searchByName(
      params.query,
      category: params.category,
      localOnly: params.localOnly,
    );
  },
);

final categoriesProvider = Provider<List<String>>((ref) {
  return [
    'Rice and Grains',
    'Meat and Poultry',
    'Seafood',
    'Vegetables',
    'Fruits',
    'Dairy and Eggs',
    'Bread and Pastry',
    'Soups and Porridge',
    'Beverages',
    'Snacks and Desserts',
    'Legumes and Tofu',
    'Condiments and Spreads',
  ];
});

class FoodFormData {
  final String userId;
  final String foodName;
  final String categoryName;
  final String servingLabel;
  final double servingGrams;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double estimatedPricePhp;
  final bool isLocalFood;

  const FoodFormData({
    required this.userId,
    required this.foodName,
    required this.categoryName,
    required this.servingLabel,
    required this.servingGrams,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.estimatedPricePhp,
    this.isLocalFood = true,
  });
}

final customFoodProvider =
    FutureProvider.family<void, FoodFormData>((ref, data) async {
  final repo = FoodRepository(DatabaseProvider());
  final syncRepo = SyncQueueRepository(DatabaseProvider());
  final now = DateTime.now().toUtc().toIso8601String();
  final foodId = UuidHelper.generateUuid();
  final servingId = UuidHelper.generateUuid();

  final food = Food(
    foodId: foodId,
    categoryName: data.categoryName,
    ownerUserId: data.userId,
    foodName: data.foodName,
    normalizedName: data.foodName.toLowerCase(),
    isLocalFood: data.isLocalFood,
    isOfficial: false,
    isActive: true,
    servingId: servingId,
    servingLabel: data.servingLabel,
    servingGrams: data.servingGrams,
    calories: data.calories,
    proteinG: data.proteinG,
    carbsG: data.carbsG,
    fatG: data.fatG,
    estimatedPricePhp: data.estimatedPricePhp,
    syncStatus: 'pending',
    createdAt: now,
    updatedAt: now,
  );

  await repo.insert(food);

  await syncRepo.insert(SyncQueueEntry(
    syncQueueId: UuidHelper.generateUuid(),
    userId: data.userId,
    operationId: UuidHelper.generateOperationId(),
    entityTypeCode: 'custom_food',
    entityId: foodId,
    operationCode: 'create',
    payloadJson: jsonEncode(food.toMap()),
    clientSequence: DateTime.now().millisecondsSinceEpoch,
    createdAt: now,
  ));
});
