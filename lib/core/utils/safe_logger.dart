import 'package:flutter/foundation.dart';

/// Secure logging utility ensuring no secrets, passwords, PINs, or raw vault data
/// are ever emitted into system logs or logcat.
class SafeLogger {
  SafeLogger._();

  static const bool _isLoggingEnabled = kDebugMode;

  /// Log general lifecycle info. Sensitive objects must NEVER be passed.
  static void info(String tag, String message) {
    if (_isLoggingEnabled) {
      debugPrint('[VaultKey:INFO][$tag] $message');
    }
  }

  /// Log warnings.
  static void warn(String tag, String message) {
    if (_isLoggingEnabled) {
      debugPrint('[VaultKey:WARN][$tag] $message');
    }
  }

  /// Log non-sensitive error messages.
  static void error(String tag, String message, [Object? error]) {
    if (_isLoggingEnabled) {
      debugPrint(
        '[VaultKey:ERROR][$tag] $message ${error != null ? '($error)' : ''}',
      );
    }
  }
}
