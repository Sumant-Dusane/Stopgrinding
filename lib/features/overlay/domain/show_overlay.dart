import 'package:stopgrinding/core/logging/app_logger.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_service.dart';

class ShowOverlay {
  const ShowOverlay(this._overlayService);

  final OverlayService _overlayService;

  Future<void> call() {
    AppLogger.info('ShowOverlay', 'ShowOverlay command invoked from Flutter.');
    return _overlayService.showOverlay();
  }
}
