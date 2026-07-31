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
      .select('role_id')
      .eq('auth_user_id', session.user.id)
      .maybeSingle();
  return row?['role_id'] == 2;
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

const int _foodPageSize = 50;

final allOfficialFoodsProvider =
    FutureProvider.family<List<Food>, int>((ref, page) async {
  final db = await DatabaseProvider().database;
  final results = await db.query(
    'foods',
    where: 'is_official = 1 AND is_deleted = 0',
    orderBy: 'food_name ASC',
    limit: _foodPageSize,
    offset: page * _foodPageSize,
  );
  return results.map((m) => Food.fromMap(m)).toList();
});
