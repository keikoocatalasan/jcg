import 'package:shared_preferences/shared_preferences.dart';

import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/sync/sync_initial_pull.dart';

/// Best-effort refresh of the official food catalog so verification changes
/// made by a nutritionist reach consumer clients without a full re-login.
/// Debounced and fully offline-safe.
class OfficialFoodsRefresh {
  static const _lastRefreshKey = 'official_foods_refreshed_at_ms';
  static const _minInterval = Duration(minutes: 5);

  static Future<void> maybeRefresh() async {
    if (AppConfig.isLocalTestMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = prefs.getInt(_lastRefreshKey) ?? 0;
      if (now - last < _minInterval.inMilliseconds) return;
      await prefs.setInt(_lastRefreshKey, now);
      await SyncInitialPull.pullInitialData(DatabaseProvider())
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Cached catalog data remains usable when the refresh fails.
    }
  }
}
