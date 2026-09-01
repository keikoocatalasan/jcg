import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jcg_fitness/core/database/migration_v1.dart';
import 'package:jcg_fitness/core/database/migration_v2.dart';
import 'package:jcg_fitness/core/database/migration_v3.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');

    final batch = db.batch();
    await MigrationV1.run(batch);
    await batch.commit(noResult: true);
  });

  tearDown(() async {
    await db.close();
  });

  group('Schema Creation', () {
    test('create schema runs without error', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final tableNames = tables.map((r) => r['name'] as String).toList();
      expect(tableNames.length, greaterThan(17));

      expect(tableNames, contains('app_settings'));
      expect(tableNames, contains('profiles'));
      expect(tableNames, contains('nutrition_targets'));
      expect(tableNames, contains('daily_target_snapshots'));
      expect(tableNames, contains('foods'));
      expect(tableNames, contains('meal_logs'));
      expect(tableNames, contains('water_logs'));
      expect(tableNames, contains('weight_logs'));
      expect(tableNames, contains('meal_plans'));
      expect(tableNames, contains('recommendation_sessions'));
      expect(tableNames, contains('recommendation_items'));
      expect(tableNames, contains('ai_scans'));
      expect(tableNames, contains('ai_scan_predictions'));
      expect(tableNames, contains('ai_scan_feedback'));
      expect(tableNames, contains('chat_sessions'));
      expect(tableNames, contains('chat_messages'));
      expect(tableNames, contains('community_cache'));
      expect(tableNames, contains('sync_queue'));
    });

    test('all indexes are created', () async {
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'",
      );
      final indexNames = indexes.map((r) => r['name'] as String).toList();

      expect(indexNames, contains('idx_foods_search'));
      expect(indexNames, contains('idx_foods_category'));
      expect(indexNames, contains('idx_foods_user'));
      expect(indexNames, contains('idx_meal_logs_user_date'));
      expect(indexNames, contains('idx_meal_logs_active'));
      expect(indexNames, contains('idx_water_logs_user_date'));
      expect(indexNames, contains('idx_weight_logs_user_date'));
      expect(indexNames, contains('idx_meal_plans_user_date'));
      expect(indexNames, contains('idx_ai_scans_client'));
      expect(indexNames, contains('idx_chat_messages_session'));
      expect(indexNames, contains('idx_sync_queue_status'));
      expect(indexNames, contains('idx_sync_queue_operation'));
      expect(indexNames, contains('idx_sync_queue_entity'));
    });

    test('idempotent: running migration twice does not error', () async {
      final batch = db.batch();
      await MigrationV1.run(batch);
      await batch.commit(noResult: true);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      expect(tables.length, greaterThan(17));
    });
  });

  group('Migration V2', () {
    test('adds retryable scan feedback fields and is idempotent', () async {
      await MigrationV2.run(db);
      await MigrationV2.run(db);

      final columns = await db.rawQuery('PRAGMA table_info(ai_scan_feedback)');
      final names = columns.map((row) => row['name']).toSet();
      expect(
          names,
          containsAll(<String>{
            'client_scan_id',
            'selected_food_id',
            'was_helpful',
            'feedback_text',
            'created_at',
          }));
    });
  });

  group('Migration V3', () {
    test('adds food descriptions and is idempotent', () async {
      await MigrationV3.run(db);
      await MigrationV3.run(db);

      final columns = await db.rawQuery('PRAGMA table_info(foods)');
      final names = columns.map((row) => row['name']).toSet();
      expect(names, contains('description'));

      await db.insert('foods', {
        'food_id': 'food-description',
        'category_name': 'Other',
        'subcategory': 'Prepared',
        'description': 'A test food description',
        'food_name': 'Test Food',
        'normalized_name': 'test food',
        'calories': 100.0,
        'protein_g': 5.0,
        'carbs_g': 10.0,
        'fat_g': 2.0,
        'estimated_price_php': 20.0,
      });

      final row = await db.query(
        'foods',
        columns: ['subcategory', 'description'],
        where: 'food_id = ?',
        whereArgs: ['food-description'],
      );
      expect(row.single['subcategory'], 'Prepared');
      expect(row.single['description'], 'A test food description');
    });
  });

  group('Profile CRUD', () {
    test('insert and read profile', () async {
      await db.insert('profiles', {
        'user_id': 'u1',
        'auth_user_id': 'auth_u1',
        'role_code': 'user',
        'account_status_code': 'active',
        'nickname': 'TestUser',
        'sex_code': 'male',
        'age': 25,
        'height_cm': 175.0,
        'current_weight_kg': 70.0,
        'target_weight_kg': 65.0,
        'activity_level_code': 'moderate',
        'fitness_goal_code': 'cutting',
        'daily_budget_php': 300.0,
        'onboarding_completed': 1,
        'allergies': 'dairy,peanut',
        'dietary_restrictions': '',
        'disclaimer_accepted': 1,
        'disclaimer_version': 'v1',
        'sync_status': 'synced',
        'created_at': '2026-06-13T00:00:00Z',
        'updated_at': '2026-06-13T00:00:00Z',
      });

      final result = await db.query(
        'profiles',
        where: 'user_id = ?',
        whereArgs: ['u1'],
      );

      expect(result.length, 1);
      expect(result.first['nickname'], 'TestUser');
      expect(result.first['age'], 25);
      expect(result.first['daily_budget_php'], 300.0);
      expect(result.first['allergies'], 'dairy,peanut');
    });

    test('update profile and verify', () async {
      await db.insert('profiles', {
        'user_id': 'u2',
        'auth_user_id': 'auth_u2',
        'role_code': 'user',
        'account_status_code': 'active',
        'nickname': 'OldName',
        'sex_code': 'female',
        'age': 30,
        'height_cm': 160.0,
        'current_weight_kg': 55.0,
        'target_weight_kg': 52.0,
        'activity_level_code': 'light',
        'fitness_goal_code': 'maintenance',
        'daily_budget_php': 250.0,
        'onboarding_completed': 1,
        'sync_status': 'synced',
        'created_at': '2026-06-13T00:00:00Z',
        'updated_at': '2026-06-13T00:00:00Z',
      });

      await db.update(
        'profiles',
        {'nickname': 'NewName', 'current_weight_kg': 54.0},
        where: 'user_id = ?',
        whereArgs: ['u2'],
      );

      final result = await db.query(
        'profiles',
        where: 'user_id = ?',
        whereArgs: ['u2'],
      );

      expect(result.first['nickname'], 'NewName');
      expect(result.first['current_weight_kg'], 54.0);
      expect(result.first['age'], 30);
    });

    test('delete profile', () async {
      await db.insert('profiles', {
        'user_id': 'u3',
        'auth_user_id': 'auth_u3',
        'role_code': 'user',
        'account_status_code': 'active',
        'nickname': 'ToDelete',
        'sex_code': 'male',
        'age': 20,
        'height_cm': 170.0,
        'current_weight_kg': 65.0,
        'activity_level_code': 'active',
        'fitness_goal_code': 'bulking',
        'daily_budget_php': 400.0,
        'onboarding_completed': 1,
        'sync_status': 'synced',
        'created_at': '2026-06-13T00:00:00Z',
        'updated_at': '2026-06-13T00:00:00Z',
      });

      final deleted = await db.delete(
        'profiles',
        where: 'user_id = ?',
        whereArgs: ['u3'],
      );
      expect(deleted, 1);

      final result = await db.query(
        'profiles',
        where: 'user_id = ?',
        whereArgs: ['u3'],
      );
      expect(result, isEmpty);
    });
  });

  group('Meal Log Operations', () {
    setUp(() async {
      await db.insert('profiles', {
        'user_id': 'meal_user',
        'auth_user_id': 'auth_meal_user',
        'role_code': 'user',
        'account_status_code': 'active',
        'nickname': 'MealLogger',
        'sex_code': 'male',
        'age': 25,
        'height_cm': 175.0,
        'current_weight_kg': 70.0,
        'activity_level_code': 'moderate',
        'fitness_goal_code': 'cutting',
        'daily_budget_php': 300.0,
        'onboarding_completed': 1,
        'sync_status': 'synced',
        'created_at': '2026-06-13T00:00:00Z',
        'updated_at': '2026-06-13T00:00:00Z',
      });
    });

    test('insert meal log and query by date', () async {
      await db.insert('meal_logs', {
        'meal_log_id': 'ml1',
        'user_id': 'meal_user',
        'food_id': 'f1',
        'meal_type_code': 'lunch',
        'log_source_code': 'manual',
        'food_name_snapshot': 'Chicken Breast',
        'serving_grams_snapshot': 150.0,
        'quantity': 1.5,
        'calories_snapshot': 426.0,
        'protein_g_snapshot': 79.5,
        'carbs_g_snapshot': 0.0,
        'fat_g_snapshot': 9.0,
        'cost_php_snapshot': 82.5,
        'logged_at': '2026-06-13T12:00:00Z',
        'sync_status': 'synced',
        'created_at': '2026-06-13T12:00:00Z',
        'updated_at': '2026-06-13T12:00:00Z',
      });

      await db.insert('meal_logs', {
        'meal_log_id': 'ml2',
        'user_id': 'meal_user',
        'food_id': 'f2',
        'meal_type_code': 'lunch',
        'log_source_code': 'manual',
        'food_name_snapshot': 'Rice',
        'serving_grams_snapshot': 200.0,
        'quantity': 1.0,
        'calories_snapshot': 260.0,
        'protein_g_snapshot': 4.0,
        'carbs_g_snapshot': 58.0,
        'fat_g_snapshot': 0.4,
        'cost_php_snapshot': 15.0,
        'logged_at': '2026-06-13T12:00:00Z',
        'sync_status': 'synced',
        'created_at': '2026-06-13T12:00:00Z',
        'updated_at': '2026-06-13T12:00:00Z',
      });

      final results = await db.query(
        'meal_logs',
        where: 'user_id = ? AND date(logged_at) = ?',
        whereArgs: ['meal_user', '2026-06-13'],
      );

      expect(results.length, 2);
      expect(
        results.any((r) => r['food_name_snapshot'] == 'Chicken Breast'),
        true,
      );
      expect(results.any((r) => r['food_name_snapshot'] == 'Rice'), true);
    });

    test('soft delete meal log', () async {
      await db.insert('meal_logs', {
        'meal_log_id': 'ml3',
        'user_id': 'meal_user',
        'meal_type_code': 'breakfast',
        'log_source_code': 'manual',
        'food_name_snapshot': 'Oatmeal',
        'serving_grams_snapshot': 100.0,
        'quantity': 1.0,
        'calories_snapshot': 150.0,
        'protein_g_snapshot': 5.0,
        'carbs_g_snapshot': 27.0,
        'fat_g_snapshot': 2.5,
        'cost_php_snapshot': 20.0,
        'logged_at': '2026-06-13T07:00:00Z',
        'sync_status': 'synced',
        'created_at': '2026-06-13T07:00:00Z',
        'updated_at': '2026-06-13T07:00:00Z',
      });

      await db.update(
        'meal_logs',
        {'is_deleted': 1, 'updated_at': '2026-06-13T08:00:00Z'},
        where: 'meal_log_id = ?',
        whereArgs: ['ml3'],
      );

      final all = await db.query('meal_logs');
      expect(all.length, 1);

      final active = await db.query(
        'meal_logs',
        where: 'is_deleted = 0',
      );
      expect(active, isEmpty);
    });
  });

  group('Food Search', () {
    setUp(() async {
      final foods = [
        {
          'food_id': 'f1',
          'category_name': 'Meat',
          'food_name': 'Chicken Breast',
          'normalized_name': 'chicken breast',
          'calories': 284.0,
          'protein_g': 53.0,
          'carbs_g': 0.0,
          'fat_g': 6.0,
          'estimated_price_php': 55.0,
          'is_official': 1,
          'is_active': 1,
          'is_deleted': 0,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        },
        {
          'food_id': 'f2',
          'category_name': 'Rice and Grains',
          'food_name': 'White Rice',
          'normalized_name': 'white rice',
          'calories': 260.0,
          'protein_g': 4.0,
          'carbs_g': 58.0,
          'fat_g': 0.4,
          'estimated_price_php': 10.0,
          'is_official': 1,
          'is_active': 1,
          'is_deleted': 0,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        },
        {
          'food_id': 'f3',
          'category_name': 'Fruits',
          'food_name': 'Banana',
          'normalized_name': 'banana',
          'calories': 105.0,
          'protein_g': 1.3,
          'carbs_g': 27.0,
          'fat_g': 0.4,
          'estimated_price_php': 8.0,
          'is_official': 1,
          'is_active': 1,
          'is_deleted': 0,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        },
        {
          'food_id': 'f4',
          'category_name': 'Seafood',
          'food_name': 'Bangus',
          'normalized_name': 'bangus',
          'calories': 200.0,
          'protein_g': 22.0,
          'carbs_g': 0.0,
          'fat_g': 12.0,
          'estimated_price_php': 80.0,
          'is_official': 1,
          'is_active': 1,
          'is_deleted': 0,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        },
      ];

      for (final food in foods) {
        await db.insert('foods', food);
      }
    });

    test('food search by name returns matches', () async {
      final results = await db.query(
        'foods',
        where: 'normalized_name LIKE ?',
        whereArgs: ['%chicken%'],
      );
      expect(results.length, 1);
      expect(results.first['food_name'], 'Chicken Breast');
    });

    test('food search by partial name returns multiple', () async {
      final results = await db.query(
        'foods',
        where: 'normalized_name LIKE ?',
        whereArgs: ['%an%'],
      );
      // banana, bangus
      expect(results.length, 2);
    });

    test('food search by category and name', () async {
      final results = await db.query(
        'foods',
        where: 'category_name = ? AND normalized_name LIKE ?',
        whereArgs: ['Fruits', '%ban%'],
      );
      expect(results.length, 1);
      expect(results.first['food_name'], 'Banana');
    });

    test('food search with no matches returns empty', () async {
      final results = await db.query(
        'foods',
        where: 'normalized_name LIKE ?',
        whereArgs: ['%nonexistent%'],
      );
      expect(results, isEmpty);
    });

    test('query active official foods only', () async {
      final results = await db.query(
        'foods',
        where: 'is_official = 1 AND is_active = 1 AND is_deleted = 0',
      );
      expect(results.length, 4);
    });
  });

  group('Water Log', () {
    setUp(() async {
      await db.insert('profiles', {
        'user_id': 'water_user',
        'auth_user_id': 'auth_water',
        'role_code': 'user',
        'account_status_code': 'active',
        'nickname': 'WaterDrinker',
        'sex_code': 'male',
        'age': 25,
        'height_cm': 175.0,
        'current_weight_kg': 70.0,
        'activity_level_code': 'moderate',
        'fitness_goal_code': 'maintenance',
        'daily_budget_php': 300.0,
        'onboarding_completed': 1,
        'sync_status': 'synced',
        'created_at': '2026-06-13T00:00:00Z',
        'updated_at': '2026-06-13T00:00:00Z',
      });
    });

    test('insert water log and query by user and date', () async {
      await db.insert('water_logs', {
        'water_log_id': 'wl1',
        'user_id': 'water_user',
        'amount_ml': 500,
        'logged_at': '2026-06-13T08:00:00Z',
        'sync_status': 'synced',
        'created_at': '2026-06-13T08:00:00Z',
        'updated_at': '2026-06-13T08:00:00Z',
      });

      final results = await db.query(
        'water_logs',
        where: 'user_id = ? AND date(logged_at) = ?',
        whereArgs: ['water_user', '2026-06-13'],
      );

      expect(results.length, 1);
      expect(results.first['amount_ml'], 500);
    });

    test('sum water totals for a day', () async {
      await db.insert('water_logs', {
        'water_log_id': 'wl2',
        'user_id': 'water_user',
        'amount_ml': 300,
        'logged_at': '2026-06-13T09:00:00Z',
      });
      await db.insert('water_logs', {
        'water_log_id': 'wl3',
        'user_id': 'water_user',
        'amount_ml': 200,
        'logged_at': '2026-06-13T10:00:00Z',
      });
      await db.insert('water_logs', {
        'water_log_id': 'wl4',
        'user_id': 'water_user',
        'amount_ml': 500,
        'logged_at': '2026-06-13T12:00:00Z',
      });

      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_ml), 0) as total FROM water_logs WHERE user_id = ? AND date(logged_at) = ?',
        ['water_user', '2026-06-13'],
      );

      expect(result.first['total'], 1000);
    });
  });

  group('Weight Log', () {
    setUp(() async {
      await db.insert('profiles', {
        'user_id': 'weight_user',
        'auth_user_id': 'auth_weight',
        'role_code': 'user',
        'account_status_code': 'active',
        'nickname': 'WeighIn',
        'sex_code': 'female',
        'age': 30,
        'height_cm': 160.0,
        'current_weight_kg': 55.0,
        'activity_level_code': 'light',
        'fitness_goal_code': 'maintenance',
        'daily_budget_php': 250.0,
        'onboarding_completed': 1,
        'sync_status': 'synced',
        'created_at': '2026-06-01T00:00:00Z',
        'updated_at': '2026-06-01T00:00:00Z',
      });
    });

    test('insert and query weight logs in date range', () async {
      await db.insert('weight_logs', {
        'weight_log_id': 'wg1',
        'user_id': 'weight_user',
        'weight_kg': 55.0,
        'logged_at': '2026-06-01T07:00:00Z',
      });
      await db.insert('weight_logs', {
        'weight_log_id': 'wg2',
        'user_id': 'weight_user',
        'weight_kg': 54.5,
        'logged_at': '2026-06-07T07:00:00Z',
      });
      await db.insert('weight_logs', {
        'weight_log_id': 'wg3',
        'user_id': 'weight_user',
        'weight_kg': 54.0,
        'logged_at': '2026-06-13T07:00:00Z',
      });

      final results = await db.query(
        'weight_logs',
        where: 'user_id = ? AND date(logged_at) BETWEEN ? AND ?',
        whereArgs: ['weight_user', '2026-06-01', '2026-06-07'],
      );

      expect(results.length, 2);
    });
  });

  group('Sync Queue', () {
    test('insert and query pending sync items', () async {
      await db.insert('profiles', {
        'user_id': 'sync_user',
        'auth_user_id': 'auth_sync',
        'role_code': 'user',
        'account_status_code': 'active',
        'nickname': 'SyncUser',
        'sex_code': 'male',
        'age': 25,
        'height_cm': 175.0,
        'current_weight_kg': 70.0,
        'activity_level_code': 'moderate',
        'fitness_goal_code': 'cutting',
        'daily_budget_php': 300.0,
        'onboarding_completed': 1,
        'sync_status': 'synced',
        'created_at': '2026-06-13T00:00:00Z',
        'updated_at': '2026-06-13T00:00:00Z',
      });

      await db.insert('sync_queue', {
        'sync_queue_id': 'sq1',
        'user_id': 'sync_user',
        'operation_id': 'op_abc123',
        'entity_type_code': 'meal_log',
        'entity_id': 'ml_pending',
        'operation_code': 'insert',
        'payload_json': '{}',
        'client_sequence': 1,
        'sync_status': 'pending',
        'created_at': '2026-06-13T00:00:00Z',
      });

      await db.insert('sync_queue', {
        'sync_queue_id': 'sq2',
        'user_id': 'sync_user',
        'operation_id': 'op_def456',
        'entity_type_code': 'food',
        'entity_id': 'f_pending',
        'operation_code': 'insert',
        'payload_json': '{}',
        'client_sequence': 2,
        'sync_status': 'pending',
        'created_at': '2026-06-13T00:00:00Z',
      });

      final pending = await db.query(
        'sync_queue',
        where: 'sync_status = ?',
        whereArgs: ['pending'],
      );

      expect(pending.length, 2);
    });
  });

  group('Foreign Key Enforcement', () {
    test('inserting meal_log with non-existent user_id fails', () async {
      await expectLater(
        db.insert('meal_logs', {
          'meal_log_id': 'orphan',
          'user_id': 'nonexistent',
          'meal_type_code': 'lunch',
          'log_source_code': 'manual',
          'food_name_snapshot': 'Test',
          'serving_grams_snapshot': 100,
          'quantity': 1,
          'calories_snapshot': 200,
          'protein_g_snapshot': 10,
          'carbs_g_snapshot': 20,
          'fat_g_snapshot': 5,
          'cost_php_snapshot': 50,
          'logged_at': '2026-06-13T12:00:00Z',
          'sync_status': 'pending',
          'created_at': '2026-06-13T12:00:00Z',
          'updated_at': '2026-06-13T12:00:00Z',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
