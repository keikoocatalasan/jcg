import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Which product experience the signed-in account should land in.
enum AccountFlowMode { consumer, nutritionist }

/// Where a nutritionist-flow account belongs right now.
enum NutritionistLanding { none, application, workspace }

/// Set once during the session check so the router can make synchronous
/// redirect decisions before the first protected frame is shown.
final accountFlowProvider =
    StateProvider<AccountFlowMode>((ref) => AccountFlowMode.consumer);

final nutritionistLandingProvider =
    StateProvider<NutritionistLanding>((ref) => NutritionistLanding.none);

/// Admin console access has priority over the nutritionist flow so an
/// administrator who also requested reviewer access keeps the admin console.
final adminFlowProvider = StateProvider<bool>((ref) => false);

/// Reads the nutritionist intent that registration stores in the Supabase
/// Auth user metadata (`requested_account_type`). This is intent only; the
/// `nutritionist_application` row remains the authorization source of truth.
bool hasNutritionistIntent() {
  if (AppConfig.isLocalTestMode) return false;
  try {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.userMetadata?['requested_account_type'] == 'nutritionist';
  } catch (_) {
    return false;
  }
}

/// Pure resolver so the routing matrix is unit-testable without Supabase.
NutritionistLanding resolveNutritionistLanding({
  required bool hasIntent,
  required NutritionistApplication? application,
}) {
  if (!hasIntent && application == null) {
    return NutritionistLanding.none;
  }
  if (application != null &&
      application.isVerified &&
      !application.isExpired) {
    return NutritionistLanding.workspace;
  }
  return NutritionistLanding.application;
}

/// Lets a nutritionist-flow account use the normal consumer experience.
/// The router then enforces consumer onboarding when no profile exists.
void enterConsumerFlow(WidgetRef ref) {
  ref.read(accountFlowProvider.notifier).state = AccountFlowMode.consumer;
  ref.read(nutritionistLandingProvider.notifier).state =
      NutritionistLanding.none;
}

/// Returns a nutritionist-flow account to its professional landing.
void enterNutritionistFlow(WidgetRef ref, NutritionistLanding landing) {
  ref.read(accountFlowProvider.notifier).state = AccountFlowMode.nutritionist;
  ref.read(nutritionistLandingProvider.notifier).state = landing;
}

String landingRoute(NutritionistLanding landing) {
  return landing == NutritionistLanding.workspace
      ? '/nutritionist'
      : '/nutritionist-application';
}
