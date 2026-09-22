import 'package:flutter_riverpod/flutter_riverpod.dart';

class RegistrationData {
  final String fullName;
  final String username;
  final String accountType;

  const RegistrationData({
    required this.fullName,
    required this.username,
    this.accountType = 'user',
  });
}

final registrationDataProvider =
    StateProvider<RegistrationData?>((ref) => null);
