import 'package:sqflite/sqflite.dart';

import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';

/// Seeds a small, deterministic local workspace for manual QA.
///
/// This is only called when [AppConfig.isLocalTestMode] is true. It uses a
/// namespaced demo identity and never writes to Supabase, so it cannot affect
/// a real account or hosted data.
class LocalTestDataSeeder {
  const LocalTestDataSeeder._();

  static const _userId = AppConfig.localTestUserId;
  static const _authUserId = AppConfig.localTestUserId;
  static Future<void>? _seedFuture;

  static Future<void> ensure() {
    if (!AppConfig.isLocalTestMode) return Future<void>.value();
    return _seedFuture ??= _seed();
  }

  static Future<void> _seed() async {
    final db = await DatabaseProvider().database;
    final now = DateTime.now();
    final nowIso = now.toUtc().toIso8601String();
    final today = _date(now);

    await db.insert(
      'profiles',
      {
        'user_id': _userId,
        'auth_user_id': _authUserId,
        'role_code': 'admin',
        'account_status_code': 'active',
        'nickname': 'Demo Admin',
        'sex_code': 'female',
        'age': 24,
        'height_cm': 160.0,
        'current_weight_kg': 55.0,
        'target_weight_kg': 52.0,
        'activity_level_code': 'moderate',
        'fitness_goal_code': 'maintenance',
        'daily_budget_php': 300.0,
        'onboarding_completed': 1,
        'allergies': '',
        'dietary_restrictions': '',
        'disclaimer_accepted': 1,
        'disclaimer_version': 'local-test-v1',
        'sync_status': 'synced',
        'created_at': nowIso,
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // Keep the demo account usable for both consumer and admin walkthroughs
    // even if a previous local run changed only its profile fields.
    await db.update(
      'profiles',
      {
        'role_code': 'admin',
        'account_status_code': 'active',
        'onboarding_completed': 1,
      },
      where: 'user_id = ?',
      whereArgs: [_userId],
    );

    await db.insert(
      'weight_logs',
      {
        'weight_log_id': 'local-weight-1',
        'user_id': _userId,
        'weight_kg': 55.0,
        'logged_at':
            now.subtract(const Duration(days: 6)).toUtc().toIso8601String(),
        'sync_status': 'synced',
        'created_at': nowIso,
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      'weight_logs',
      {
        'weight_log_id': 'local-weight-2',
        'user_id': _userId,
        'weight_kg': 54.6,
        'logged_at': now.toUtc().toIso8601String(),
        'sync_status': 'synced',
        'created_at': nowIso,
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      'nutrition_targets',
      {
        'target_id': 'local-target-1',
        'user_id': _userId,
        'formula_version_code': 'local-test',
        'fitness_goal_code': 'maintenance',
        'source_weight_log_id': 'local-weight-2',
        'bmr': 1280.0,
        'tdee': 1760.0,
        'calorie_target': 1760,
        'protein_target_g': 110.0,
        'carbs_target_g': 220.0,
        'fat_target_g': 55.0,
        'water_target_ml': 1900,
        'daily_budget_php': 300.0,
        'effective_from': today,
        'effective_to': null,
        'is_active': 1,
        'sync_status': 'synced',
        'created_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      'daily_target_snapshots',
      {
        'snapshot_id': 'local-snapshot-1',
        'user_id': _userId,
        'nutrition_target_id': 'local-target-1',
        'target_date': today,
        'calorie_target_snapshot': 1760,
        'protein_target_g_snapshot': 110.0,
        'carbs_target_g_snapshot': 220.0,
        'fat_target_g_snapshot': 55.0,
        'water_target_ml_snapshot': 1900,
        'daily_budget_php_snapshot': 300.0,
        'sync_status': 'synced',
        'created_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final foods = [
      _food(
        id: 'local-food-adobo',
        name: 'Chicken Adobo',
        category: 'Meat',
        servingLabel: '1 bowl',
        servingGrams: 180,
        calories: 430,
        protein: 35,
        carbs: 8,
        fat: 28,
        price: 65,
        mealTypes: 'lunch,dinner',
      ),
      _food(
        id: 'local-food-sinigang',
        name: 'Sinigang na Baboy',
        category: 'Meat',
        servingLabel: '1 bowl',
        servingGrams: 300,
        calories: 380,
        protein: 22,
        carbs: 15,
        fat: 26,
        price: 65,
        mealTypes: 'lunch,dinner',
      ),
      _food(
        id: 'local-food-rice',
        name: 'White Rice',
        category: 'Rice and Grains',
        servingLabel: '1 cup',
        servingGrams: 158,
        calories: 205,
        protein: 4.3,
        carbs: 44.5,
        fat: 0.4,
        price: 15,
        mealTypes: 'breakfast,lunch,dinner',
      ),
    ];
    for (final food in foods) {
      await db.insert(
        'foods',
        food,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final hasMeals = await db.query(
      'meal_logs',
      columns: ['meal_log_id'],
      where: 'user_id = ?',
      whereArgs: [_userId],
      limit: 1,
    );
    if (hasMeals.isEmpty) {
      await db.insert(
          'meal_logs',
          _meal(
            id: 'local-meal-adobo',
            foodId: 'local-food-adobo',
            foodName: 'Chicken Adobo',
            mealType: 'lunch',
            servingGrams: 180,
            calories: 430,
            protein: 35,
            carbs: 8,
            fat: 28,
            price: 65,
            loggedAt: now
                .subtract(const Duration(hours: 3))
                .toUtc()
                .toIso8601String(),
          ));
      await db.insert(
          'meal_logs',
          _meal(
            id: 'local-meal-rice',
            foodId: 'local-food-rice',
            foodName: 'White Rice',
            mealType: 'lunch',
            servingGrams: 158,
            calories: 205,
            protein: 4.3,
            carbs: 44.5,
            fat: 0.4,
            price: 15,
            loggedAt: now
                .subtract(const Duration(hours: 3))
                .toUtc()
                .toIso8601String(),
          ));
    }

    final hasWater = await db.query(
      'water_logs',
      columns: ['water_log_id'],
      where: 'user_id = ?',
      whereArgs: [_userId],
      limit: 1,
    );
    if (hasWater.isEmpty) {
      await db.insert('water_logs', {
        'water_log_id': 'local-water-1',
        'user_id': _userId,
        'amount_ml': 500,
        'logged_at':
            now.subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
        'sync_status': 'synced',
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      await db.insert('water_logs', {
        'water_log_id': 'local-water-2',
        'user_id': _userId,
        'amount_ml': 250,
        'logged_at':
            now.subtract(const Duration(hours: 1)).toUtc().toIso8601String(),
        'sync_status': 'synced',
        'created_at': nowIso,
        'updated_at': nowIso,
      });
    }

    await _seedCommunityCache(db, nowIso);
  }

  static Map<String, dynamic> _food({
    required String id,
    required String name,
    required String category,
    required String servingLabel,
    required double servingGrams,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double price,
    required String mealTypes,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'food_id': id,
      'category_name': category,
      'subcategory': 'Filipino demo catalog',
      'description': 'Local test food for the JCG defense walkthrough.',
      'owner_user_id': null,
      'food_name': name,
      'normalized_name': name.toLowerCase(),
      'is_local_food': 1,
      'is_official': 1,
      'is_active': 1,
      'serving_id': '$id-serving',
      'serving_label': servingLabel,
      'serving_grams': servingGrams,
      'calories': calories,
      'protein_g': protein,
      'carbs_g': carbs,
      'fat_g': fat,
      'estimated_price_php': price,
      'meal_type_codes': mealTypes,
      'is_deleted': 0,
      'sync_status': 'synced',
      'created_at': now,
      'updated_at': now,
    };
  }

  static Map<String, dynamic> _meal({
    required String id,
    required String foodId,
    required String foodName,
    required String mealType,
    required double servingGrams,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double price,
    required String loggedAt,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'meal_log_id': id,
      'user_id': _userId,
      'food_id': foodId,
      'meal_type_code': mealType,
      'log_source_code': 'manual',
      'food_name_snapshot': foodName,
      'serving_grams_snapshot': servingGrams,
      'quantity': 1.0,
      'calories_snapshot': calories,
      'protein_g_snapshot': protein,
      'carbs_g_snapshot': carbs,
      'fat_g_snapshot': fat,
      'cost_php_snapshot': price,
      'logged_at': loggedAt,
      'is_deleted': 0,
      'sync_status': 'synced',
      'created_at': now,
      'updated_at': now,
    };
  }

  static Future<void> _seedCommunityCache(Database db, String nowIso) async {
    final posts = [
      {
        'post_id': 'local-post-1',
        'user_id': 'local-community-mika',
        'author_nickname': 'Mika',
        'body_text': 'What is your go-to budget-friendly ulam this week?',
        'like_count': 18,
        'comment_count': 5,
      },
      {
        'post_id': 'local-post-2',
        'user_id': 'local-community-jon',
        'author_nickname': 'Jon',
        'body_text': 'Sinigang and rice kept me full after training today.',
        'like_count': 11,
        'comment_count': 3,
      },
      {
        'post_id': 'local-post-3',
        'user_id': 'local-community-ana',
        'author_nickname': 'Ana',
        'body_text': 'Small, consistent choices add up. Share your progress.',
        'like_count': 8,
        'comment_count': 2,
      },
    ];
    for (var index = 0; index < posts.length; index++) {
      final post = posts[index];
      final createdAt = DateTime.now()
          .subtract(Duration(hours: index + 1))
          .toUtc()
          .toIso8601String();
      await db.insert(
        'community_cache',
        {
          ...post,
          'is_hidden': 0,
          'is_deleted': 0,
          'created_at': createdAt,
          'updated_at': createdAt,
          'cached_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
