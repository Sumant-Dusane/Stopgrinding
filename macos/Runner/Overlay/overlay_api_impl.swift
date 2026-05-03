import Cocoa
import Foundation
import FlutterMacOS

final class OverlayApiImpl: OverlayHostApi {
  init(binaryMessenger: FlutterBinaryMessenger) {
    events = OverlayEvents(binaryMessenger: binaryMessenger)
  }

  private let events: OverlayEvents
  private var settings = OverlaySettingsDto(
    intervalMillis: 3_600_000,
    durationMillis: 120_000,
    interactionMode: .passthrough,
    fullscreenMode: .disabled,
    monitorScope: .allDisplays,
    dismissPolicyType: .timedOnly,
    allowEarlyDismiss: false
  )
  private var state: OverlayStateDto = .idle
  private var activeSession: OverlaySessionDto?

  func initialize() throws {
    state = .idle
  }

  func showOverlay(request: OverlayRequestDto) throws {
    settings = request.settings
    let session = OverlaySessionDto(
      id: request.requestId,
      startedAtEpochMillis: Self.nowMillis(),
      displays: currentDisplays()
    )
    activeSession = session
    state = .visible
    events.publishShown(session: session)
  }

  func hideOverlay(request: HideOverlayRequestDto) throws {
    guard let session = activeSession else {
      state = .idle
      return
    }

    state = .dismissed
    activeSession = nil
    events.publishDismissed(
      event: OverlayDismissedDto(
        sessionId: session.id,
        reason: request.reason,
        dismissedAtEpochMillis: Self.nowMillis()
      )
    )
  }

  func updateSettings(settings: OverlaySettingsDto) throws {
    self.settings = settings
  }

  func refreshDisplays() throws {
    events.publishDisplayTopologyChanged(displays: currentDisplays())
  }

  func getOverlayStatus() throws -> OverlayStatusDto {
    OverlayStatusDto(
      state: state,
      activeSession: activeSession,
      nextTriggerAtEpochMillis: nil
    )
  }

  private func currentDisplays() -> [DisplayTargetDto] {
    let screens = NSScreen.screens
    let primaryId = screens.first?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber

    return screens.enumerated().map { index, screen in
      let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
      let id = number?.stringValue ?? UUID().uuidString
      let isPrimary = number == primaryId
      let name = "Display \(index + 1)"

      return DisplayTargetDto(
        id: id,
        name: name,
        isPrimary: isPrimary
      )
    }
  }

  private static func nowMillis() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
  }
}
