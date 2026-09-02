import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';

final isAdminProvider = FutureProvider<bool>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return false;
  final row = await ref
      .read(supabaseClientProvider)
      .from('app_user')
      .select('role(role_code)')
      .eq('auth_user_id', session.user.id)
      .maybeSingle();
  return (row?['role'] as Map?)?['role_code'] == 'admin';
});

class DashboardKpis {
  final int totalUsers;
  final int activeUsers;
  final int totalMealLogs;
  final int totalAiScans;
  final int reportCount;
  final int pendingPostReports;

  const DashboardKpis({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalMealLogs,
    required this.totalAiScans,
    required this.reportCount,
    required this.pendingPostReports,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    return DashboardKpis(
      totalUsers: (json['total_users'] as num).toInt(),
      activeUsers: (json['active_users'] as num).toInt(),
      totalMealLogs: (json['total_meal_logs'] as num).toInt(),
      totalAiScans: (json['total_ai_scans'] as num).toInt(),
      reportCount: (json['report_count'] as num).toInt(),
      pendingPostReports: (json['pending_post_reports'] as num).toInt(),
    );
  }
}

final dashboardKpisProvider = FutureProvider<DashboardKpis>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final result = await supabase.rpc('admin_dashboard_kpis');
  return DashboardKpis.fromJson(result as Map<String, dynamic>);
});

class AdminBlockedWord {
  final int id;
  final String word;
  final bool isActive;

  const AdminBlockedWord({
    required this.id,
    required this.word,
    required this.isActive,
  });
}

final adminBlockedWordsProvider =
    FutureProvider<List<AdminBlockedWord>>((ref) async {
  final rows = await ref
      .read(supabaseClientProvider)
      .from('community_blocked_word')
      .select('blocked_word_id, blocked_word, is_active')
      .order('blocked_word');
  return rows
      .map(
        (row) => AdminBlockedWord(
          id: (row['blocked_word_id'] as num).toInt(),
          word: row['blocked_word'] as String,
          isActive: row['is_active'] == true,
        ),
      )
      .toList();
});

class AdminRoleOption {
  final int id;
  final String code;
  final String name;

  const AdminRoleOption({
    required this.id,
    required this.code,
    required this.name,
  });
}

final adminRolesProvider = FutureProvider<List<AdminRoleOption>>((ref) async {
  final rows = await ref
      .read(supabaseClientProvider)
      .from('role')
      .select('role_id, role_code, role_name')
      .order('role_id');

  return rows
      .map(
        (row) => AdminRoleOption(
          id: (row['role_id'] as num).toInt(),
          code: row['role_code'] as String,
          name: row['role_name'] as String,
        ),
      )
      .toList();
});

class AdminAccountStatusOption {
  final int id;
  final String code;
  final String name;

  const AdminAccountStatusOption({
    required this.id,
    required this.code,
    required this.name,
  });
}

final adminAccountStatusesProvider =
    FutureProvider<List<AdminAccountStatusOption>>((ref) async {
  final rows = await ref
      .read(supabaseClientProvider)
      .from('account_status')
      .select('account_status_id, status_code, status_name')
      .order('account_status_id');

  return rows
      .map(
        (row) => AdminAccountStatusOption(
          id: (row['account_status_id'] as num).toInt(),
          code: row['status_code'] as String,
          name: row['status_name'] as String,
        ),
      )
      .toList();
});

class AdminUserEntry {
  final String userId;
  final String authUserId;
  final String? email;
  final int roleId;
  final String roleName;
  final int statusId;
  final String statusCode;
  final String statusName;
  final String? nickname;
  final DateTime createdAt;

  const AdminUserEntry({
    required this.userId,
    required this.authUserId,
    required this.email,
    required this.roleId,
    required this.roleName,
    required this.statusId,
    required this.statusCode,
    required this.statusName,
    required this.nickname,
    required this.createdAt,
  });
}

