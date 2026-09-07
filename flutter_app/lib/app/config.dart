import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const fastApiBaseUrl = String.fromEnvironment(
    'FASTAPI_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Local-only test access. This is intentionally a compile-time flag so it
  /// cannot be enabled by a user or by a remotely supplied value at runtime.
  /// The release guard below also makes accidental production builds fail
  /// early instead of silently weakening authentication.
  static const devAuthBypassRequested = bool.fromEnvironment(
    'JCG_DEV_BYPASS_AUTH',
    defaultValue: false,
  );
  static bool get isProduction =>
      environment.trim().toLowerCase() == 'production';

  static bool get isLocalTestMode =>
      devAuthBypassRequested && !kReleaseMode && !isProduction;

  static const localTestUserId = 'local-demo-admin';
  static const localTestUserEmail = 'demo.admin@local.jcg';

  static void validateRuntimeConfiguration() {
    if (devAuthBypassRequested && kReleaseMode) {
      throw StateError('JCG_DEV_BYPASS_AUTH is not allowed in release builds.');
    }
    if (devAuthBypassRequested && isProduction) {
      throw StateError('JCG_DEV_BYPASS_AUTH is not allowed in production.');
    }
    if (isLocalTestMode) return;

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError('SUPABASE_URL and SUPABASE_ANON_KEY are required.');
    }
    if (isProduction &&
        (!fastApiBaseUrl.startsWith('https://') ||
            fastApiBaseUrl.contains('10.0.2.2'))) {
      throw StateError('Production FASTAPI_BASE_URL must use HTTPS.');
    }
  }
}
