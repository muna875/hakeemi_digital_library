class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, [this.cause]);

  @override
  String toString() =>
      cause == null ? 'AppException: $message' : 'AppException: $message ($cause)';
}
