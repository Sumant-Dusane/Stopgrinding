import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';

abstract class OverlaySettingsRepository {
  Future<OverlaySettings> load();

  Future<void> save(OverlaySettings settings);
}
