import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/profile_repository.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';

class WelcomeMessage {
  final bool returningUser;
  final String nickname;

  const WelcomeMessage({
    required this.returningUser,
    required this.nickname,
  });

  String get text => returningUser
      ? 'Welcome back, $nickname!'
      : 'Welcome to JCG Fitness, $nickname!';
}

final welcomeMessageProvider = FutureProvider<WelcomeMessage?>((ref) async {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) return null;

  final databaseProvider = DatabaseProvider();
  final profile =
      await ProfileRepository(databaseProvider).readByUserId(authUser.id);
  final localUserId = profile?.userId ?? authUser.id;
  final database = await databaseProvider.database;
  final history = await database.rawQuery(
    '''
      SELECT (
        (SELECT COUNT(*) FROM meal_logs WHERE user_id = ? AND is_deleted = 0) +
        (SELECT COUNT(*) FROM water_logs WHERE user_id = ?) +
        (SELECT COUNT(*) FROM weight_logs WHERE user_id = ?) +
        (SELECT COUNT(*) FROM meal_plans WHERE user_id = ?)
      ) AS history_count
    ''',
    [localUserId, localUserId, localUserId, localUserId],
  );
  final hasHistory = (history.first['history_count'] as num? ?? 0) > 0;
  final prefs = await SharedPreferences.getInstance();
  final seenKey = 'welcome_seen_${authUser.id}';
  final wasSeen = prefs.getBool(seenKey) ?? false;
  await prefs.setBool(seenKey, true);

  return WelcomeMessage(
    returningUser: wasSeen || hasHistory,
    nickname: profile?.nickname?.trim().isNotEmpty == true
        ? profile!.nickname!.trim()
        : 'there',
  );
});
