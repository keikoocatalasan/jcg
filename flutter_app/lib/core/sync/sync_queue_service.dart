import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_provider.dart';
import '../database/sync_queue_repository.dart';

class SyncResult {
  final int synced;
  final int failed;
  final int skipped;
  final int total;
  final List<String> errors;

  const SyncResult({
    this.synced = 0,
    this.failed = 0,
    this.skipped = 0,
    this.total = 0,
    this.errors = const [],
  });

  SyncResult copyWith({
    int? synced,
    int? failed,
    int? skipped,
    int? total,
    List<String>? errors,
  }) {
    return SyncResult(
      synced: synced ?? this.synced,
      failed: failed ?? this.failed,
      skipped: skipped ?? this.skipped,
      total: total ?? this.total,
      errors: errors ?? this.errors,
    );
  }

  @override
  String toString() =>
      'SyncResult(synced: $synced, failed: $failed, skipped: $skipped, total: $total)';
}

class SyncQueueService {
  final DatabaseProvider dbProvider;
  final SupabaseClient supabaseClient;
  late final SyncQueueRepository _repo;

  SyncQueueService(this.dbProvider, this.supabaseClient) {
    _repo = SyncQueueRepository(dbProvider);
  }

  static const syncOrder = [
    'profile',
    'nutrition_target',
    'daily_target_snapshot',
    'custom_food',
    'meal_log',
    'water_log',
    'weight_log',
    'meal_plan',
    'recommendation_session',
    'recommendation_item',
    'ai_scan',
    'ai_scan_prediction',
    'ai_scan_feedback',
    'chat_session',
    'chat_message',
  ];

  static const _maxAttempts = 5;

  Future<SyncResult> processSyncQueue() async {
    final items = await _repo.readPending();
    if (items.isEmpty) {
      return const SyncResult();
    }

    var synced = 0;
    var failed = 0;
    var skipped = 0;
    final errors = <String>[];

    final syncedEntities = <String, Set<String>>{};

    items.sort((left, right) {
      final leftOrder = syncOrder.indexOf(left.entityTypeCode);
      final rightOrder = syncOrder.indexOf(right.entityTypeCode);
      final entityComparison = (leftOrder < 0 ? syncOrder.length : leftOrder)
          .compareTo(rightOrder < 0 ? syncOrder.length : rightOrder);
      if (entityComparison != 0) return entityComparison;
      return left.clientSequence.compareTo(right.clientSequence);
    });

    for (final item in items) {
      try {
        final canProcess = await _canProcess(item, syncedEntities);
        if (!canProcess) {
          skipped++;
          continue;
        }

        await _executeOperation(item);
        final now = DateTime.now().toUtc().toIso8601String();
        await _markLocalEntitySynced(item);
        await _repo.markSynced(item.syncQueueId, serverSyncedAt: now);

        syncedEntities
            .putIfAbsent(item.entityTypeCode, () => {})
            .add(item.entityId);
        synced++;
      } catch (e) {
        final errorMsg = e.toString();
        errors.add('${item.entityTypeCode}/${item.entityId}: $errorMsg');

        try {
          await _repo.incrementAttempt(item.syncQueueId, error: errorMsg);
          final updated = await _repo.readById(item.syncQueueId);
          if (updated != null && updated.attemptCount >= _maxAttempts) {
            await _repo.updateSyncStatus(item.syncQueueId, 'failed');
            failed++;
          }
        } catch (_) {
          failed++;
        }
      }
    }

    return SyncResult(
      synced: synced,
      failed: failed,
      skipped: skipped,
      total: items.length,
      errors: errors,
    );
  }

  Future<void> _markLocalEntitySynced(SyncQueueEntry item) async {
    final db = await dbProvider.database;
    final table = _entityTypeToLocalTable(item.entityTypeCode);
    final primaryKey = _entityTypeToPkColumn(item.entityTypeCode);
    await db.update(
      table,
      {'sync_status': 'synced'},
      where: '$primaryKey = ?',
      whereArgs: [item.entityId],
    );
  }

  Future<bool> _canProcess(
    SyncQueueEntry item,
    Map<String, Set<String>> syncedEntities,
  ) async {
    final depType = item.dependsOnEntityType;
    final depId = item.dependsOnEntityId;
    if (depType == null || depId == null) return true;

    final alreadySynced = syncedEntities[depType]?.contains(depId) ?? false;
    if (alreadySynced) return true;

    final db = await dbProvider.database;
    final pending = await db.query(
      'sync_queue',
      where:
          'entity_type_code = ? AND entity_id = ? AND sync_status = ? AND sync_queue_id != ?',
      whereArgs: [depType, depId, 'pending', item.syncQueueId],
      limit: 1,
    );
    return pending.isEmpty;
  }

