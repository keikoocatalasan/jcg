import 'package:flutter_riverpod/flutter_riverpod.dart';

class RegistrationData {
  final String fullName;
  final String username;

  const RegistrationData({
    required this.fullName,
    required this.username,
  });
}

final registrationDataProvider =
    StateProvider<RegistrationData?>((ref) => null);
