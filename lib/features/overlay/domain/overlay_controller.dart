import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';

abstract class OverlayController {
  Stream<OverlayEvent> get events;

  Future<void> initialize();

  Future<void> showOverlay(OverlaySettings settings);

  Future<void> hideOverlay({
    OverlayDismissReason reason = OverlayDismissReason.hiddenByApp,
  });

  Future<void> updateSettings(OverlaySettings settings);

  Future<void> refreshDisplays();

  Future<OverlayStatus> getStatus();
}
