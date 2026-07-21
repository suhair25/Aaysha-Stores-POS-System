import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Application logger utility
/// Provides formatted logging for debugging and error tracking
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
  );

  static String? _safeErrorString(dynamic error) {
    if (error == null) return null;
    try {
      final value = error.toString();
      if (value.isEmpty) {
        return 'Unknown error';
      }
      return value;
    } catch (_) {
      try {
        return 'Unknown error of type ${error.runtimeType}';
      } catch (_) {
        return 'Unknown error';
      }
    }
  }

  static void _safeLog(
    void Function(String message, {dynamic error, StackTrace? stackTrace})
        loggerMethod,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    final safeMessage = message.toString();
    final safeError = _safeErrorString(error);

    try {
      if (safeError == null) {
        loggerMethod(safeMessage, stackTrace: stackTrace);
      } else {
        loggerMethod(safeMessage, error: safeError, stackTrace: stackTrace);
      }
    } catch (_) {
      final fallbackMessage = safeError == null
          ? safeMessage
          : '$safeMessage | Error: $safeError';
      try {
        debugPrint(fallbackMessage);
      } catch (_) {
        // Ignore fallback output issues.
      }
    }
  }

  /// Log debug message
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _safeLog(_logger.d, message, error, stackTrace);
  }

  /// Log info message
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _safeLog(_logger.i, message, error, stackTrace);
  }

  /// Log warning message
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _safeLog(_logger.w, message, error, stackTrace);
  }

  /// Log error message
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _safeLog(_logger.e, message, error, stackTrace);
  }

  /// Log success message
  static void success(String message) {
    _logger.i('✅ $message');
  }

  /// Log failure message
  static void failure(String message) {
    _logger.e('❌ $message');
  }

  /// Log API request
  static void logApiRequest(String method, String url, {dynamic body}) {
    _logger.i('📤 $method $url\nBody: $body');
  }

  /// Log API response
  static void logApiResponse(String method, String url, dynamic response) {
    _logger.i('📥 $method $url\nResponse: $response');
  }

  /// Log database operation
  static void logDatabase(String operation, String table, {dynamic data}) {
    _logger.i('🗄️ DB: $operation on $table\nData: $data');
  }
}
