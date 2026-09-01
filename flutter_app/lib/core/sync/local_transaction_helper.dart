import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database_provider.dart';

class LocalTransactionHelper {
  final DatabaseProvider _dbProvider;
  final Uuid _uuid = const Uuid();

  LocalTransactionHelper(this._dbProvider);

  /// Transaction 1: Complete onboarding
  /// Creates profile, initial weight log, nutrition target, daily snapshot, and sync queue rows
  Future<void> completeOnboarding({
    required String userId,
    required Map<String, dynamic> profileData,
    required Map<String, dynamic> nutritionTargetData,
    required Map<String, dynamic> dailySnapshotData,
    required Map<String, dynamic> weightLogData,
  }) async {
    final db = await _dbProvider.database;
    final operationId = _uuid.v4();
    final clientSequence = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final existingProfiles = await txn.query(
        'profiles',
        columns: ['user_id'],
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      final profileExists = existingProfiles.isNotEmpty;

      if (profileExists) {
        await txn.update(
          'profiles',
          {
            ...profileData,
            'sync_status': 'pending',
            'updated_at': nowIso,
          },
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      } else {
        await txn.insert('profiles', {
          'user_id': userId,
          ...profileData,
          'sync_status': 'pending',
          'created_at': nowIso,
          'updated_at': nowIso,
        });
      }

      await txn.insert('weight_logs', {
        'weight_log_id': weightLogData['weight_log_id'],
        'user_id': userId,
        'weight_kg': weightLogData['weight_kg'],
        'logged_at': weightLogData['logged_at'],
        'sync_status': 'pending',
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      await txn.update(
        'nutrition_targets',
        {
          'is_active': 0,
          'effective_to': nowIso,
        },
        where: 'user_id = ? AND is_active = 1',
        whereArgs: [userId],
      );

      await txn.insert('nutrition_targets', {
        'target_id': nutritionTargetData['target_id'],
        'user_id': userId,
        ...nutritionTargetData,
        'sync_status': 'pending',
        'created_at': nowIso,
      });

      final existingSnapshots = await txn.query(
        'daily_target_snapshots',
        columns: ['snapshot_id'],
        where: 'user_id = ? AND target_date = ?',
        whereArgs: [userId, dailySnapshotData['target_date']],
        limit: 1,
      );
      final snapshotExists = existingSnapshots.isNotEmpty;

      await txn.insert(
          'daily_target_snapshots',
          {
            'snapshot_id': dailySnapshotData['snapshot_id'],
            'user_id': userId,
            ...dailySnapshotData,
            'sync_status': 'pending',
            'created_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      await _enqueueSync(txn, userId, operationId, clientSequence, 'profile',
          userId, profileExists ? 'update' : 'create', profileData);
      await _enqueueSync(
          txn,
          userId,
          _uuid.v4(),
          clientSequence + 1,
          'weight_log',
          weightLogData['weight_log_id'],
          'create',
          weightLogData);
      await _enqueueSync(
          txn,
          userId,
          _uuid.v4(),
          clientSequence + 2,
          'nutrition_target',
          nutritionTargetData['target_id'],
          'create',
          nutritionTargetData);
      await _enqueueSync(
          txn,
          userId,
          _uuid.v4(),
          clientSequence + 3,
          'daily_target_snapshot',
          dailySnapshotData['snapshot_id'],
          snapshotExists ? 'update' : 'create',
          dailySnapshotData);
    });
  }

  /// Transaction 2: Create meal log + sync queue
  Future<void> createMealLog(Map<String, dynamic> mealLogData) async {
    final db = await _dbProvider.database;
    final operationId = _uuid.v4();
    final clientSequence = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.insert('meal_logs', {
        ...mealLogData,
        'sync_status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _enqueueSync(
          txn,
          mealLogData['user_id'],
          operationId,
          clientSequence,
          'meal_log',
          mealLogData['meal_log_id'],
          'create',
          mealLogData);
    });
  }

  /// Transaction 3: Update meal log + sync queue
  Future<void> updateMealLog(Map<String, dynamic> mealLogData) async {
    final db = await _dbProvider.database;
    final operationId = _uuid.v4();
    final clientSequence = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.update(
        'meal_logs',
        {
          ...mealLogData,
          'sync_status': 'pending',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'meal_log_id = ?',
        whereArgs: [mealLogData['meal_log_id']],
      );
      await _enqueueSync(
          txn,
          mealLogData['user_id'],
          operationId,
          clientSequence,
          'meal_log',
          mealLogData['meal_log_id'],
          'update',
          mealLogData);
    });
  }

  /// Transaction 4: Soft delete meal log + sync queue
  Future<void> deleteMealLog(String mealLogId, String userId) async {
    final db = await _dbProvider.database;
    final operationId = _uuid.v4();
    final clientSequence = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.update(
        'meal_logs',
        {
          'is_deleted': 1,
          'sync_status': 'pending',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'meal_log_id = ?',
        whereArgs: [mealLogId],
      );
      await _enqueueSync(txn, userId, operationId, clientSequence, 'meal_log',
          mealLogId, 'delete', {'meal_log_id': mealLogId, 'is_deleted': true});
    });
  }

