import 'package:stopgrinding/features/overlay/domain/overlay_service.dart';

class ShowOverlay {
  const ShowOverlay(this._overlayService);

  final OverlayService _overlayService;

  Future<void> call() {
    return _overlayService.showOverlay();
  }
}
