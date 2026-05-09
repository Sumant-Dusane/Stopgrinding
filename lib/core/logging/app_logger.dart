import 'package:flutter/foundation.dart';

enum AppLogLevel { debug, info, warning, error }

class AppLogger {
  const AppLogger._();

  static void debug(String scope, String message) {
    _log(AppLogLevel.debug, scope, message);
  }

  static void info(String scope, String message) {
    _log(AppLogLevel.info, scope, message);
  }

  static void warning(String scope, String message) {
    _log(AppLogLevel.warning, scope, message);
  }

  static void error(String scope, String message, [Object? error]) {
    _log(
      AppLogLevel.error,
      scope,
      error == null ? message : '$message | error=$error',
    );
  }

  static void _log(AppLogLevel level, String scope, String message) {
    final String timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] [${level.name.toUpperCase()}] [$scope] $message');
  }
}