  Future<void> _executeOperation(SyncQueueEntry item) async {
    late final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
    } on FormatException {
      if (item.entityTypeCode != 'meal_plan') rethrow;
      final db = await dbProvider.database;
      final rows = await db.query(
        'meal_plans',
        where: 'meal_plan_id = ?',
        whereArgs: [item.entityId],
        limit: 1,
      );
      if (rows.isEmpty) rethrow;
      payload = Map<String, dynamic>.from(rows.first);
    }

    if (await _remoteVersionIsNewer(item, payload)) return;

    switch (item.entityTypeCode) {
      case 'profile':
        await _syncProfile(payload);
        return;
      case 'weight_log':
        await _syncWeightLog(item, payload);
        return;
      case 'nutrition_target':
        await _syncNutritionTarget(item, payload);
        return;
      case 'daily_target_snapshot':
        await _syncDailyTargetSnapshot(item, payload);
        return;
      case 'meal_log':
        await _syncMealLog(item, payload);
        return;
      case 'water_log':
        await _syncWaterLog(item, payload);
        return;
      case 'chat_session':
        await _syncChatSession(item, payload);
        return;
      case 'chat_message':
        await _syncChatMessage(item, payload);
        return;
      case 'meal_plan':
        await _syncMealPlan(item, payload);
        return;
      case 'recommendation_session':
        await _syncRecommendationSession(item, payload);
        return;
      case 'recommendation_item':
        await _syncRecommendationItem(item, payload);
        return;
      case 'custom_food':
        await _syncCustomFood(item, payload);
        return;
      case 'ai_scan_feedback':
        await _syncAiScanFeedback(item, payload);
        return;
    }

    final tableName = _entityTypeToTable(item.entityTypeCode);