final adminUsersProvider = FutureProvider<List<AdminUserEntry>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final roles = await ref.watch(adminRolesProvider.future);
  final statuses = await ref.watch(adminAccountStatusesProvider.future);

  try {
    final result = await supabase.rpc('admin_list_users');
    final rows = (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    return rows
        .map(
          (row) => AdminUserEntry(
            userId: row['user_id'] as String,
            authUserId: row['auth_user_id'] as String,
            email: row['email'] as String?,
            roleId: (row['role_id'] as num).toInt(),
            roleName: row['role_name'] as String? ?? 'Unknown role',
            statusId: (row['account_status_id'] as num).toInt(),
            statusCode: row['status_code'] as String? ?? 'unknown',
            statusName: row['status_name'] as String? ?? 'Unknown status',
            nickname: row['nickname'] as String?,
            createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .toList();
  } catch (_) {
    // Keep the console usable while an older hosted project is being
    // migrated. The fallback cannot read auth.users, so email is unavailable.
  }

  final userRows = await supabase
      .from('app_user')
      .select('user_id, auth_user_id, role_id, account_status_id, created_at');

  final roleById = <int, AdminRoleOption>{
    for (final role in roles) role.id: role,
  };
  final statusById = <int, AdminAccountStatusOption>{
    for (final status in statuses) status.id: status,
  };
  final userIds = userRows.map((row) => row['user_id'] as String).toList();
  final profileRows = userIds.isEmpty
      ? const <dynamic>[]
      : await supabase
          .from('user_profile')
          .select('user_id, nickname')
          .inFilter('user_id', userIds);
  final nicknameByUserId = <String, String>{
    for (final row in profileRows)
      row['user_id'] as String: row['nickname'] as String,
  };

  DateTime parseDate(Object? value) {
    return DateTime.tryParse(value as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  return userRows.map((row) {
    final roleId = (row['role_id'] as num).toInt();
    final statusId = (row['account_status_id'] as num).toInt();
    final role = roleById[roleId];
    final status = statusById[statusId];
    return AdminUserEntry(
      userId: row['user_id'] as String,
      authUserId: row['auth_user_id'] as String,
      email: null,
      roleId: roleId,
      roleName: role?.name ?? 'Unknown role',
      statusId: statusId,
      statusCode: status?.code ?? 'unknown',
      statusName: status?.name ?? 'Unknown status',
      nickname: nicknameByUserId[row['user_id'] as String],
      createdAt: parseDate(row['created_at']),
    );
  }).toList();
});

class AdminAuditEntry {
  final String id;
  final String auditType;
  final String action;
  final String actorId;
  final String? targetId;
  final String? reportId;
  final String? postId;
  final String? details;
  final DateTime createdAt;

  const AdminAuditEntry({
    required this.id,
    required this.auditType,
    required this.action,
    required this.actorId,
    this.targetId,
    this.reportId,
    this.postId,
    this.details,
    required this.createdAt,
  });
}

final adminAuditLogProvider =
    FutureProvider<List<AdminAuditEntry>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final statuses = await ref.watch(adminAccountStatusesProvider.future);
  final moderationRows = await supabase
      .from('moderation_audit_log')
      .select(
          'log_id, admin_user_id, action_code, report_id, post_id, details, created_at')
      .order('created_at', ascending: false)
      .limit(100);
  final roleRows = await supabase
      .from('admin_role_audit')
      .select(
          'audit_id, changed_by, target_user, old_role_id, new_role_id, changed_at')
      .order('changed_at', ascending: false)
      .limit(100);
  List<dynamic> accountStatusRows = const [];
  try {
    accountStatusRows = await supabase
        .from('admin_account_status_audit')
        .select(
            'audit_id, changed_by, target_user, old_status_id, new_status_id, changed_at')
        .order('changed_at', ascending: false)
        .limit(100);
  } catch (_) {
    // Older hosted projects may not have the account-status audit migration
    // yet. Keep the rest of the audit timeline available until it is applied.
  }

  final statusNames = <int, String>{
    for (final status in statuses) status.id: status.name,
  };

  DateTime parseDate(Object? value) {
    return DateTime.tryParse(value as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  final entries = <AdminAuditEntry>[
    ...moderationRows.map(
      (row) => AdminAuditEntry(
        id: row['log_id'] as String,
        auditType: 'Moderation',
        action: row['action_code'] as String? ?? 'unknown',
        actorId: row['admin_user_id'] as String,
        reportId: row['report_id'] as String?,
        postId: row['post_id'] as String?,
        details: row['details'] as String?,
        createdAt: parseDate(row['created_at']),
      ),
    ),
    ...roleRows.map(
      (row) => AdminAuditEntry(
        id: row['audit_id'] as String,
        auditType: 'Role Change',
        action: 'role_changed',
        actorId: row['changed_by'] as String,
        targetId: row['target_user'] as String?,
        details:
            'Role ${row['old_role_id'] ?? 'unknown'} -> ${row['new_role_id']}',
        createdAt: parseDate(row['changed_at']),
      ),
    ),
    ...accountStatusRows.map(
      (row) => AdminAuditEntry(
        id: row['audit_id'] as String,
        auditType: 'Account Status',
        action: 'account_status_changed',
        actorId: row['changed_by'] as String,
        targetId: row['target_user'] as String?,
        details:
            'Status ${statusNames[(row['old_status_id'] as num?)?.toInt()] ?? 'unknown'}'
            ' -> ${statusNames[(row['new_status_id'] as num?)?.toInt()] ?? 'unknown'}',
        createdAt: parseDate(row['changed_at']),
      ),
    ),
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return entries;
});

const int adminFoodPageSize = 50;

final allOfficialFoodsProvider =
    FutureProvider.family<List<Food>, int>((ref, page) async {
  final db = await DatabaseProvider().database;
  final results = await db.query(
    'foods',
    where: 'is_official = 1 AND is_deleted = 0',
    orderBy: 'food_name ASC',
    limit: adminFoodPageSize,
    offset: page * adminFoodPageSize,
  );
  return results.map((m) => Food.fromMap(m)).toList();
});

/// Returns the first [pages] pages as one list so the admin screen can append
/// results without dropping records that were already visible.
final pagedOfficialFoodsProvider =
    FutureProvider.family<List<Food>, int>((ref, pages) async {
  final db = await DatabaseProvider().database;
  final results = await db.query(
    'foods',
    where: 'is_official = 1 AND is_deleted = 0',
    orderBy: 'food_name ASC',
    limit: adminFoodPageSize * pages,
  );
  return results.map((m) => Food.fromMap(m)).toList();
});

/// Admin catalog data comes from Supabase directly. The consumer app keeps a
/// SQLite cache for offline use, but the admin console must also work in the
/// web build where sqflite has no default database factory.
final pagedAdminFoodsProvider =
    FutureProvider.family<List<Food>, int>((ref, pages) async {
  final supabase = ref.read(supabaseClientProvider);
  const baseSelection =
      'food_id, owner_user_id, food_name, normalized_name, is_local_food, '
      'is_official, is_active, created_at, updated_at, '
      'food_category(category_name), '
      'food_serving(serving_id, serving_label, serving_grams, is_default, is_active), '
      'food_nutrition_profile(serving_id, calories, protein_g, carbs_g, fat_g, is_active, effective_from), '
      'food_price(serving_id, estimated_price_php, is_active, effective_from)';
  List<dynamic> rows;
  try {
    rows = await supabase
        .from('food_item')
        .select('$baseSelection, food_meal_type(meal_type(meal_type_code))')
        .eq('is_official', true)
        .order('food_name')
        .range(0, (pages * adminFoodPageSize) - 1);
  } catch (_) {
    rows = await supabase
        .from('food_item')
        .select(baseSelection)
        .eq('is_official', true)
        .order('food_name')
        .range(0, (pages * adminFoodPageSize) - 1);
  }

  return rows
      .map((row) => Food.fromMap(
            _adminFoodRowToLocalMap(Map<String, dynamic>.from(row as Map)),
          ))
      .toList();
});

Map<String, dynamic> _adminFoodRowToLocalMap(Map<String, dynamic> row) {
  Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  List<Map<String, dynamic>> asMaps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  final category = asMap(row['food_category']);
  final servings = asMaps(row['food_serving']);
  final serving = servings.firstWhere(
    (item) => item['is_default'] == true && item['is_active'] == true,
    orElse: () => servings.isNotEmpty ? servings.first : const {},
  );
  final servingId = serving['serving_id'] as String?;
  final nutrition = asMaps(row['food_nutrition_profile'])
      .where((item) =>
          item['is_active'] == true && item['serving_id'] == servingId)
      .toList();
  final price = asMaps(row['food_price'])
      .where((item) =>
          item['is_active'] == true && item['serving_id'] == servingId)
      .toList();
  final nutritionRow =
      nutrition.isEmpty ? const <String, dynamic>{} : nutrition.first;
  final priceRow = price.isEmpty ? const <String, dynamic>{} : price.first;
  final mealTypeCodes = asMaps(row['food_meal_type'])
      .map((item) => asMap(item['meal_type'])?['meal_type_code'])
      .whereType<String>()
      .toList();
  final now = DateTime.now().toUtc().toIso8601String();

  return {
    'food_id': row['food_id'],
    'category_name': category?['category_name'] ?? 'Uncategorized',
    'subcategory': null,
    'description': null,
    'owner_user_id': row['owner_user_id'],
    'food_name': row['food_name'],
    'normalized_name': row['normalized_name'],
    'is_local_food': row['is_local_food'] == true ? 1 : 0,
    'is_official': row['is_official'] == true ? 1 : 0,
    'is_active': row['is_active'] == true ? 1 : 0,
    'serving_id': servingId,
    'serving_label': serving['serving_label'],
    'serving_grams': serving['serving_grams'] ?? 0,
    'calories': nutritionRow['calories'] ?? 0,
    'protein_g': nutritionRow['protein_g'] ?? 0,
    'carbs_g': nutritionRow['carbs_g'] ?? 0,
    'fat_g': nutritionRow['fat_g'] ?? 0,
    'estimated_price_php': priceRow['estimated_price_php'] ?? 0,
    'meal_type_codes': mealTypeCodes.join(','),
    'is_deleted': 0,
    'sync_status': 'synced',
    'created_at': row['created_at']?.toString() ?? now,
    'updated_at': row['updated_at']?.toString() ?? now,
  };
}
