import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_provider.dart';
import '../database/food_repository.dart';

class SyncInitialPull {
  /// Pull official foods and lookup data from Supabase to SQLite.
  static Future<void> pullInitialData(DatabaseProvider db) async {
    final supabase = Supabase.instance.client;

    await _pullOfficialFoods(supabase, db);

    await _pullLookupData(supabase, db);
  }

  static Future<void> _pullOfficialFoods(
    SupabaseClient supabase,
    DatabaseProvider db,
  ) async {
    try {
      final foods = await supabase
          .from('food_catalog')
          .select()
          .eq('is_official', true)
          .eq('is_active', true);

      if (foods.isEmpty) return;

      final database = await db.database;
      final repo = FoodRepository(db);

      final existingFoods = await repo.readActiveOfficial();
      final existingIds = existingFoods.map((f) => f.foodId).toSet();

      for (final food in foods) {
        final foodId = food['food_id'] as String;
        if (existingIds.contains(foodId)) continue;

        final record = Map<String, dynamic>.from(food)
          ..['is_local_food'] = food['is_local_food'] == true ? 1 : 0
          ..['is_official'] = food['is_official'] == true ? 1 : 0
          ..['is_active'] = food['is_active'] == true ? 1 : 0
          ..['is_deleted'] = 0;
        await database.insert('foods', record,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {
      // Non-blocking: initial pull failures are silent to avoid blocking startup
    }
  }

  static Future<void> _pullLookupData(
    SupabaseClient supabase,
    DatabaseProvider db,
  ) async {
    try {
      // Category names are included in each flattened food catalog row.
    } catch (_) {}
  }

  /// Sync user profile from Supabase to SQLite (bridge gap
  /// after offline registration).
  static Future<void> pullUserData(
    String userId,
    DatabaseProvider db,
  ) async {
    final supabase = Supabase.instance.client;

    try {
      final appUser = await supabase
          .from('app_user')
          .select(
            'user_id, role(role_code), account_status(status_code)',
          )
          .eq('auth_user_id', userId)
          .maybeSingle();
      if (appUser == null) return;

      final appUserId = appUser['user_id'] as String;
      final profile = await supabase
          .from('user_profile')
          .select(
            '*, sex(sex_code), activity_level(activity_code), '
            'fitness_goal(goal_code)',
          )
          .eq('user_id', appUserId)
          .maybeSingle();

      if (profile != null) {
        final allergyRows = await supabase
            .from('user_allergy')
            .select('allergy(allergy_name)')
            .eq('user_id', appUserId);
        final restrictionRows = await supabase
            .from('user_dietary_restriction')
            .select('dietary_restriction(restriction_name)')
            .eq('user_id', appUserId);
        final disclaimer = await supabase
            .from('medical_disclaimer_acceptance')
            .select('disclaimer_version')
            .eq('user_id', appUserId)
            .order('accepted_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final database = await db.database;
        final record = Map<String, dynamic>.from(profile)
          ..remove('profile_id')
          ..remove('sex_id')
          ..remove('activity_level_id')
          ..remove('fitness_goal_id')
          ..['user_id'] = appUserId
          ..['auth_user_id'] = userId
          ..['role_code'] = (appUser['role'] as Map?)?['role_code'] ?? 'user'
          ..['account_status_code'] =
              (appUser['account_status'] as Map?)?['status_code'] ?? 'active'
          ..['sex_code'] = (profile['sex'] as Map?)?['sex_code']
          ..['activity_level_code'] =
              (profile['activity_level'] as Map?)?['activity_code']
          ..['fitness_goal_code'] =
              (profile['fitness_goal'] as Map?)?['goal_code']
          ..['allergies'] = allergyRows
              .map((row) => (row['allergy'] as Map?)?['allergy_name'])
              .whereType<String>()
              .join(',')
          ..['dietary_restrictions'] = restrictionRows
              .map((row) =>
                  (row['dietary_restriction'] as Map?)?['restriction_name'])
              .whereType<String>()
              .join(',')
          ..['disclaimer_accepted'] = disclaimer == null ? 0 : 1
          ..['disclaimer_version'] = disclaimer?['disclaimer_version']
          ..['onboarding_completed'] =
              profile['onboarding_completed'] == true ? 1 : 0
          ..['sex'] = null
          ..['activity_level'] = null
          ..['fitness_goal'] = null
          ..['sync_status'] = 'synced';
        record.removeWhere((key, value) =>
            value == null ||
            key == 'sex' ||
            key == 'activity_level' ||
            key == 'fitness_goal');
        await database.insert('profiles', record,
            conflictAlgorithm: ConflictAlgorithm.replace);

        await _pullNutritionData(
          supabase,
          database,
          appUserId,
          (profile['daily_budget_php'] as num).toDouble(),
        );
        await _pullTrackingData(supabase, database, appUserId);
      }
    } catch (_) {}
  }

  static Future<void> _pullNutritionData(
    SupabaseClient supabase,
    Database database,
    String appUserId,
    double dailyBudgetPhp,
  ) async {
    try {
      final targets = await supabase
          .from('nutrition_target')
          .select(
            '*, nutrition_formula_version(version_code), '
            'fitness_goal(goal_code)',
          )
          .eq('user_id', appUserId);
      for (final target in targets) {
        final record = <String, dynamic>{
          'target_id': target['target_id'],
          'user_id': appUserId,
          'formula_version_code':
              (target['nutrition_formula_version'] as Map?)?['version_code'] ??
                  'mifflin_v1',
          'fitness_goal_code':
              (target['fitness_goal'] as Map?)?['goal_code'] ?? 'maintenance',
          'source_weight_log_id': target['source_weight_log_id'],
          'bmr': target['bmr'],
          'tdee': target['tdee'],
          'calorie_target': target['calorie_target'],
          'protein_target_g': target['protein_target_g'],
          'carbs_target_g': target['carbs_target_g'],
          'fat_target_g': target['fat_target_g'],
          'water_target_ml': target['water_target_ml'],
          'daily_budget_php': dailyBudgetPhp,
          'effective_from': target['effective_from'],
          'effective_to': target['effective_to'],
          'is_active': target['is_active'] == true ? 1 : 0,
          'sync_status': 'synced',
          'created_at': target['created_at'],
        };
        record.removeWhere((_, value) => value == null);
        await database.insert(
          'nutrition_targets',
          record,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final snapshots = await supabase
          .from('daily_target_snapshot')
          .select()
          .eq('user_id', appUserId);
      for (final snapshot in snapshots) {
        await database.insert(
          'daily_target_snapshots',
          <String, dynamic>{
            ...snapshot,
            'sync_status': 'synced',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {
      // Profile hydration remains usable when optional target history fails.
    }
  }

  static Future<void> _pullTrackingData(
    SupabaseClient supabase,
    Database database,
    String appUserId,
  ) async {
    try {
      final weightLogs =
          await supabase.from('weight_log').select().eq('user_id', appUserId);
      for (final row in weightLogs) {
        await database.insert(
          'weight_logs',
          <String, dynamic>{...row, 'sync_status': 'synced'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {}

    try {
      final waterLogs =
          await supabase.from('water_log').select().eq('user_id', appUserId);
      for (final row in waterLogs) {
        await database.insert(
          'water_logs',
          <String, dynamic>{...row, 'sync_status': 'synced'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {}

    try {
      final mealLogs = await supabase
          .from('meal_log')
          .select('*, meal_type(meal_type_code), log_source(source_code)')
          .eq('user_id', appUserId);
      for (final row in mealLogs) {
        final record = Map<String, dynamic>.from(row)
          ..remove('meal_type_id')
          ..remove('log_source_id')
          ..['meal_type_code'] =
              (row['meal_type'] as Map?)?['meal_type_code'] ?? 'snack'
          ..['log_source_code'] =
              (row['log_source'] as Map?)?['source_code'] ?? 'manual'
          ..['is_deleted'] = row['is_deleted'] == true ? 1 : 0
          ..['sync_status'] = 'synced'
          ..remove('meal_type')
          ..remove('log_source');
        await database.insert(
          'meal_logs',
          record,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {}

    try {
      final mealPlans = await supabase
          .from('meal_plan')
          .select(
            '*, meal_type(meal_type_code), '
            'meal_plan_status(status_code)',
          )
          .eq('user_id', appUserId);
      for (final row in mealPlans) {
        final record = Map<String, dynamic>.from(row)
          ..remove('meal_type_id')
          ..remove('status_id')
          ..['meal_type_code'] =
              (row['meal_type'] as Map?)?['meal_type_code'] ?? 'snack'
          ..['status_code'] =
              (row['meal_plan_status'] as Map?)?['status_code'] ?? 'planned'
          ..['sync_status'] = 'synced'
          ..remove('meal_type')
          ..remove('meal_plan_status');
        await database.insert(
          'meal_plans',
          record,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {}
  }
}