  /// Transaction 5: Convert meal plan to meal log
  Future<void> convertPlanToLog({
    required Map<String, dynamic> mealLogData,
    required String mealPlanId,
    required String userId,
    bool markPlanCompleted = true,
  }) async {
    final db = await _dbProvider.database;
    final logOperationId = _uuid.v4();
    final planOperationId = _uuid.v4();
    final clientSequence = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final queuedMealLog = <String, dynamic>{
        ...mealLogData,
        'log_source_code': 'planner',
      };
      await txn.insert('meal_logs', {
        ...queuedMealLog,
        'sync_status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await _enqueueSync(txn, userId, logOperationId, clientSequence,
          'meal_log', mealLogData['meal_log_id'], 'create', queuedMealLog);

      if (markPlanCompleted) {
        final planRows = await txn.query(
          'meal_plans',
          where: 'meal_plan_id = ?',
          whereArgs: [mealPlanId],
          limit: 1,
        );
        final queuedPlan = <String, dynamic>{
          if (planRows.isNotEmpty) ...planRows.first,
          'meal_plan_id': mealPlanId,
          'status_code': 'logged',
          'converted_meal_log_id': mealLogData['meal_log_id'],
        };
        await txn.update(
          'meal_plans',
          {
            'status_code': 'logged',
            'converted_meal_log_id': mealLogData['meal_log_id'],
            'sync_status': 'pending',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'meal_plan_id = ?',
          whereArgs: [mealPlanId],
        );
        await _enqueueSync(txn, userId, planOperationId, clientSequence + 1,
            'meal_plan', mealPlanId, 'update', queuedPlan);
      }
    });
  }

