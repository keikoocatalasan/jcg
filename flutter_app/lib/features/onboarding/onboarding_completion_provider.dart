import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final initialOnboardingCompleteProvider = Provider<bool>((ref) => false);

final onboardingCompleteProvider = StateProvider<bool>((ref) {
  return ref.watch(initialOnboardingCompleteProvider);
});

String onboardingCompleteKey(String userId) => 'onboarding_complete_$userId';

/// Administrators use the moderation and catalog console, so they do not need
/// to complete the nutrition-specific onboarding flow before accessing it.
Future<bool> loadAdminAccess(String userId) async {
  try {
    final appUser = await Supabase.instance.client
        .from('app_user')
        .select('role(role_code)')
        .eq('auth_user_id', userId)
        .maybeSingle();
    return (appUser?['role'] as Map?)?['role_code'] == 'admin';
  } catch (_) {
    return false;
  }
}

Future<bool> loadOnboardingComplete(String userId) async {
  bool? localCompletion;

  // Admins should be able to enter the admin console even when they do not
  // have a consumer profile or nutrition onboarding record.
  if (await loadAdminAccess(userId)) {
    await saveOnboardingComplete(userId, true);
    return true;
  }

  try {
    final local =
        await ProfileRepository(DatabaseProvider()).readByUserId(userId);
    if (local != null) {
      localCompletion = local.onboardingCompleted;
      if (local.onboardingCompleted) {
        await saveOnboardingComplete(userId, true);
        return true;
      }
    }
  } catch (_) {
    // The local database may not exist on the first authenticated launch.
  }

  try {
    final client = Supabase.instance.client;
    final appUser = await client
        .from('app_user')
        .select('user_id')
        .eq('auth_user_id', userId)
        .maybeSingle();
    final appUserId = appUser?['user_id'] as String?;
    if (appUserId != null) {
      final remote = await client
          .from('user_profile')
          .select('onboarding_completed')
          .eq('user_id', appUserId)
          .maybeSingle();
      if (remote != null) {
        final complete = remote['onboarding_completed'] == true;
        await saveOnboardingComplete(userId, complete);
        return complete;
      }
    }
  } catch (_) {
    // Offline launch falls back to the last cached completion state.
  }

  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(onboardingCompleteKey(userId)) ??
      localCompletion ??
      false;
}

Future<void> saveOnboardingComplete(String userId, bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(onboardingCompleteKey(userId), value);
}
