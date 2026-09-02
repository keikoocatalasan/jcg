import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/core/errors/result.dart';
import 'package:jcg_fitness/core/errors/app_error.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';

/// Checks whether Google Play Services is available on this device.
/// Returns true if available, false if missing (e.g. Huawei, custom ROMs, China).
Future<bool> isGooglePlayServicesAvailable() async {
  try {
    final googleSignIn = GoogleSignIn(scopes: ['email']);
    // A silent sign-in attempt will fail quickly if Play Services is absent.
    await googleSignIn.signInSilently();
    return true;
  } on PlatformException catch (e) {
    final code = e.code.toLowerCase();
    if (code.contains('network_error') ||
        code.contains('sign_in_failed') ||
        code.contains('play_services')) {
      return false;
    }
    // Unknown error — assume available and let the real flow handle it.
    return true;
  } catch (_) {
    return true;
  }
}

final authSessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentSession;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map(
    (event) => event.session?.user,
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

class RegistrationResult {
  final User user;
  final Session? session;

  const RegistrationResult({required this.user, required this.session});

  bool get requiresEmailConfirmation => session == null;
}

class AuthService {
  final Ref _ref;

  AuthService(this._ref);

  SupabaseClient get _supabase => _ref.read(supabaseClientProvider);

  GoogleSignIn get _googleSignIn {
    final serverClientId = AppConfig.googleWebClientId;
    return GoogleSignIn(
      scopes: ['email', 'openid', 'profile'],
      serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
    );
  }

  Future<Result<RegistrationResult>> register(
    String email,
    String password, {
    required String fullName,
    required String username,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'username': username},
      );
      final user = response.user;
      if (user == null) {
        return Failure(
            AppError.unknown('Registration failed. Please try again.'));
      }
      return Success(RegistrationResult(user: user, session: response.session));
    } on AuthException catch (e) {
      return Failure<RegistrationResult>(
        AppError(code: 'AUTH_ERROR', message: e.message),
      );
    } catch (e) {
      return Failure<RegistrationResult>(
        AppError.unknown('Registration failed. Please try again.'),
      );
    }
  }

  Future<Result<Session>> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = response.session;
      if (session == null) {
        return Failure(AppError.unknown('Login failed. Please try again.'));
      }

      final statusResult = await checkAccountStatus(session.user.id);
      switch (statusResult) {
        case Success(data: final _):
          return Success(session);
        case Failure(:final error):
          await _supabase.auth.signOut();
          return Failure<Session>(error);
      }
    } on AuthException catch (e) {
      return Failure(AppError(code: 'AUTH_ERROR', message: e.message));
    } catch (e) {
      return Failure(AppError.unknown('Login failed. Please try again.'));
    }
  }

  Future<Result<bool>> checkAccountStatus(String authUserId) async {
    try {
      final response = await _supabase
          .from('app_user')
          .select('account_status(status_code)')
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      if (response == null) {
        return const Failure(AppError(
          code: 'ACCOUNT_UNKNOWN',
          message: 'Unable to verify your account. Please try again.',
        ));
      }

      final statusCode =
          (response['account_status'] as Map?)?['status_code'] as String?;
      if (statusCode == 'disabled') {
        return const Failure(AppError(
          code: 'ACCOUNT_DISABLED',
          message: 'Your account has been disabled. Please contact support.',
        ));
      }

      return const Success(true);
    } on AppError {
      rethrow;
    } catch (e) {
      return const Failure(AppError(
        code: 'ACCOUNT_CHECK_FAILED',
        message: 'Unable to verify your account. Please try again.',
      ));
    }
  }

  Future<Result<User>> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return Failure(AppError.unknown('Google sign-in was cancelled.'));
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        return Failure(AppError.unknown(
            'Unable to get Google credentials. Please try again.'));
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) {
        return Failure(
            AppError.unknown('Google sign-in failed. Please try again.'));
      }
      final statusResult = await checkAccountStatus(user.id);
      switch (statusResult) {
        case Success(data: final _):
          return Success(user);
        case Failure(:final error):
          await _supabase.auth.signOut();
          return Failure<User>(error);
      }
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled' || e.code == 'CANCELED') {
        return Failure(AppError.unknown('Google sign-in was cancelled.'));
      }
      return Failure(AppError.unknown('Google sign-in failed: ${e.message}'));
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') ||
          msg.contains('user already registered') ||
          msg.contains('identity already exists') ||
          msg.contains('user already exists')) {
        return Failure(AppError(
          code: 'ACCOUNT_EXISTS',
          message:
              'An account with this email already exists. Please log in with your password, then link Google from your profile settings.',
        ));
      }
      return Failure(AppError(code: 'AUTH_ERROR', message: e.message));
    } catch (e) {
      return Failure(
          AppError.unknown('Google sign-in failed. Please try again.'));
    }
  }

  Future<Result<void>> sendPasswordReset(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return const Success(null);
    } on AuthException catch (e) {
      return Failure(AppError(code: 'AUTH_ERROR', message: e.message));
    } catch (e) {
      return Failure(
          AppError.unknown('Failed to send reset link. Please try again.'));
    }
  }

  Future<Result<void>> logout() async {
    try {
      await _supabase.auth.signOut();
      return const Success(null);
    } on AuthException catch (e) {
      return Failure(AppError(code: 'AUTH_ERROR', message: e.message));
    } catch (e) {
      return Failure(AppError.unknown('Logout failed. Please try again.'));
    }
  }

  Future<Result<Map<String, dynamic>>> requestPasswordReset(
      String email) async {
    try {
      final uri = Uri.parse('${AppConfig.fastApiBaseUrl}/auth/forgot-password');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Success(body);
      }
      return Failure(AppError.unknown('Failed to request password reset.'));
    } catch (e) {
      return Failure(AppError.unknown('Connection error. Please try again.'));
    }
  }

  Future<Result<Map<String, dynamic>>> verifyResetOtp(
      String email, String otp) async {
    try {
      final uri =
          Uri.parse('${AppConfig.fastApiBaseUrl}/auth/verify-reset-otp');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Success(body);
      }
      return Failure(
          AppError(code: 'INVALID_OTP', message: 'Invalid or expired code.'));
    } catch (e) {
      return Failure(AppError.unknown('Connection error. Please try again.'));
    }
  }

  Future<Result<Map<String, dynamic>>> resetPassword(
      String resetToken, String newPassword) async {
    try {
      final uri = Uri.parse('${AppConfig.fastApiBaseUrl}/auth/reset-password');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {'reset_token': resetToken, 'new_password': newPassword}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Success(body);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['detail'] ??
          body['error']?['message'] ??
          'Password reset failed.';
      return Failure(AppError.unknown(msg.toString()));
    } catch (e) {
      return Failure(AppError.unknown('Connection error. Please try again.'));
    }
  }
}
