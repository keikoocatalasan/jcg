class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static bool isValidEmail(String value) => _emailRegex.hasMatch(value);

  static bool isValidPassword(String value) {
    if (value.length < 8) return false;
    if (!RegExp(r'[A-Z]').hasMatch(value)) return false;
    if (!RegExp(r'[a-z]').hasMatch(value)) return false;
    if (!RegExp(r'[0-9]').hasMatch(value)) return false;
    return true;
  }

  static bool passwordsMatch(String password, String confirmation) =>
      password == confirmation;

  static bool isValidNickname(String value) =>
      value.trim().length >= 2 && value.trim().length <= 20;

  static bool isValidAge(int value) => value >= 13 && value <= 80;

  static bool isValidHeight(double value) => value >= 100 && value <= 250;

  static bool isValidWeight(double value) => value >= 20 && value <= 300;

  static bool isValidBudget(double value) => value >= 20;

  static bool isValidWaterAmount(int value) => value >= 1 && value <= 5000;

  static bool isValidQuantity(double value) => value > 0;

  static bool isPositiveNumber(double value) => value > 0;
}
