import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

class LaunchAtStartupService extends ChangeNotifier {
  LaunchAtStartupService({LaunchAtStartupAdapter? adapter})
    : _adapter = adapter ?? PackageLaunchAtStartupAdapter();

  final LaunchAtStartupAdapter _adapter;

  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isEnabled = false;
  String? _lastError;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isEnabled => _isEnabled;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    if (_isInitialized || _isLoading) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _adapter.initialize();
      _isEnabled = await _adapter.isEnabled();
      _lastError = null;
      _isInitialized = true;
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      await _adapter.initialize();
      _isEnabled = await _adapter.isEnabled();
      _lastError = null;
      _isInitialized = true;
    } catch (error) {
      _lastError = error.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _adapter.initialize();
      if (enabled) {
        await _adapter.enable();
      } else {
        await _adapter.disable();
      }
      _isEnabled = await _adapter.isEnabled();
      _lastError = null;
      _isInitialized = true;
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

abstract class LaunchAtStartupAdapter {
  Future<void> initialize();

  Future<bool> isEnabled();

  Future<void> enable();

  Future<void> disable();
}

class PackageLaunchAtStartupAdapter implements LaunchAtStartupAdapter {
  bool _isConfigured = false;

  @override
  Future<void> initialize() async {
    if (_isConfigured) {
      return;
    }

    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
      packageName: packageInfo.packageName,
    );
    _isConfigured = true;
  }

  @override
  Future<void> disable() async {
    await launchAtStartup.disable();
  }

  @override
  Future<void> enable() async {
    await launchAtStartup.enable();
  }

  @override
  Future<bool> isEnabled() {
    return launchAtStartup.isEnabled();
  }
}
