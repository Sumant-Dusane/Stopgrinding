import Cocoa
import Foundation
import FlutterMacOS

enum AssetLocator {
  static func url(forFlutterAsset assetPath: String) -> URL? {
    if let frameworksURL = Bundle.main.privateFrameworksURL {
      let frameworkAssetURL = frameworksURL
        .appendingPathComponent("App.framework")
        .appendingPathComponent("Resources")
        .appendingPathComponent("flutter_assets")
        .appendingPathComponent(assetPath)
      if FileManager.default.fileExists(atPath: frameworkAssetURL.path) {
        AppLogger.debug("AssetLocator", "Resolved Flutter asset at \(frameworkAssetURL.path)")
        return frameworkAssetURL
      }
    }

    if let resourcesURL = Bundle.main.resourceURL {
      let resourcesAssetURL = resourcesURL
        .appendingPathComponent("flutter_assets")
        .appendingPathComponent(assetPath)
      if FileManager.default.fileExists(atPath: resourcesAssetURL.path) {
        AppLogger.debug("AssetLocator", "Resolved Flutter asset at \(resourcesAssetURL.path)")
        return resourcesAssetURL
      }
    }

    AppLogger.error("AssetLocator", "Missing Flutter asset at path \(assetPath)")
    return nil
  }
}

final class OverlayApiImpl: OverlayHostApi {
  init(binaryMessenger: FlutterBinaryMessenger) {
    AppLogger.info("OverlayApiImpl", "Creating OverlayApiImpl.")
    events = OverlayEvents(binaryMessenger: binaryMessenger)
    overlayFacade = OverlayFacade()
    overlayFacade.onDismiss = { [weak self] reason in
      self?.handleNativeDismiss(reason: reason)
    }
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
    allowEarlyDismiss: false,
    selectedOverlayId: "",
    selectedOverlayAssetPath: ""
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
    AppLogger.info(
      "OverlayApiImpl",
      "Showing overlay for media id \(request.settings.selectedOverlayId) at asset path \(request.settings.selectedOverlayAssetPath)."
    )
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
    AppLogger.info(
      "OverlayApiImpl",
      "Native overlay show call returned \(displays.count) display targets."
    )
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
    AppLogger.info("OverlayApiImpl", "Hide overlay requested with reason \(request.reason).")
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
    AppLogger.info(
      "OverlayApiImpl",
      "Updating overlay settings for media id \(settings.selectedOverlayId) at asset path \(settings.selectedOverlayAssetPath)."
    )
    self.settings = settings
    overlayFacade.updateSettings(settings)
  }

  func refreshDisplays() throws {
    AppLogger.debug("OverlayApiImpl", "Refreshing displays.")
    let displays = try overlayFacade.refreshDisplays(
      rebuildVisibleWindows: activeSession != nil
    )
    events.publishDisplayTopologyChanged(displays: displays.map(Self.mapDisplay))
  }

  static func selectedOverlayItem(for settings: OverlaySettingsDto) -> OverlayMediaItem {
    let fallbackTitle = URL(fileURLWithPath: settings.selectedOverlayAssetPath)
      .deletingPathExtension()
      .lastPathComponent
    let title = fallbackTitle.isEmpty ? "Selected Video" : fallbackTitle

    return OverlayMediaItem(
      id: settings.selectedOverlayId.isEmpty ? "selected-video" : settings.selectedOverlayId,
      title: title,
      assetPath: settings.selectedOverlayAssetPath
    )
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
      AppLogger.info("OverlayApiImpl", "Display topology change detected.")
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

  private func handleNativeDismiss(reason: OverlayDismissReasonDto) {
    AppLogger.info("OverlayApiImpl", "Native dismiss received with reason \(reason).")
    guard let session = activeSession else {
      state = .idle
      return
    }

    state = .dismissed
    activeSession = nil
    events.publishDismissed(
      event: OverlayDismissedDto(
        sessionId: session.id,
        reason: reason,
        dismissedAtEpochMillis: Self.nowMillis()
      )
    )
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

struct OverlayMediaItem {
  let id: String
  let title: String
  let assetPath: String
}
