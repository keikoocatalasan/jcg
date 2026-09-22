import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';

void main() {
  test('maps an existing-email provider error to an actionable message', () {
    final error = AuthService.registrationError('User already registered');

    expect(error.code, 'ACCOUNT_EXISTS');
    expect(error.message, contains('logging in'));
    expect(error.message, contains('Forgot password'));
  });

  test('maps an ambiguous empty signup response to an actionable message', () {
    final error = AuthService.registrationError();

    expect(error.code, 'REGISTRATION_FAILED');
    expect(error.message, contains('may already be registered'));
    expect(error.message, contains('temporarily unavailable'));
  });
}
