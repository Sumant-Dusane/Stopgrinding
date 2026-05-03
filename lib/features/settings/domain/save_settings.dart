import 'package:stopgrinding/features/overlay/domain/overlay_service.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';

class SaveSettings {
  const SaveSettings(this._overlayService);

  final OverlayService _overlayService;

  Future<void> call(OverlaySettings settings) {
    return _overlayService.saveSettings(settings);
  }
}
