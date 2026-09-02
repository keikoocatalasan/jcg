import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';

class LocalUserIdentity {
  const LocalUserIdentity._();

  /// Resolves the stable application user ID stored in local domain tables.
  ///
  /// During first-time offline onboarding the auth ID is temporarily used as
  /// the local user ID. After the first Supabase pull, the server-generated
  /// app_user.user_id replaces it while auth_user_id remains the lookup key.
  static Future<String> resolve(
    DatabaseProvider databaseProvider,
    String authUserId,
  ) async {
    final database = await databaseProvider.database;
    return resolveInDatabase(database, authUserId);
  }

  static Future<String> resolveInDatabase(
    Database database,
    String authUserId,
  ) async {
    final rows = await database.query(
      'profiles',
      columns: ['user_id'],
      where: 'auth_user_id = ?',
      whereArgs: [authUserId],
      limit: 1,
    );
    return rows.isEmpty ? authUserId : rows.first['user_id'] as String;
  }
}

final localUserIdProvider = FutureProvider<String?>((ref) async {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) return null;
  return LocalUserIdentity.resolve(DatabaseProvider(), authUser.id);
});
