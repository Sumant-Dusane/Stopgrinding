import 'package:flutter/foundation.dart';

enum ShellDestination { home, settings }

class ShellNavigationController extends ChangeNotifier {
  ShellDestination _destination = ShellDestination.home;
  int _requestVersion = 0;

  ShellDestination get destination => _destination;
  int get requestVersion => _requestVersion;

  void openHome() {
    _destination = ShellDestination.home;
    _requestVersion += 1;
    notifyListeners();
  }

  void openSettings() {
    _destination = ShellDestination.settings;
    _requestVersion += 1;
    notifyListeners();
  }
}
