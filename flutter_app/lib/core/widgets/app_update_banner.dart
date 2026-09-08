import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:jcg_fitness/core/network/app_release.dart';

// Retain the result for this app session instead of refetching on every visit.
final availableAppUpdateProvider = FutureProvider<AppRelease?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final release = await AppRelease.fetch();
    return AppRelease.compareVersions(release.version, info.version) > 0
        ? release
        : null;
  } catch (_) {
    // Automatic discovery must never block the dashboard when offline.
    return null;
  }
});

final dismissedAppUpdateProvider = StateProvider<int?>((ref) => null);

class AppUpdateBanner extends ConsumerWidget {
  const AppUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(availableAppUpdateProvider).valueOrNull;
    final dismissed = ref.watch(dismissedAppUpdateProvider);
    if (release == null || release.versionCode == dismissed) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('JCG Fitness ${release.version} is available',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          const Text('Review the latest version whenever you are ready.'),
          Wrap(spacing: 12, children: [
            TextButton(
                onPressed: () => context.push('/settings'),
                child: const Text('View update')),
            TextButton(
                onPressed: () {
                  ref.read(dismissedAppUpdateProvider.notifier).state =
                      release.versionCode;
                },
                child: const Text('Later')),
          ]),
        ]),
      ),
    );
  }
}
