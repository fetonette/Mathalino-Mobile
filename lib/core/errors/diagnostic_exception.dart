/// Custom exception for diagnostic assessment errors in Mathalino Student App.
///
/// Thrown when diagnostic loading, scoring, placement, or submission
/// encounters a known, recoverable failure (e.g. no questions available,
/// incomplete answers, Firestore write failures).
class DiagnosticException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  DiagnosticException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'DiagnosticException: $message';
}
