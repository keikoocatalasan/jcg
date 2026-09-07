import 'package:flutter/material.dart';
import 'package:jcg_fitness/app/theme.dart';

/// Renders the first frame while hosted services initialize. Keeping this
/// outside the main router prevents a slow SDK restore from holding Android
/// on its native splash screen indefinitely.
class AppBootstrap extends StatefulWidget {
  final Future<void> Function() initialize;
  final Widget child;

  const AppBootstrap({
    super.key,
    required this.initialize,
    required this.child,
  });

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = widget.initialize();
  }

  void _retry() {
    setState(() => _initialization = widget.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BootstrapMaterialApp(
            child: _BootstrapError(onRetry: _retry),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapMaterialApp(child: _BootstrapLoading());
        }
        return widget.child;
      },
    );
  }
}

class _BootstrapMaterialApp extends StatelessWidget {
  final Widget child;

  const _BootstrapMaterialApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: child,
    );
  }
}

class _BootstrapLoading extends StatelessWidget {
  const _BootstrapLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.eco_outlined,
                  size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'JCG FITNESS',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 18),
              Text(
                'Preparing your secure session…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  final VoidCallback onRetry;

  const _BootstrapError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 64, color: AppColors.warning),
              const SizedBox(height: 20),
              Text(
                'Unable to start securely',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
