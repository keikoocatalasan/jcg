import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/errors/result.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:jcg_fitness/core/sync/sync_initial_pull.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/auth/session_loading_provider.dart';
import 'package:jcg_fitness/features/onboarding/onboarding_completion_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionLoadingScreen extends ConsumerStatefulWidget {
  const SessionLoadingScreen({super.key});

  @override
  ConsumerState<SessionLoadingScreen> createState() =>
      _SessionLoadingScreenState();
}

class _SessionLoadingScreenState extends ConsumerState<SessionLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinnerController;
  final _statuses = <_SessionStepStatus>[
    _SessionStepStatus.complete,
    _SessionStepStatus.active,
    _SessionStepStatus.pending,
    _SessionStepStatus.pending,
  ];

  @override
  void initState() {
    super.initState();
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runChecks());
    });
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    super.dispose();
  }

  Future<void> _runChecks() async {
    await _ensureSupabaseInitialized();
    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final supabase = ref.read(supabaseClientProvider);
    final session = supabase.auth.currentSession;
    _setStep(0, _SessionStepStatus.complete);

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (session == null) {
      _setStep(1, _SessionStepStatus.complete);
      _setStep(2, _SessionStepStatus.complete);
      _setStep(3, _SessionStepStatus.complete);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) {
        ref.read(launchSessionCheckedProvider.notifier).state = true;
        context.go('/login');
      }
      return;
    }

    final statusResult =
        await ref.read(authServiceProvider).checkAccountStatus(session.user.id);
    if (!mounted) return;
    _setStep(1, _SessionStepStatus.complete);

    if (statusResult is Failure) {
      await supabase.auth.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) {
        ref.read(launchSessionCheckedProvider.notifier).state = true;
        context.go('/login');
      }
      return;
    }

    await SyncInitialPull.pullInitialData(DatabaseProvider());
    await SyncInitialPull.pullUserData(session.user.id, DatabaseProvider());

    _setStep(2, _SessionStepStatus.active);
    final onboardingComplete = await loadOnboardingComplete(session.user.id);
    final adminAccess = await loadAdminAccess(session.user.id);
    if (!mounted) return;
    ref.read(onboardingCompleteProvider.notifier).state = onboardingComplete;
    _setStep(2, _SessionStepStatus.complete);

    _setStep(3, _SessionStepStatus.active);
    await _checkPendingSync();
    if (!mounted) return;
    _setStep(3, _SessionStepStatus.complete);

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    ref.read(launchSessionCheckedProvider.notifier).state = true;
    context.go(
      adminAccess
          ? '/admin'
          : onboardingComplete
              ? '/dashboard'
              : '/onboarding',
    );
  }

  Future<void> _ensureSupabaseInitialized() async {
    try {
      Supabase.instance.client;
      return;
    } catch (_) {
      final url = const String.fromEnvironment('SUPABASE_URL');
      final key = const String.fromEnvironment('SUPABASE_ANON_KEY');
      if (url.isEmpty || key.isEmpty) {
        throw StateError(
            'Supabase URL and ANON_KEY must be provided via --dart-define');
      }
      await Supabase.initialize(url: url, publishableKey: key);
    }
  }

  Future<void> _checkPendingSync() async {
    try {
      final db = await DatabaseProvider().database;
      await db.query(
        'sync_queue',
        columns: ['sync_queue_id'],
        where: 'sync_status = ?',
        whereArgs: ['pending'],
        limit: 1,
      );
    } catch (_) {
      // Pending sync is non-blocking for app launch.
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  void _setStep(int index, _SessionStepStatus status) {
    if (!mounted) return;
    setState(() => _statuses[index] = status);
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                if (!isOnline) const _OfflineNotice(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 940;
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          28,
                          compact ? 18 : 42,
                          28,
                          18,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight -
                                    (isOnline ? 0 : _OfflineNotice.height))
                                .clamp(0, double.infinity)
                                .toDouble(),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const _BrandMark(),
                              SizedBox(height: compact ? 22 : 42),
                              Text(
                                'Checking your session...',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Preparing your nutrition dashboard',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                              SizedBox(height: compact ? 20 : 34),
                              _SessionSpinner(controller: _spinnerController),
                              SizedBox(height: compact ? 26 : 44),
                              _ChecklistCard(statuses: _statuses),
                              SizedBox(height: compact ? 30 : 58),
                              const _SecurityNote(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _SessionStepStatus { complete, active, pending }

class _OfflineNotice extends StatelessWidget {
  static const double height = 56;

  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.textPrimary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You\'re offline. Some features may be limited.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.fitness_center, size: 80, color: AppColors.primary),
        const SizedBox(height: 12),
        Text(
          'JCG FITNESS',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 0.95,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandRule(),
            const SizedBox(width: 10),
            Text(
              'BUDGET NUTRITION',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
            ),
            const SizedBox(width: 10),
            _BrandRule(),
          ],
        ),
      ],
    );
  }
}

class _BrandRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 2,
      color: AppColors.borderStrong,
    );
  }
}

class _SessionSpinner extends StatelessWidget {
  final AnimationController controller;

  const _SessionSpinner({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Transform.rotate(
            angle: controller.value * math.pi * 2,
            child: CircularProgressIndicator(
              value: 0.68,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final List<_SessionStepStatus> statuses;

  const _ChecklistCard({required this.statuses});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _CheckRow(
            status: statuses[0],
            title: 'Checking saved session',
            trailing: Icons.check,
          ),
          const _DividerInset(),
          _CheckRow(
            status: statuses[1],
            title: 'Checking account status',
            subtitle: statuses[1] == _SessionStepStatus.active
                ? 'Please wait...'
                : null,
            emphasized: statuses[1] == _SessionStepStatus.active,
          ),
          const _DividerInset(),
          _CheckRow(
            status: statuses[2],
            title: 'Checking onboarding progress',
          ),
          const _DividerInset(),
          _CheckRow(
            status: statuses[3],
            title: 'Checking pending sync',
          ),
        ],
      ),
    );
  }
}

class _DividerInset extends StatelessWidget {
  const _DividerInset();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: 22,
      color: AppColors.divider,
    );
  }
}

class _CheckRow extends StatelessWidget {
  final _SessionStepStatus status;
  final String title;
  final String? subtitle;
  final IconData? trailing;
  final bool emphasized;

  const _CheckRow({
    required this.status,
    required this.title,
    this.subtitle,
    this.trailing,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _StepIcon(status: status, fallback: trailing),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight:
                            emphasized ? FontWeight.w800 : FontWeight.w500,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          _TrailingStatus(status: status),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  final _SessionStepStatus status;
  final IconData? fallback;

  const _StepIcon({required this.status, this.fallback});

  @override
  Widget build(BuildContext context) {
    if (status == _SessionStepStatus.complete) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.10),
        ),
        child: Center(
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: const Icon(Icons.check, color: AppColors.surface, size: 18),
          ),
        ),
      );
    }

    if (status == _SessionStepStatus.active) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.10),
        ),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(
            strokeWidth: 3,
            strokeCap: StrokeCap.round,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Icon(
        fallback ?? Icons.schedule_outlined,
        color: AppColors.textSecondary,
        size: 22,
      ),
    );
  }
}

class _TrailingStatus extends StatelessWidget {
  final _SessionStepStatus status;

  const _TrailingStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == _SessionStepStatus.complete) {
      return const Icon(Icons.check, color: AppColors.primary, size: 26);
    }
    return const Text(
      '-',
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: AppColors.primary,
            size: 23,
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            'Your data is safe and secure with us.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w400,
                ),
          ),
        ),
      ],
    );
  }
}
