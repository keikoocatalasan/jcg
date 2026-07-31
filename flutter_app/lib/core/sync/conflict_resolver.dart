import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConflictResolver {
  static const _pkColumnMap = {
    'user_profile': 'user_id',
    'nutrition_target': 'target_id',
    'daily_target_snapshot': 'snapshot_id',
    'food_item': 'food_id',
    'meal_log': 'meal_log_id',
    'water_log': 'water_log_id',
    'weight_log': 'weight_log_id',
    'meal_plan': 'meal_plan_id',
    'recommendation_session': 'session_id',
    'recommendation_item': 'recommendation_item_id',
    'ai_scan': 'scan_id',
    'ai_scan_prediction': 'prediction_id',
    'ai_scan_feedback': 'feedback_id',
    'chat_session': 'chat_session_id',
    'chat_message': 'chat_message_id',
  };

  static const _remoteTableMap = {
    'profiles': 'user_profile',
    'nutrition_targets': 'nutrition_target',
    'daily_target_snapshots': 'daily_target_snapshot',
    'foods': 'food_item',
    'meal_logs': 'meal_log',
    'water_logs': 'water_log',
    'weight_logs': 'weight_log',
    'meal_plans': 'meal_plan',
    'recommendation_sessions': 'recommendation_session',
    'recommendation_items': 'recommendation_item',
    'ai_scans': 'ai_scan',
    'ai_scan_predictions': 'ai_scan_prediction',
    'chat_sessions': 'chat_session',
    'chat_messages': 'chat_message',
  };

  static String _remoteTable(String tableName) =>
      _remoteTableMap[tableName] ?? tableName;

  /// For profile updates: merge by changed_fields_json.
  /// Only fields listed in `changedFields` override the remote record.
  static Future<Map<String, dynamic>> resolveProfileConflict({
    required SupabaseClient supabase,
    required String userId,
    required Map<String, dynamic> localPayload,
    String? changedFieldsJson,
  }) async {
    final appUser = await supabase
        .from('app_user')
        .select('user_id')
        .eq('auth_user_id', userId)
        .maybeSingle();
    if (appUser == null) return localPayload;

    final remote = await supabase
        .from('user_profile')
        .select()
        .eq('user_id', appUser['user_id'])
        .maybeSingle();

    if (remote == null) {
      return localPayload;
    }

    final changedFields = changedFieldsJson != null
        ? (jsonDecode(changedFieldsJson) as List<dynamic>)
            .map((e) => e as String)
            .toSet()
        : <String>{};

    if (changedFields.isEmpty) {
      return localPayload;
    }

    final merged = Map<String, dynamic>.from(remote);
    for (final field in changedFields) {
      if (localPayload.containsKey(field)) {
        merged[field] = localPayload[field];
      }
    }
    merged['updated_at'] = DateTime.now().toUtc().toIso8601String();

    return merged;
  }

  /// For same-UUID records (weight_logs, water_logs, meal_logs, etc.):
  /// Check if remote already has a record with the same ID.
  /// If it does, prevent duplicate by treating as update instead of create.
  static Future<bool> isDuplicateOnServer({
    required SupabaseClient supabase,
    required String tableName,
    required String entityId,
  }) async {
    final remoteTable = _remoteTable(tableName);
    final pkColumn = _pkColumnMap[remoteTable] ?? '${remoteTable}_id';

    final existing = await supabase
        .from(remoteTable)
        .select(pkColumn)
        .eq(pkColumn, entityId)
        .maybeSingle();

    return existing != null;
  }

  /// For delete tombstones on water_log/weight_log:
  /// Only send delete if the remote record still exists.
  /// For weight_log, also cancel if a later weight was used to recalculate targets.
  static Future<bool> shouldSendDelete({
    required SupabaseClient supabase,
    required String tableName,
    required String entityId,
    String? userId,
  }) async {
    final remoteTable = _remoteTable(tableName);
    final pkColumn = _pkColumnMap[remoteTable] ?? '${remoteTable}_id';

    final existing = await supabase
        .from(remoteTable)
        .select(pkColumn)
        .eq(pkColumn, entityId)
        .maybeSingle();

    if (existing == null) return false;

    if (remoteTable == 'weight_log' && userId != null) {
      final latestTarget = await supabase
          .from('nutrition_target')
          .select('source_weight_log_id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (latestTarget != null &&
          latestTarget['source_weight_log_id'] == entityId) {
        return false;
      }
    }

    return true;
  }
}
