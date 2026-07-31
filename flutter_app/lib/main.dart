import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/app.dart';
import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/core/sync/background_sync_worker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.validateRuntimeConfiguration();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  // Initialize WorkManager for Doze-safe background sync.
  await BackgroundSyncScheduler.initialize();
  await BackgroundSyncScheduler.schedulePeriodicSync();

  runApp(const ProviderScope(child: JcgFitnessApp()));
}
