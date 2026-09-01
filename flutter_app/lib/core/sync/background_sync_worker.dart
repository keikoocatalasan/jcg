import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/sync/sync_queue_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String backgroundSyncTaskName = 'jcg-fitness-background-sync';

/// Top-level callback required by the workmanager package.
/// Must be a static or top-level function.
@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Ensure Supabase is initialized if the app was killed.
      const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
      const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
      if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
        try {
          await Supabase.initialize(
            url: supabaseUrl,
            publishableKey: supabaseAnonKey,
          );
        } catch (_) {
          // Already initialized or unavailable; continue best-effort.
        }
      }

      final client = Supabase.instance.client;
      final service = SyncQueueService(
        DatabaseProvider(),
        client,
      );
      final result = await service.processSyncQueue();
      log(
        'Background sync finished: '
        '${result.synced} synced, ${result.failed} failed, '
        '${result.skipped} skipped',
        name: 'BackgroundSync',
      );
      return Future.value(result.errors.isEmpty && result.failed == 0);
    } catch (e, st) {
      log('Background sync error: $e',
          name: 'BackgroundSync', error: e, stackTrace: st);
      return Future.value(false);
    }
  });
}

class BackgroundSyncScheduler {
  static bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  static Future<void> initialize() async {
    if (!_isSupportedPlatform) return;
    await Workmanager().initialize(backgroundSyncCallbackDispatcher);
  }

  static Future<void> schedulePeriodicSync() async {
    if (!_isSupportedPlatform) return;
    await Workmanager().registerPeriodicTask(
      backgroundSyncTaskName,
      backgroundSyncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancel() async {
    if (!_isSupportedPlatform) return;
    await Workmanager().cancelByUniqueName(backgroundSyncTaskName);
  }
}
