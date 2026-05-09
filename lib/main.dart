import 'package:flutter/widgets.dart';
import 'package:stopgrinding/app/app.dart';
import 'package:stopgrinding/core/logging/app_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error('FlutterError', details.exceptionAsString());
    FlutterError.presentError(details);
  };

  AppLogger.info('main', 'Starting StopGrinding app.');
  runStopGrindingApp();
}
