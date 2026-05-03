import AppKit
import Foundation

struct NativeDisplayTarget {
  let id: String
  let name: String
  let isPrimary: Bool
  let screen: NSScreen
}

final class OverlayFacade {
  init(displayService: DisplayService = DisplayService()) {
    self.displayService = displayService
    self.windowManager = OverlayWindowManager()
    self.coordinator = OverlayCoordinator(
      displayService: displayService,
      windowManager: windowManager
    )
  }

  private let displayService: DisplayService
  private let windowManager: OverlayWindowManager
  private let coordinator: OverlayCoordinator

  func initialize() {
    coordinator.hideOverlay()
  }

  func showOverlay(settings: OverlaySettingsDto) throws -> [NativeDisplayTarget] {
    try coordinator.showOverlay(settings: settings)
  }

  func hideOverlay() {
    coordinator.hideOverlay()
  }

  func refreshDisplays(rebuildVisibleWindows: Bool) throws -> [NativeDisplayTarget] {
    try coordinator.refreshDisplays(rebuildVisibleWindows: rebuildVisibleWindows)
  }

  func currentDisplays() -> [NativeDisplayTarget] {
    displayService.currentDisplays()
  }
}

final class OverlayCoordinator {
  init(
    displayService: DisplayService,
    windowManager: OverlayWindowManager
  ) {
    self.displayService = displayService
    self.windowManager = windowManager
  }

  private let displayService: DisplayService
  private let windowManager: OverlayWindowManager
  private var lastSettings: OverlaySettingsDto?
  private(set) var isVisible = false

  func showOverlay(settings: OverlaySettingsDto) throws -> [NativeDisplayTarget] {
    let displays = displayService.currentDisplays()
    guard !displays.isEmpty else {
      throw PigeonError(
        code: "no-displays",
        message: "No active displays were found for the overlay.",
        details: nil
      )
    }

    lastSettings = settings
    windowManager.showOverlay(on: displays, settings: settings)
    isVisible = true
    return displays
  }

  func hideOverlay() {
    windowManager.hideOverlay()
    isVisible = false
  }

  func refreshDisplays(rebuildVisibleWindows: Bool) throws -> [NativeDisplayTarget] {
    let displays = displayService.currentDisplays()

    if rebuildVisibleWindows, isVisible, let settings = lastSettings {
      windowManager.showOverlay(on: displays, settings: settings)
    }

    return displays
  }
}

final class OverlayWindowManager {
  private var windowsByDisplayId: [String: OverlayWindowController] = [:]

  func showOverlay(on displays: [NativeDisplayTarget], settings: OverlaySettingsDto) {
    let activeIds = Set(displays.map(\.id))

    for (displayId, controller) in windowsByDisplayId where !activeIds.contains(displayId) {
      controller.close()
      windowsByDisplayId.removeValue(forKey: displayId)
    }

    for display in displays {
      let controller = windowsByDisplayId[display.id] ?? OverlayWindowController(display: display)
      controller.update(display: display, settings: settings)
      controller.show()
      windowsByDisplayId[display.id] = controller
    }
  }

  func hideOverlay() {
    for controller in windowsByDisplayId.values {
      controller.hide()
    }
  }
}

final class OverlayWindowController {
  init(display: NativeDisplayTarget) {
    self.display = display

    let window = OverlayWindow(
      contentRect: display.screen.frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false,
      screen: display.screen
    )
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.level = .screenSaver
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    window.ignoresMouseEvents = true
    window.isReleasedWhenClosed = false

    let overlayView = OverlayVisualView(frame: display.screen.frame)
    window.contentView = overlayView

    self.window = window
    self.overlayView = overlayView
  }

  private var display: NativeDisplayTarget
  private let window: OverlayWindow
  private let overlayView: OverlayVisualView

  func update(display: NativeDisplayTarget, settings: OverlaySettingsDto) {
    self.display = display

    window.setFrame(display.screen.frame, display: true)
    window.setFrameOrigin(display.screen.frame.origin)
    window.collectionBehavior = collectionBehavior(for: settings.fullscreenMode)
    window.ignoresMouseEvents = settings.interactionMode == .passthrough
    window.orderFrontRegardless()

    overlayView.update(
      displayName: display.name,
      blocksInteraction: settings.interactionMode == .blocking
    )
  }

  func show() {
    window.orderFrontRegardless()
  }

  func hide() {
    window.orderOut(nil)
  }

  func close() {
    window.close()
  }

  private func collectionBehavior(for mode: FullscreenModeDto) -> NSWindow.CollectionBehavior {
    switch mode {
    case .disabled:
      return [.canJoinAllSpaces, .stationary]
    case .enabled:
      return [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    }
  }
}

final class DisplayService {
  func currentDisplays() -> [NativeDisplayTarget] {
    let screens = NSScreen.screens
    let primaryId = displayId(for: screens.first)

    return screens.enumerated().map { index, screen in
      let id = displayId(for: screen) ?? UUID().uuidString
      return NativeDisplayTarget(
        id: id,
        name: "Display \(index + 1)",
        isPrimary: id == primaryId,
        screen: screen
      )
    }
  }

  private func displayId(for screen: NSScreen?) -> String? {
    guard
      let screen,
      let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    else {
      return nil
    }

    return number.stringValue
  }
}

final class OverlayWindow: NSWindow {
  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    false
  }
}

final class OverlayVisualView: NSView {
  override init(frame frameRect: NSRect) {
    self.backdropView = NSVisualEffectView(frame: .zero)
    self.titleLabel = NSTextField(labelWithString: "")
    self.subtitleLabel = NSTextField(labelWithString: "")
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    return nil
  }

  private let backdropView: NSVisualEffectView
  private let titleLabel: NSTextField
  private let subtitleLabel: NSTextField

  func update(displayName: String, blocksInteraction: Bool) {
    titleLabel.stringValue = "Stop grinding"
    subtitleLabel.stringValue = blocksInteraction
      ? "\(displayName) is blocked for a break."
      : "\(displayName) is showing the break overlay."
  }

  private func configure() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor

    backdropView.translatesAutoresizingMaskIntoConstraints = false
    backdropView.material = .hudWindow
    backdropView.blendingMode = .withinWindow
    backdropView.state = .active
    backdropView.wantsLayer = true
    backdropView.layer?.cornerRadius = 28
    backdropView.layer?.masksToBounds = true

    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.font = .systemFont(ofSize: 34, weight: .semibold)
    titleLabel.textColor = .white
    titleLabel.alignment = .center

    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    subtitleLabel.font = .systemFont(ofSize: 17, weight: .medium)
    subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.82)
    subtitleLabel.alignment = .center

    addSubview(backdropView)
    addSubview(titleLabel)
    addSubview(subtitleLabel)

    NSLayoutConstraint.activate([
      backdropView.centerXAnchor.constraint(equalTo: centerXAnchor),
      backdropView.centerYAnchor.constraint(equalTo: centerYAnchor),
      backdropView.widthAnchor.constraint(equalToConstant: 440),
      backdropView.heightAnchor.constraint(equalToConstant: 220),

      titleLabel.leadingAnchor.constraint(equalTo: backdropView.leadingAnchor, constant: 24),
      titleLabel.trailingAnchor.constraint(equalTo: backdropView.trailingAnchor, constant: -24),
      titleLabel.topAnchor.constraint(equalTo: backdropView.topAnchor, constant: 64),

      subtitleLabel.leadingAnchor.constraint(equalTo: backdropView.leadingAnchor, constant: 24),
      subtitleLabel.trailingAnchor.constraint(equalTo: backdropView.trailingAnchor, constant: -24),
      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 18),
    ])
  }
}