    switch (item.operationCode) {
      case 'create':
        await _executeCreate(tableName, payload);
      case 'update':
        await _executeUpdate(tableName, item.entityId, payload);
      case 'delete':
        await _executeDelete(tableName, item.entityId, payload);
      default:
        throw Exception('Unknown operation code: ${item.operationCode}');
    }
  }

  Future<String> _currentAppUserId() async {
    final authUserId = supabaseClient.auth.currentUser?.id;
    if (authUserId == null) throw Exception('No authenticated sync user');
    final row = await supabaseClient
        .from('app_user')
        .select('user_id')
        .eq('auth_user_id', authUserId)
        .single();
    return row['user_id'] as String;
  }

  Future<int> _lookupId(
    String table,
    String codeColumn,
    String code,
    String idColumn,
  ) async {
    final row = await supabaseClient
        .from(table)
        .select(idColumn)
        .eq(codeColumn, code)
        .single();
    return row[idColumn] as int;
  }

  Future<void> _syncProfile(Map<String, dynamic> payload) async {
    final appUserId = await _currentAppUserId();
    final updateData = <String, dynamic>{'user_id': appUserId};

    if (payload.containsKey('sex_code')) {
      updateData['sex_id'] =
          await _lookupId('sex', 'sex_code', payload['sex_code'], 'sex_id');
    }
    if (payload.containsKey('activity_level_code')) {
      updateData['activity_level_id'] = await _lookupId(
        'activity_level',
        'activity_code',
        payload['activity_level_code'],
        'activity_level_id',
      );
    }
    if (payload.containsKey('fitness_goal_code')) {
      updateData['fitness_goal_id'] = await _lookupId(
        'fitness_goal',
        'goal_code',
        payload['fitness_goal_code'],
        'fitness_goal_id',
      );
    }

    // Populate missing NOT NULL lookups from local database if not present in payload
    final db = await dbProvider.database;
    final localRows = await db.query(
      'profiles',
      where: 'user_id = ?',
      whereArgs: [appUserId],
    );
    if (localRows.isNotEmpty) {
      final localProfile = localRows.first;
      if (!updateData.containsKey('sex_id')) {
        final sexCode = localProfile['sex_code'] as String?;
        if (sexCode != null) {
          updateData['sex_id'] =
              await _lookupId('sex', 'sex_code', sexCode, 'sex_id');
        }
      }
      if (!updateData.containsKey('activity_level_id')) {
        final activityCode = localProfile['activity_level_code'] as String?;
        if (activityCode != null) {
          updateData['activity_level_id'] = await _lookupId(
            'activity_level',
            'activity_code',
            activityCode,
            'activity_level_id',
          );
        }
      }
      if (!updateData.containsKey('fitness_goal_id')) {
        final goalCode = localProfile['fitness_goal_code'] as String?;
        if (goalCode != null) {
          updateData['fitness_goal_id'] = await _lookupId(
            'fitness_goal',
            'goal_code',
            goalCode,
            'fitness_goal_id',
          );
        }
      }
    }

    final fields = [
      'nickname',
      'age',
      'height_cm',
      'current_weight_kg',
      'target_weight_kg',
      'daily_budget_php',
      'onboarding_completed'
    ];
    for (final field in fields) {
      if (payload.containsKey(field)) {
        if (field == 'onboarding_completed') {
          updateData[field] = payload[field] == 1 || payload[field] == true;
        } else {
          updateData[field] = payload[field];
        }
      }
    }

    await supabaseClient
        .from('user_profile')
        .upsert(updateData, onConflict: 'user_id');

    if (payload.containsKey('disclaimer_accepted') &&
        (payload['disclaimer_accepted'] == 1 ||
            payload['disclaimer_accepted'] == true)) {
      final existing = await supabaseClient
          .from('medical_disclaimer_acceptance')
          .select('acceptance_id')
          .eq('user_id', appUserId)
          .limit(1);
      if (existing.isEmpty) {
        await supabaseClient.from('medical_disclaimer_acceptance').insert({
          'user_id': appUserId,
          'disclaimer_version': payload['disclaimer_version'] ?? '1.0',
        });
      }
    }

    if (payload.containsKey('allergies')) {
      final allergyText = (payload['allergies'] as String? ?? '').trim();
      const aliases = {'Dairy': 'Milk', 'Peanuts': 'Peanut'};
      final names = allergyText
          .split(',')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .map((name) => aliases[name] ?? name)
          .toList();

      if (names.isNotEmpty) {
        final rows = await supabaseClient
            .from('allergy')
            .select('allergy_id, allergy_name')
            .inFilter('allergy_name', names);
        await supabaseClient
            .from('user_allergy')
            .delete()
            .eq('user_id', appUserId);
        if (rows.isNotEmpty) {
          await supabaseClient.from('user_allergy').insert(
                rows
                    .map((row) => {
                          'user_id': appUserId,
                          'allergy_id': row['allergy_id'],
                        })
                    .toList(),
              );
        }
      } else {
        await supabaseClient
            .from('user_allergy')
            .delete()
            .eq('user_id', appUserId);
      }
    }

    if (payload.containsKey('dietary_restrictions')) {
      final restrictionText =
          (payload['dietary_restrictions'] as String? ?? '').trim();
      const labels = {
        'vegetarian': 'Vegetarian',
        'vegan': 'Vegan',
        'lactose_intolerant': 'Lactose Intolerant',
        'gluten_free': 'Gluten-Free',
        'low_carb': 'Low Carb',
        'low_sodium': 'Low Sodium',
        'diabetic': 'Diabetic-Friendly',
        'halal': 'Halal',
        'no_pork': 'No Pork',
        'no_beef': 'No Beef',
      };
      final names = restrictionText
          .split(',')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .map((name) => labels[name] ?? name)
          .toList();

      await supabaseClient
          .from('user_dietary_restriction')
          .delete()
          .eq('user_id', appUserId);
      if (names.isNotEmpty) {
        final rows = await supabaseClient
            .from('dietary_restriction')
            .select('restriction_id, restriction_name')
            .inFilter('restriction_name', names);
        if (rows.isNotEmpty) {
          await supabaseClient.from('user_dietary_restriction').insert(
                rows
                    .map((row) => {
                          'user_id': appUserId,
                          'restriction_id': row['restriction_id'],
                        })
                    .toList(),
              );
        }
      }
    }
  }

  Future<bool> _remoteVersionIsNewer(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    final localTimestamp = DateTime.tryParse(
      (payload['updated_at'] ?? item.createdAt).toString(),
    );
    if (localTimestamp == null) return false;

    const versionedEntities = <String, (String, String)>{
      'profile': ('user_profile', 'user_id'),
      'custom_food': ('food_item', 'food_id'),
      'food': ('food_item', 'food_id'),
      'meal_log': ('meal_log', 'meal_log_id'),
      'water_log': ('water_log', 'water_log_id'),
      'weight_log': ('weight_log', 'weight_log_id'),
      'meal_plan': ('meal_plan', 'meal_plan_id'),
    };
    final mapping = versionedEntities[item.entityTypeCode];
    if (mapping == null) return false;

    final entityId = item.entityTypeCode == 'profile'
        ? await _currentAppUserId()
        : item.entityId;
    final remote = await supabaseClient
        .from(mapping.$1)
        .select('updated_at')
        .eq(mapping.$2, entityId)
        .maybeSingle();
    if (remote == null) return false;

    final remoteTimestamp =
        DateTime.tryParse((remote['updated_at'] ?? '').toString());
    return remoteTimestamp != null && remoteTimestamp.isAfter(localTimestamp);
  }

  Future<void> _syncWeightLog(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    final appUserId = await _currentAppUserId();
    if (item.operationCode == 'delete') {
      await supabaseClient
          .from('weight_log')
          .delete()
          .eq('weight_log_id', item.entityId);
      return;
    }
    await supabaseClient.from('weight_log').upsert({
      'weight_log_id': item.entityId,
      'user_id': appUserId,
      'weight_kg': payload['weight_kg'],
      'logged_at': payload['logged_at'],
    });
  }

  Future<void> _syncNutritionTarget(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    final appUserId = await _currentAppUserId();
    final goalId = await _lookupId(
      'fitness_goal',
      'goal_code',
      payload['fitness_goal_code'],
      'fitness_goal_id',
    );
    if (payload['is_active'] == 1 || payload['is_active'] == true) {
      await supabaseClient
          .from('nutrition_target')
          .update({
            'is_active': false,
            'effective_to': payload['effective_from'],
          })
          .eq('user_id', appUserId)
          .eq('is_active', true)
          .neq('target_id', item.entityId);
    }
    await supabaseClient.from('nutrition_target').upsert({
      'target_id': item.entityId,
      'user_id': appUserId,
      'formula_version_id': 1,
      'fitness_goal_id': goalId,
      'source_weight_log_id': payload['source_weight_log_id'],
      'bmr': payload['bmr'],
      'tdee': payload['tdee'],
      'calorie_target': (payload['calorie_target'] as num).round(),
      'protein_target_g': payload['protein_target_g'],
      'carbs_target_g': payload['carbs_target_g'],
      'fat_target_g': payload['fat_target_g'],
      'water_target_ml': (payload['water_target_ml'] as num).round(),
      'effective_from': payload['effective_from'],
      'effective_to': payload['effective_to'],
      'is_active': payload['is_active'] == 1 || payload['is_active'] == true,
    });
  }

  Future<void> _syncDailyTargetSnapshot(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    final appUserId = await _currentAppUserId();
    await supabaseClient.from('daily_target_snapshot').upsert({
      'snapshot_id': item.entityId,
      'user_id': appUserId,
      'nutrition_target_id': payload['nutrition_target_id'],
      'target_date': payload['target_date'],
      'calorie_target_snapshot':
          (payload['calorie_target_snapshot'] as num).round(),
      'protein_target_g_snapshot': payload['protein_target_g_snapshot'],
      'carbs_target_g_snapshot': payload['carbs_target_g_snapshot'],
      'fat_target_g_snapshot': payload['fat_target_g_snapshot'],
      'water_target_ml_snapshot':
          (payload['water_target_ml_snapshot'] as num).round(),
      'daily_budget_php_snapshot': payload['daily_budget_php_snapshot'],
    }, onConflict: 'user_id,target_date');
  }

  Future<void> _syncMealLog(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    if (item.operationCode == 'delete') {
      await supabaseClient
          .from('meal_log')
          .update({'is_deleted': true}).eq('meal_log_id', item.entityId);
      return;
    }

    final db = await dbProvider.database;
    final localRows = await db.query(
      'meal_logs',
      where: 'meal_log_id = ?',
      whereArgs: [item.entityId],
      limit: 1,
    );
    final data = <String, dynamic>{
      if (localRows.isNotEmpty) ...localRows.first,
      ...payload,
    };
    final appUserId = await _currentAppUserId();
    final mealTypeId = await _lookupId(
      'meal_type',
      'meal_type_code',
      data['meal_type_code'] as String,
      'meal_type_id',
    );
    final logSourceId = await _lookupId(
      'log_source',
      'source_code',
      (data['log_source_code'] as String?) ?? 'manual',
      'log_source_id',
    );
    await supabaseClient.from('meal_log').upsert({
      'meal_log_id': item.entityId,
      'user_id': appUserId,
      'food_id': data['food_id'],
      'meal_type_id': mealTypeId,
      'log_source_id': logSourceId,
      'food_name_snapshot': data['food_name_snapshot'],
      'serving_grams_snapshot': data['serving_grams_snapshot'],
      'quantity': data['quantity'],
      'calories_snapshot': data['calories_snapshot'],
      'protein_g_snapshot': data['protein_g_snapshot'],
      'carbs_g_snapshot': data['carbs_g_snapshot'],
      'fat_g_snapshot': data['fat_g_snapshot'],
      'cost_php_snapshot': data['cost_php_snapshot'],
      'logged_at': data['logged_at'],
      'is_deleted': data['is_deleted'] == 1 || data['is_deleted'] == true,
    });
  }

  Future<void> _syncWaterLog(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    if (item.operationCode == 'delete') {
      await supabaseClient
          .from('water_log')
          .delete()
          .eq('water_log_id', item.entityId);
      return;
    }
    final appUserId = await _currentAppUserId();
    await supabaseClient.from('water_log').upsert({
      'water_log_id': item.entityId,
      'user_id': appUserId,
      'amount_ml': payload['amount_ml'],
      'logged_at': payload['logged_at'],
    });
  }

  Future<void> _syncChatSession(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    final appUserId = await _currentAppUserId();
    if (item.operationCode == 'delete') {
      await supabaseClient
          .from('chat_session')
          .delete()
          .eq('chat_session_id', item.entityId);
      return;
    }
    await supabaseClient.from('chat_session').upsert({
      'chat_session_id': item.entityId,
      'user_id': appUserId,
      'started_at': payload['started_at'],
      'ended_at': payload['ended_at'],
    });
  }

  Future<void> _syncChatMessage(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    if (item.operationCode == 'delete') {
      await supabaseClient
          .from('chat_message')
          .delete()
          .eq('chat_message_id', item.entityId);
      return;
    }
    final roleId = await _lookupId(
      'chat_role',
      'role_code',
      payload['role_code'],
      'chat_role_id',
    );
    final safetyId = await _lookupId(
      'chat_safety_status',
      'status_code',
      payload['safety_status_code'] ?? 'safe',
      'safety_status_id',
    );
    final deliveryId = await _lookupId(
      'chat_delivery_status',
      'status_code',
      payload['delivery_status_code'] ?? 'local_saved',
      'delivery_status_id',
    );
    await supabaseClient.from('chat_message').upsert({
      'chat_message_id': item.entityId,
      'chat_session_id': payload['chat_session_id'],
      'chat_role_id': roleId,
      'safety_status_id': safetyId,
      'delivery_status_id': deliveryId,
      'message_text': payload['message_text'],
      'created_at': payload['created_at'],
      'sent_at': payload['sent_at'],
    });
  }

  Future<void> _syncMealPlan(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    if (item.operationCode == 'delete') {
      await supabaseClient
          .from('meal_plan')
          .delete()
          .eq('meal_plan_id', item.entityId);
      return;
    }
    final db = await dbProvider.database;
    final localRows = await db.query(
      'meal_plans',
      where: 'meal_plan_id = ?',
      whereArgs: [item.entityId],
      limit: 1,
    );
    final data = <String, dynamic>{
      if (localRows.isNotEmpty) ...localRows.first,
      ...payload,
    };
    final appUserId = await _currentAppUserId();
    final mealTypeId = await _lookupId(
      'meal_type',
      'meal_type_code',
      data['meal_type_code'] as String,
      'meal_type_id',
    );
    final statusId = await _lookupId(
      'meal_plan_status',
      'status_code',
      data['status_code'] as String,
      'status_id',
    );
    await supabaseClient.from('meal_plan').upsert({
      'meal_plan_id': item.entityId,
      'user_id': appUserId,
      'food_id': data['food_id'],
      'meal_type_id': mealTypeId,
      'status_id': statusId,
      'converted_meal_log_id': data['converted_meal_log_id'],
      'food_name_snapshot': data['food_name_snapshot'],
      'serving_grams_snapshot': data['serving_grams_snapshot'],
      'quantity': data['quantity'],
      'calories_snapshot': data['calories_snapshot'],
      'protein_g_snapshot': data['protein_g_snapshot'],
      'carbs_g_snapshot': data['carbs_g_snapshot'],
      'fat_g_snapshot': data['fat_g_snapshot'],
      'cost_php_snapshot': data['cost_php_snapshot'],
      'planned_date': data['planned_date'],
    });
  }

  Future<void> _syncRecommendationSession(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    final appUserId = await _currentAppUserId();
    final mealTypeCode = payload['meal_type_code'] as String?;
    final goalCode = payload['fitness_goal_code'] as String?;
    final remote = <String, dynamic>{
      'session_id': item.entityId,
      'user_id': appUserId,
      'remaining_budget_php': payload['remaining_budget_php'],
      'remaining_calories': payload['remaining_calories'],
      'remaining_protein_g': payload['remaining_protein_g'],
      'remaining_carbs_g': payload['remaining_carbs_g'],
      'remaining_fat_g': payload['remaining_fat_g'],
      'minimum_price_php': payload['minimum_price_php'],
      'maximum_price_php': payload['maximum_price_php'],
      'generated_at': payload['generated_at'],
    };
    if (mealTypeCode != null && mealTypeCode.isNotEmpty) {
      remote['meal_type_id'] = await _lookupId(
        'meal_type',
        'meal_type_code',
        mealTypeCode,
        'meal_type_id',
      );
    }
    if (goalCode != null && goalCode.isNotEmpty) {
      remote['fitness_goal_id'] = await _lookupId(
        'fitness_goal',
        'goal_code',
        goalCode,
        'fitness_goal_id',
      );
    }
    await supabaseClient.from('recommendation_session').upsert(remote);
  }

  Future<void> _syncRecommendationItem(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    await supabaseClient.from('recommendation_item').upsert({
      'recommendation_item_id': item.entityId,
      'session_id': payload['session_id'],
      'food_id': payload['food_id'],
      'linked_meal_log_id': payload['linked_meal_log_id'],
      'linked_meal_plan_id': payload['linked_meal_plan_id'],
      'rank_number': payload['rank_number'],
      'final_score': payload['final_score'],
      'affordability_score': payload['affordability_score'],
      'protein_fit_score': payload['protein_fit_score'],
      'calorie_fit_score': payload['calorie_fit_score'],
      'macro_balance_score': payload['macro_balance_score'],
      'goal_match_score': payload['goal_match_score'],
      'meal_type_score': payload['meal_type_score'],
      'over_budget_penalty': payload['over_budget_penalty'],
      'reason_text': payload['reason_text'],
      'was_accepted':
          payload['was_accepted'] == true || payload['was_accepted'] == 1,
      'accepted_at': payload['accepted_at'],
    });
  }

  Future<void> _syncCustomFood(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    if (item.operationCode == 'delete') {
      await supabaseClient
          .from('food_item')
          .delete()
          .eq('food_id', item.entityId);
      return;
    }

    final isOfficial =
        payload['is_official'] == true || payload['is_official'] == 1;
    if (isOfficial) {
      await supabaseClient.rpc('admin_upsert_food', params: {
        'p_food_id': item.entityId,
        'p_category_name': payload['category_name'],
        'p_subcategory': payload['subcategory'],
        'p_description': payload['description'],
        'p_food_name': payload['food_name'],
        'p_normalized_name': payload['normalized_name'],
        'p_is_local_food':
            payload['is_local_food'] == true || payload['is_local_food'] == 1,
        'p_is_official': true,
        'p_is_active':
            payload['is_active'] == true || payload['is_active'] == 1,
        'p_serving_id': payload['serving_id'] ?? item.entityId,
        'p_serving_label': payload['serving_label'],
        'p_serving_grams': payload['serving_grams'],
        'p_calories': payload['calories'],
        'p_protein_g': payload['protein_g'],
        'p_carbs_g': payload['carbs_g'],
        'p_fat_g': payload['fat_g'],
        'p_price_php': payload['estimated_price_php'],
      });
      return;
    }

    final appUserId = await _currentAppUserId();
    final categoryId = await _lookupId(
      'food_category',
      'category_name',
      payload['category_name'],
      'category_id',
    );
    await supabaseClient.from('food_item').upsert({
      'food_id': item.entityId,
      'category_id': categoryId,
      'subcategory': payload['subcategory'],
      'description': payload['description'],
      'owner_user_id': appUserId,
      'food_name': payload['food_name'],
      'normalized_name': payload['normalized_name'],
      'is_local_food':
          payload['is_local_food'] == true || payload['is_local_food'] == 1,
      'is_official': false,
      'is_active': payload['is_active'] == true || payload['is_active'] == 1,
    });
    // Also insert serving and nutrition if present
    if (payload['serving_label'] != null) {
      final sourceName = payload['source_name'] as String? ??
          ((payload['is_official'] == true || payload['is_official'] == 1)
              ? 'FNRI_DOST'
              : 'Estimated_Common');
      final sourceId = await _lookupId(
        'data_source',
        'source_name',
        sourceName,
        'source_id',
      );
      final servingId = payload['serving_id'] ?? item.entityId;
      await supabaseClient.from('food_serving').upsert({
        'serving_id': servingId,
        'food_id': item.entityId,
        'serving_label': payload['serving_label'],
        'serving_grams': payload['serving_grams'],
        'is_default': true,
        'is_active': true,
      });
      if (payload['calories'] != null) {
        await supabaseClient.from('food_nutrition_profile').upsert({
          'nutrition_profile_id': item.entityId,
          'food_id': item.entityId,
          'serving_id': servingId,
          'source_id': sourceId,
          'calories': payload['calories'],
          'protein_g': payload['protein_g'],
          'carbs_g': payload['carbs_g'],
          'fat_g': payload['fat_g'],
          'is_active': true,
        });
      }
      if (payload['estimated_price_php'] != null) {
        await supabaseClient.from('food_price').upsert({
          'price_id': item.entityId,
          'food_id': item.entityId,
          'serving_id': servingId,
          'source_id': sourceId,
          'estimated_price_php': payload['estimated_price_php'],
          'is_active': true,
        });
      }
    }
    await supabaseClient.from('food_change_log').insert({
      'food_id': item.entityId,
      'changed_by_user_id': appUserId,
      'change_type': item.operationCode,
      'changed_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _syncAiScanFeedback(
    SyncQueueEntry item,
    Map<String, dynamic> payload,
  ) async {
    if (item.operationCode == 'delete') {
      await supabaseClient
          .from('ai_scan_feedback')
          .delete()
          .eq('feedback_id', item.entityId);
      return;
    }
    final appUserId = await _currentAppUserId();
    await supabaseClient.from('ai_scan_feedback').upsert({
      'feedback_id': item.entityId,
      'user_id': appUserId,
      'client_scan_id': payload['client_scan_id'],
      'selected_food_id': payload['selected_food_id'],
      'was_helpful': payload['was_helpful'],
      'feedback_text': payload['feedback_text'],
      'created_at':
          payload['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _executeCreate(
      String table, Map<String, dynamic> payload) async {
    final filtered = Map<String, dynamic>.from(payload)
      ..remove('sync_status')
      ..remove('local_created_at');
    final now = DateTime.now().toUtc().toIso8601String();
    filtered['created_at'] ??= now;
    filtered['updated_at'] ??= now;

    final response = await supabaseClient.from(table).insert(filtered).select();
    if (response.isEmpty) {
      throw Exception('Create returned empty response');
    }
  }

  Future<void> _executeUpdate(
    String table,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    final filtered = Map<String, dynamic>.from(payload)
      ..remove('sync_status')
      ..remove('local_created_at')
      ..remove('created_at');
    filtered['updated_at'] = DateTime.now().toUtc().toIso8601String();

    final pkColumn = _entityTypeToPkColumn(_tableToEntityType(table));

    final existing = await supabaseClient
        .from(table)
        .select()
        .eq(pkColumn, entityId)
        .maybeSingle();

    if (existing == null) {
      filtered[pkColumn] = entityId;
      filtered['created_at'] ??= DateTime.now().toUtc().toIso8601String();
      final response =
          await supabaseClient.from(table).insert(filtered).select();
      if (response.isEmpty) {
        throw Exception('Upsert returned empty response');
      }
      return;
    }

    final response = await supabaseClient
        .from(table)
        .update(filtered)
        .eq(pkColumn, entityId)
        .select();
    if (response.isEmpty) {
      throw Exception('Update returned empty response');
    }
  }

  Future<void> _executeDelete(
    String table,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    final pkColumn = _entityTypeToPkColumn(_tableToEntityType(table));

    if (payload['is_deleted'] == true) {
      await supabaseClient.from(table).update({
        'is_deleted': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq(pkColumn, entityId);
    } else {
      await supabaseClient.from(table).delete().eq(pkColumn, entityId);
    }
  }

  Future<int> retryFailed() async {
    final failed = await _repo.readFailed();
    for (final item in failed) {
      await _repo.updateSyncStatus(item.syncQueueId, 'pending',
          serverSyncedAt: null);
    }
    return failed.length;
  }

  String _entityTypeToTable(String entityTypeCode) {
    switch (entityTypeCode) {
      case 'profile':
        return 'user_profile';
      case 'nutrition_target':
        return 'nutrition_target';
      case 'daily_target_snapshot':
        return 'daily_target_snapshot';
      case 'custom_food':
      case 'food':
        return 'food_item';
      case 'meal_log':
        return 'meal_log';
      case 'water_log':
        return 'water_log';
      case 'weight_log':
        return 'weight_log';
      case 'meal_plan':
        return 'meal_plan';
      case 'recommendation_session':
        return 'recommendation_session';
      case 'recommendation_item':
        return 'recommendation_item';
      case 'ai_scan':
        return 'ai_scan';
      case 'ai_scan_prediction':
        return 'ai_scan_prediction';
      case 'ai_scan_feedback':
        return 'ai_scan_feedback';
      case 'chat_session':
        return 'chat_session';
      case 'chat_message':
        return 'chat_message';
      default:
        throw Exception('Unknown entity type code: $entityTypeCode');
    }
  }

  String _entityTypeToLocalTable(String entityTypeCode) {
    switch (entityTypeCode) {
      case 'profile':
        return 'profiles';
      case 'nutrition_target':
        return 'nutrition_targets';
      case 'daily_target_snapshot':
        return 'daily_target_snapshots';
      case 'custom_food':
      case 'food':
        return 'foods';
      case 'meal_log':
        return 'meal_logs';
      case 'water_log':
        return 'water_logs';
      case 'weight_log':
        return 'weight_logs';
      case 'meal_plan':
        return 'meal_plans';
      case 'recommendation_session':
        return 'recommendation_sessions';
      case 'recommendation_item':
        return 'recommendation_items';
      case 'ai_scan':
        return 'ai_scans';
      case 'ai_scan_prediction':
        return 'ai_scan_predictions';
      case 'ai_scan_feedback':
        return 'ai_scan_feedback';
      case 'chat_session':
        return 'chat_sessions';
      case 'chat_message':
        return 'chat_messages';
      default:
        throw Exception('Unknown local entity type code: $entityTypeCode');
    }
  }

  String _tableToEntityType(String tableName) {
    switch (tableName) {
      case 'profiles':
      case 'user_profile':
        return 'profile';
      case 'nutrition_targets':
      case 'nutrition_target':
        return 'nutrition_target';
      case 'daily_target_snapshots':
      case 'daily_target_snapshot':
        return 'daily_target_snapshot';
      case 'foods':
      case 'food_item':
        return 'custom_food';
      case 'meal_logs':
      case 'meal_log':
        return 'meal_log';
      case 'water_logs':
      case 'water_log':
        return 'water_log';
      case 'weight_logs':
      case 'weight_log':
        return 'weight_log';
      case 'meal_plans':
      case 'meal_plan':
        return 'meal_plan';
      case 'recommendation_sessions':
      case 'recommendation_session':
        return 'recommendation_session';
      case 'recommendation_items':
      case 'recommendation_item':
        return 'recommendation_item';
      case 'ai_scans':
      case 'ai_scan':
        return 'ai_scan';
      case 'ai_scan_predictions':
      case 'ai_scan_prediction':
        return 'ai_scan_prediction';
      case 'ai_scan_feedback':
        return 'ai_scan_feedback';
      case 'chat_sessions':
      case 'chat_session':
        return 'chat_session';
      case 'chat_messages':
      case 'chat_message':
        return 'chat_message';
      default:
        throw Exception('Unknown table name: $tableName');
    }
  }

  String _entityTypeToPkColumn(String entityTypeCode) {
    switch (entityTypeCode) {
      case 'profile':
        return 'user_id';
      case 'nutrition_target':
        return 'target_id';
      case 'daily_target_snapshot':
        return 'snapshot_id';
      case 'custom_food':
        return 'food_id';
      case 'meal_log':
        return 'meal_log_id';
      case 'water_log':
        return 'water_log_id';
      case 'weight_log':
        return 'weight_log_id';
      case 'meal_plan':
        return 'meal_plan_id';
      case 'recommendation_session':
        return 'session_id';
      case 'recommendation_item':
        return 'recommendation_item_id';
      case 'ai_scan':
        return 'scan_id';
      case 'ai_scan_prediction':
        return 'prediction_id';
      case 'ai_scan_feedback':
        return 'feedback_id';
      case 'chat_session':
        return 'chat_session_id';
      case 'chat_message':
        return 'chat_message_id';
      default:
        throw Exception('Unknown entity type code: $entityTypeCode');
    }
  }
}
