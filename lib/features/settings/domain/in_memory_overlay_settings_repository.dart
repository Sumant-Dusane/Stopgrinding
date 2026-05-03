import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';
import 'package:stopgrinding/features/settings/domain/overlay_settings_repository.dart';

class InMemoryOverlaySettingsRepository implements OverlaySettingsRepository {
  InMemoryOverlaySettingsRepository({OverlaySettings? initialSettings})
    : _settings = initialSettings ?? OverlaySettings.defaults();

  OverlaySettings _settings;

  @override
  Future<OverlaySettings> load() async {
    return _settings;
  }

  @override
  Future<void> save(OverlaySettings settings) async {
    _settings = settings;
  }
}
