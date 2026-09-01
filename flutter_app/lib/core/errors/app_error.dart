class AppError {
  final String code;
  final String message;
  final dynamic details;

  const AppError({
    required this.code,
    required this.message,
    this.details,
  });

  factory AppError.unknown([String? message]) => AppError(
        code: 'UNKNOWN',
        message: message ?? 'An unexpected error occurred.',
      );

  factory AppError.network([String? message]) => AppError(
        code: 'NETWORK',
        message: message ?? 'No internet connection.',
      );

  factory AppError.validation(String message) => AppError(
        code: 'VALIDATION',
        message: message,
      );

  factory AppError.notFound([String? message]) => AppError(
        code: 'NOT_FOUND',
        message: message ?? 'Resource not found.',
      );

  @override
  String toString() => 'AppError($code): $message';
}
