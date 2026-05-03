import 'package:stopgrinding/features/overlay/domain/overlay_service.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';

class DismissOverlay {
  const DismissOverlay(this._overlayService);

  final OverlayService _overlayService;

  Future<void> call({
    OverlayDismissReason reason = OverlayDismissReason.hiddenByApp,
  }) {
    return _overlayService.dismissOverlay(reason: reason);
  }
}
