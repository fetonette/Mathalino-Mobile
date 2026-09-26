/// Custom Authentication Exception for Mathalino Student App
class AuthException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AuthException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}
