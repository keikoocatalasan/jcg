import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/router.dart';
import 'package:jcg_fitness/app/theme.dart';

class JcgFitnessApp extends ConsumerWidget {
  const JcgFitnessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          MediaQuery.textScalerOf(context).scale(1).clamp(0.8, 1.3),
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.bgPrimary,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: MaterialApp.router(
          title: 'JCG Fitness',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          showPerformanceOverlay:
              const bool.fromEnvironment('SHOW_PERFORMANCE_OVERLAY'),
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
