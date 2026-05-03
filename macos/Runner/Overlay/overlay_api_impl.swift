import Cocoa
import Foundation
import FlutterMacOS

final class OverlayApiImpl: OverlayHostApi {
  init(binaryMessenger: FlutterBinaryMessenger) {
    events = OverlayEvents(binaryMessenger: binaryMessenger)
    overlayFacade = OverlayFacade()
    screenChangeObserver = nil
    screenChangeObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.handleDisplayTopologyChange()
    }
  }

  private let events: OverlayEvents
  private let overlayFacade: OverlayFacade
  private var screenChangeObserver: NSObjectProtocol?
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

  deinit {
    if let screenChangeObserver {
      NotificationCenter.default.removeObserver(screenChangeObserver)
    }
  }

  func initialize() throws {
    overlayFacade.initialize()
    state = .idle
  }

  func showOverlay(request: OverlayRequestDto) throws {
    settings = request.settings
    if let existingSession = activeSession {
      overlayFacade.hideOverlay()
      events.publishDismissed(
        event: OverlayDismissedDto(
          sessionId: existingSession.id,
          reason: .replaced,
          dismissedAtEpochMillis: Self.nowMillis()
        )
      )
      activeSession = nil
    }

    state = .preparing
    let displays = try overlayFacade.showOverlay(settings: request.settings)
    let session = OverlaySessionDto(
      id: request.requestId,
      startedAtEpochMillis: Self.nowMillis(),
      displays: displays.map(Self.mapDisplay)
    )
    activeSession = session
    state = .visible
    events.publishShown(session: session)
  }

  func hideOverlay(request: HideOverlayRequestDto) throws {
    overlayFacade.hideOverlay()

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
    let displays = try overlayFacade.refreshDisplays(
      rebuildVisibleWindows: activeSession != nil
    )
    events.publishDisplayTopologyChanged(displays: displays.map(Self.mapDisplay))
  }

  func getOverlayStatus() throws -> OverlayStatusDto {
    OverlayStatusDto(
      state: state,
      activeSession: activeSession,
      nextTriggerAtEpochMillis: nil
    )
  }

  private func handleDisplayTopologyChange() {
    do {
      let displays = try overlayFacade.refreshDisplays(
        rebuildVisibleWindows: activeSession != nil
      )
      if let session = activeSession {
        activeSession = OverlaySessionDto(
          id: session.id,
          startedAtEpochMillis: session.startedAtEpochMillis,
          displays: displays.map(Self.mapDisplay)
        )
      }
      events.publishDisplayTopologyChanged(displays: displays.map(Self.mapDisplay))
    } catch {
      events.publishFailed(
        code: "display-refresh-failed",
        message: error.localizedDescription
      )
    }
  }

  private static func mapDisplay(_ display: NativeDisplayTarget) -> DisplayTargetDto {
    DisplayTargetDto(
      id: display.id,
      name: display.name,
      isPrimary: display.isPrimary
    )
  }

  private static func nowMillis() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
  }
}
