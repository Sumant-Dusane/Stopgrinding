import 'package:flutter/services.dart';

enum ShellWindowAction { showMainWindow, hideMainWindow, quitApp }

class ShellWindowService {
  static const MethodChannel _channel = MethodChannel('shell_window');

  Future<void> showMainWindow() async {
    await _invoke(ShellWindowAction.showMainWindow);
  }

  Future<void> hideMainWindow() async {
    await _invoke(ShellWindowAction.hideMainWindow);
  }

  Future<void> quitApp() async {
    await _invoke(ShellWindowAction.quitApp);
  }

  Future<void> _invoke(ShellWindowAction action) async {
    await _channel.invokeMethod<void>(action.name);
  }
}