  /// Transaction 6: Save weight log + recalculate targets + daily snapshot
  Future<void> saveWeightLogAndRecalculate({
    required Map<String, dynamic> weightLogData,
    required Map<String, dynamic> newTargetData,
    required Map<String, dynamic> dailySnapshotData,
  }) async {
    final db = await _dbProvider.database;
    final userId = weightLogData['user_id'];
    final baseSequence = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.insert('weight_logs', {
        ...weightLogData,
        'sync_status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await txn.update(
        'nutrition_targets',
        {
          'is_active': 0,
          'effective_to': DateTime.now().toUtc().toIso8601String()
        },
        where: 'user_id = ? AND is_active = 1',
        whereArgs: [userId],
      );

      await txn.insert('nutrition_targets', {
        'target_id': newTargetData['target_id'],
        'user_id': userId,
        ...newTargetData,
        'is_active': 1,
        'sync_status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      await txn.insert(
          'daily_target_snapshots',
          {
            'snapshot_id': dailySnapshotData['snapshot_id'],
            'user_id': userId,
            ...dailySnapshotData,
            'sync_status': 'pending',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      await _enqueueSync(txn, userId, _uuid.v4(), baseSequence, 'weight_log',
          weightLogData['weight_log_id'], 'create', weightLogData);
      await _enqueueSync(
          txn,
          userId,
          _uuid.v4(),
          baseSequence + 1,
          'nutrition_target',
          newTargetData['target_id'],
          'create',
          newTargetData);
      await _enqueueSync(
          txn,
          userId,
          _uuid.v4(),
          baseSequence + 2,
          'daily_target_snapshot',
          dailySnapshotData['snapshot_id'],
          'create',
          dailySnapshotData);
    });
  }

  /// Recalculate targets without creating a duplicate weight log. This is
  /// used when profile inputs such as age, height, activity, or goal change.
  Future<void> recalculateNutritionTarget({
    required String userId,
    required Map<String, dynamic> newTargetData,
    required Map<String, dynamic> dailySnapshotData,
  }) async {
    final db = await _dbProvider.database;
    final baseSequence = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'nutrition_targets',
        {'is_active': 0, 'effective_to': now},
        where: 'user_id = ? AND is_active = 1',
        whereArgs: [userId],
      );

      await txn.insert('nutrition_targets', {
        'target_id': newTargetData['target_id'],
        'user_id': userId,
        ...newTargetData,
        'is_active': 1,
        'sync_status': 'pending',
        'created_at': now,
      });

      final existingSnapshots = await txn.query(
        'daily_target_snapshots',
        columns: ['snapshot_id'],
        where: 'user_id = ? AND target_date = ?',
        whereArgs: [userId, dailySnapshotData['target_date']],
        limit: 1,
      );
      await txn.insert(
        'daily_target_snapshots',
        {
          'snapshot_id': dailySnapshotData['snapshot_id'],
          'user_id': userId,
          ...dailySnapshotData,
          'sync_status': 'pending',
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _enqueueSync(
        txn,
        userId,
        _uuid.v4(),
        baseSequence,
        'nutrition_target',
        newTargetData['target_id'],
        'create',
        newTargetData,
      );
      await _enqueueSync(
        txn,
        userId,
        _uuid.v4(),
        baseSequence + 1,
        'daily_target_snapshot',
        dailySnapshotData['snapshot_id'],
        existingSnapshots.isEmpty ? 'create' : 'update',
        dailySnapshotData,
      );
    });
  }

  /// Transaction 7: Delete weight log (hard) + recalculate
  Future<void> deleteWeightLogAndRecalculate({
    required String weightLogId,
    required String userId,
    Map<String, dynamic>? newLatestWeightData,
    Map<String, dynamic>? newTargetData,
    Map<String, dynamic>? dailySnapshotData,
  }) async {
    final db = await _dbProvider.database;
    final baseSequence = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.delete('weight_logs',
          where: 'weight_log_id = ?', whereArgs: [weightLogId]);

      await _enqueueSync(txn, userId, _uuid.v4(), baseSequence, 'weight_log',
          weightLogId, 'delete', {'weight_log_id': weightLogId});

      if (newLatestWeightData != null &&
          newTargetData != null &&
          dailySnapshotData != null) {
        await txn.update(
          'nutrition_targets',
          {
            'is_active': 0,
            'effective_to': DateTime.now().toUtc().toIso8601String()
          },
          where: 'user_id = ? AND is_active = 1',
          whereArgs: [userId],
        );

        await txn.insert('nutrition_targets', {
          'target_id': newTargetData['target_id'],
          'user_id': userId,
          ...newTargetData,
          'is_active': 1,
          'sync_status': 'pending',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        await txn.insert(
            'daily_target_snapshots',
            {
              'snapshot_id': dailySnapshotData['snapshot_id'],
              'user_id': userId,
              ...dailySnapshotData,
              'sync_status': 'pending',
              'created_at': DateTime.now().toUtc().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);

        await _enqueueSync(
            txn,
            userId,
            _uuid.v4(),
            baseSequence + 1,
            'nutrition_target',
            newTargetData['target_id'],
            'create',
            newTargetData);
        await _enqueueSync(
            txn,
            userId,
            _uuid.v4(),
            baseSequence + 2,
            'daily_target_snapshot',
            dailySnapshotData['snapshot_id'],
            'create',
            dailySnapshotData);
      }
    });
  }

  /// Hard delete water log + sync tombstone
  Future<void> deleteWaterLog(String waterLogId, String userId) async {
    final db = await _dbProvider.database;
    final operationId = _uuid.v4();
    final clientSequence = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.delete('water_logs',
          where: 'water_log_id = ?', whereArgs: [waterLogId]);
      await _enqueueSync(txn, userId, operationId, clientSequence, 'water_log',
          waterLogId, 'delete', {'water_log_id': waterLogId});
    });
  }

  /// Create water log + sync queue in one transaction.
  Future<void> createWaterLog(Map<String, dynamic> waterLogData) async {
    final db = await _dbProvider.database;
    final operationId = _uuid.v4();
    final clientSequence = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert('water_logs', {
        ...waterLogData,
        'sync_status': 'pending',
        'created_at': now,
        'updated_at': now,
      });
      await _enqueueSync(
        txn,
        waterLogData['user_id'],
        operationId,
        clientSequence,
        'water_log',
        waterLogData['water_log_id'],
        'create',
        waterLogData,
      );
    });
  }

  /// Hard delete planned meal plan + sync tombstone
  Future<void> deletePlannedMeal(String mealPlanId, String userId) async {
    final db = await _dbProvider.database;
    final operationId = _uuid.v4();
    final clientSequence = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.delete(
        'meal_plans',
        where: 'meal_plan_id = ? AND status_code = ?',
        whereArgs: [mealPlanId, 'planned'],
      );
      await _enqueueSync(txn, userId, operationId, clientSequence, 'meal_plan',
          mealPlanId, 'delete', {'meal_plan_id': mealPlanId});
    });
  }

  Future<void> _enqueueSync(
    Transaction txn,
    String userId,
    String operationId,
    int clientSequence,
    String entityTypeCode,
    String entityId,
    String operationCode,
    Map<String, dynamic> payload,
  ) async {
    await txn.insert('sync_queue', {
      'sync_queue_id': _uuid.v4(),
      'user_id': userId,
      'operation_id': operationId,
      'entity_type_code': entityTypeCode,
      'entity_id': entityId,
      'operation_code': operationCode,
      'payload_json': jsonEncode(payload),
      'client_sequence': clientSequence,
      'attempt_count': 0,
      'sync_status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
