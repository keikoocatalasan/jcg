import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/auth/registration_data_provider.dart';

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

  test('registration data defaults to a standard user account', () {
    const data = RegistrationData(fullName: 'Sample User', username: 'sample');

    expect(data.accountType, 'user');
  });

  test('registration data retains a nutritionist request', () {
    const data = RegistrationData(
      fullName: 'Sample Nutritionist',
      username: 'nutritionist',
      accountType: 'nutritionist',
    );

    expect(data.accountType, 'nutritionist');
  });
}
