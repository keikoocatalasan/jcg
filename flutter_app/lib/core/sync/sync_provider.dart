import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:jcg_fitness/features/admin/admin_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/hydration/hydration_provider.dart';
import 'package:jcg_fitness/features/meal_logging/meal_log_provider.dart';
import 'package:jcg_fitness/features/meal_logging/recent_logs_provider.dart';
import 'package:jcg_fitness/features/meal_planner/meal_planner_provider.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';
import 'package:jcg_fitness/features/weight_tracking/weight_provider.dart';
import 'sync_queue_service.dart';

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  final db = ref.read(databaseProvider);
  final supabase = ref.read(supabaseClientProvider);
  return SyncQueueService(db, supabase);
});

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final notifier = SyncNotifier(ref);
  ref.listen<bool>(isOnlineProvider, (previous, isOnline) {
    if (isOnline && previous != true) notifier.startSync();
  }, fireImmediately: true);
  return notifier;
});

class SyncState {
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final int pendingCount;
  final SyncResult? lastResult;

  const SyncState({
    this.isSyncing = false,
    this.lastSyncAt,
    this.pendingCount = 0,
    this.lastResult,
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncAt,
    int? pendingCount,
    SyncResult? lastResult,
    bool clearSyncing = false,
  }) {
    return SyncState(
      isSyncing: clearSyncing ? false : (isSyncing ?? this.isSyncing),
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      pendingCount: pendingCount ?? this.pendingCount,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  Timer? _debounceTimer;

  SyncNotifier(this._ref) : super(const SyncState()) {
    Future.microtask(refreshPendingCount);
  }

  Future<void> startSync() async {
    if (state.isSyncing) return;

    state = state.copyWith(isSyncing: true);

    try {
      final service = _ref.read(syncQueueServiceProvider);
      final result = await service.processSyncQueue();

      final pending = await _getPendingCount();

      state = state.copyWith(
        isSyncing: false,
        lastSyncAt: result.errors.isEmpty ? DateTime.now() : null,
        pendingCount: pending,
        lastResult: result,
        clearSyncing: true,
      );
      if (result.synced > 0) _refreshDataProviders();
    } catch (e) {
      final pending = await _getPendingCount();
      state = state.copyWith(
        isSyncing: false,
        pendingCount: pending,
        lastResult: SyncResult(
          total: 0,
          errors: [e.toString()],
        ),
        clearSyncing: true,
      );
    }
  }

  void _refreshDataProviders() {
    _ref.invalidate(dashboardDataProvider);
    _ref.invalidate(recentLogsProvider);
    _ref.invalidate(todayMealLogsProvider);
    _ref.invalidate(mealLogsForDateProvider);
    _ref.invalidate(todayWaterProvider);
    _ref.invalidate(todayWaterLogsProvider);
    _ref.invalidate(latestWeightProvider);
    _ref.invalidate(weightHistoryProvider);
    _ref.invalidate(weeklyPlansProvider);
    _ref.invalidate(plansForDateProvider);
    _ref.invalidate(allOfficialFoodsProvider);
  }

  Future<void> refreshPendingCount() async {
    final pending = await _getPendingCount();
    if (mounted) state = state.copyWith(pendingCount: pending);
  }

  Future<int> retryFailed() async {
    final service = _ref.read(syncQueueServiceProvider);
    final count = await service.retryFailed();
    if (count > 0) {
      startSync();
    }
    return count;
  }

  Future<int> _getPendingCount() async {
    try {
      final db = _ref.read(databaseProvider);
      final database = await db.database;
      final results = await database.query(
        'sync_queue',
        where: 'sync_status IN (?, ?)',
        whereArgs: ['pending', 'failed'],
      );
      return results.length;
    } catch (_) {
      return 0;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
