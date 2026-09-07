import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/app.dart';
import 'package:jcg_fitness/app/bootstrap.dart';
import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/core/sync/background_sync_worker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.validateRuntimeConfiguration();

  runApp(
    ProviderScope(
      child: AppBootstrap(
        initialize:
            AppConfig.isLocalTestMode ? () async {} : _initializeHostedServices,
        child: const JcgFitnessApp(),
      ),
    ),
  );
}

Future<void> _initializeHostedServices() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  ).timeout(const Duration(seconds: 20));

  // Background sync is useful after launch but must not hold the first frame.
  unawaited(_initializeBackgroundSync());
}

Future<void> _initializeBackgroundSync() async {
  try {
    await BackgroundSyncScheduler.initialize();
    await BackgroundSyncScheduler.schedulePeriodicSync();
  } catch (_) {
    // Sync can be retried from the app after the hosted session is ready.
  }
}
