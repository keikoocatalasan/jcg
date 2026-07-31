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

  static void validateRuntimeConfiguration() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError('SUPABASE_URL and SUPABASE_ANON_KEY are required.');
    }
    if (environment == 'production' &&
        (!fastApiBaseUrl.startsWith('https://') ||
            fastApiBaseUrl.contains('10.0.2.2'))) {
      throw StateError('Production FASTAPI_BASE_URL must use HTTPS.');
    }
  }
}
