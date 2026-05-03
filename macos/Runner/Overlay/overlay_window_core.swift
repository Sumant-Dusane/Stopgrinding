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
    self.behaviorFactory = OverlayBehaviorFactory()
    self.dismissHandler = DismissHandler()
    self.coordinator = OverlayCoordinator(
      displayService: displayService,
      windowManager: windowManager,
      behaviorFactory: behaviorFactory,
      dismissHandler: dismissHandler
    )
  }

  var onDismiss: ((OverlayDismissReasonDto) -> Void)? {
    get { coordinator.onDismiss }
    set { coordinator.onDismiss = newValue }
  }

  private let displayService: DisplayService
  private let windowManager: OverlayWindowManager
  private let behaviorFactory: OverlayBehaviorFactory
  private let dismissHandler: DismissHandler
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

  func updateSettings(_ settings: OverlaySettingsDto) {
    coordinator.updateSettings(settings)
  }

  func refreshDisplays(rebuildVisibleWindows: Bool) throws -> [NativeDisplayTarget] {
    try coordinator.refreshDisplays(rebuildVisibleWindows: rebuildVisibleWindows)
  }
}

final class OverlayCoordinator {
  init(
    displayService: DisplayService,
    windowManager: OverlayWindowManager,
    behaviorFactory: OverlayBehaviorFactory,
    dismissHandler: DismissHandler
  ) {
    self.displayService = displayService
    self.windowManager = windowManager
    self.behaviorFactory = behaviorFactory
    self.dismissHandler = dismissHandler

    dismissHandler.onDismissRequested = { [weak self] reason in
      self?.handleDismissRequested(reason: reason)
    }
  }

  var onDismiss: ((OverlayDismissReasonDto) -> Void)?

  private let displayService: DisplayService
  private let windowManager: OverlayWindowManager
  private let behaviorFactory: OverlayBehaviorFactory
  private let dismissHandler: DismissHandler
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

    let behaviors = behaviorFactory.makeBehaviors(for: settings)
    lastSettings = settings
    windowManager.showOverlay(
      on: displays,
      settings: settings,
      interactionStrategy: behaviors.interactionStrategy,
      fullscreenStrategy: behaviors.fullscreenStrategy,
      dismissTarget: behaviors.dismissStrategy.gestureTarget
    )
    dismissHandler.configure(
      controllers: windowManager.activeControllers,
      dismissStrategy: behaviors.dismissStrategy
    )
    isVisible = true
    return displays
  }

  func hideOverlay() {
    dismissHandler.cancel()
    windowManager.hideOverlay()
    isVisible = false
  }

  func updateSettings(_ settings: OverlaySettingsDto) {
    lastSettings = settings
    guard isVisible else {
      return
    }

    let behaviors = behaviorFactory.makeBehaviors(for: settings)
    windowManager.updateVisibleOverlay(
      settings: settings,
      interactionStrategy: behaviors.interactionStrategy,
      fullscreenStrategy: behaviors.fullscreenStrategy,
      dismissTarget: behaviors.dismissStrategy.gestureTarget
    )
    dismissHandler.configure(
      controllers: windowManager.activeControllers,
      dismissStrategy: behaviors.dismissStrategy
    )
  }

  func refreshDisplays(rebuildVisibleWindows: Bool) throws -> [NativeDisplayTarget] {
    let displays = displayService.currentDisplays()

    if rebuildVisibleWindows, isVisible, let settings = lastSettings {
      let behaviors = behaviorFactory.makeBehaviors(for: settings)
      windowManager.showOverlay(
        on: displays,
        settings: settings,
        interactionStrategy: behaviors.interactionStrategy,
        fullscreenStrategy: behaviors.fullscreenStrategy,
        dismissTarget: behaviors.dismissStrategy.gestureTarget
      )
      dismissHandler.configure(
        controllers: windowManager.activeControllers,
        dismissStrategy: behaviors.dismissStrategy
      )
    }

    return displays
  }

  private func handleDismissRequested(reason: OverlayDismissReasonDto) {
    guard isVisible else {
      return
    }

    hideOverlay()
    onDismiss?(reason)
  }
}

struct OverlayBehaviors {
  let interactionStrategy: InteractionStrategy
  let fullscreenStrategy: FullscreenStrategy
  let dismissStrategy: DismissStrategy
}

final class OverlayBehaviorFactory {
  func makeBehaviors(for settings: OverlaySettingsDto) -> OverlayBehaviors {
    OverlayBehaviors(
      interactionStrategy: interactionStrategy(for: settings.interactionMode),
      fullscreenStrategy: fullscreenStrategy(for: settings.fullscreenMode),
      dismissStrategy: dismissStrategy(for: settings)
    )
  }

  private func interactionStrategy(for mode: InteractionModeDto) -> InteractionStrategy {
    switch mode {
    case .blocking:
      return BlockingInteractionStrategy()
    case .passthrough:
      return PassthroughInteractionStrategy()
    }
  }

  private func fullscreenStrategy(for mode: FullscreenModeDto) -> FullscreenStrategy {
    switch mode {
    case .disabled:
      return StandardFullscreenStrategy()
    case .enabled:
      return AboveFullscreenStrategy()
    }
  }

  private func dismissStrategy(for settings: OverlaySettingsDto) -> DismissStrategy {
    DismissStrategy(settings: settings)
  }
}

protocol InteractionStrategy {
  func apply(to window: OverlayWindow)
}

struct BlockingInteractionStrategy: InteractionStrategy {
  func apply(to window: OverlayWindow) {
    window.ignoresMouseEvents = false
  }
}

struct PassthroughInteractionStrategy: InteractionStrategy {
  func apply(to window: OverlayWindow) {
    window.ignoresMouseEvents = true
  }
}

protocol FullscreenStrategy {
  var collectionBehavior: NSWindow.CollectionBehavior { get }
}

struct StandardFullscreenStrategy: FullscreenStrategy {
  let collectionBehavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary]
}

struct AboveFullscreenStrategy: FullscreenStrategy {
  let collectionBehavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
}

enum DismissGestureTarget {
  case none
  case anywhere
  case overlayCard
}

struct DismissStrategy {
  init(settings: OverlaySettingsDto) {
    timeoutInterval = TimeInterval(settings.durationMillis) / 1000

    guard
      settings.allowEarlyDismiss,
      settings.interactionMode == .blocking
    else {
      gestureTarget = .none
      return
    }

    switch settings.dismissPolicyType {
    case .timedOnly:
      gestureTarget = .none
    case .doubleClickAnywhere:
      gestureTarget = .anywhere
    case .doubleClickCat:
      gestureTarget = .overlayCard
    }
  }

  let timeoutInterval: TimeInterval
  let gestureTarget: DismissGestureTarget
}

final class DismissHandler {
  var onDismissRequested: ((OverlayDismissReasonDto) -> Void)?

  private var dismissTimer: Timer?
  private var isArmed = false

  func configure(
    controllers: [OverlayWindowController],
    dismissStrategy: DismissStrategy
  ) {
    cancel()
    isArmed = true

    for controller in controllers {
      controller.configureDismissTarget(dismissStrategy.gestureTarget) { [weak self] in
        self?.requestDismiss(reason: .userGesture)
      }
    }

    dismissTimer = Timer.scheduledTimer(
      withTimeInterval: dismissStrategy.timeoutInterval,
      repeats: false
    ) { [weak self] _ in
      self?.requestDismiss(reason: .timeout)
    }
  }

  func cancel() {
    dismissTimer?.invalidate()
    dismissTimer = nil
    isArmed = false
  }

  private func requestDismiss(reason: OverlayDismissReasonDto) {
    guard isArmed else {
      return
    }

    isArmed = false
    dismissTimer?.invalidate()
    dismissTimer = nil
    onDismissRequested?(reason)
  }
}

final class OverlayWindowManager {
  private var windowsByDisplayId: [String: OverlayWindowController] = [:]

  var activeControllers: [OverlayWindowController] {
    Array(windowsByDisplayId.values)
  }

  func showOverlay(
    on displays: [NativeDisplayTarget],
    settings: OverlaySettingsDto,
    interactionStrategy: InteractionStrategy,
    fullscreenStrategy: FullscreenStrategy,
    dismissTarget: DismissGestureTarget
  ) {
    let activeIds = Set(displays.map(\.id))

    for (displayId, controller) in windowsByDisplayId where !activeIds.contains(displayId) {
      controller.close()
      windowsByDisplayId.removeValue(forKey: displayId)
    }

    for display in displays {
      let controller = windowsByDisplayId[display.id] ?? OverlayWindowController(display: display)
      controller.update(
        display: display,
        settings: settings,
        interactionStrategy: interactionStrategy,
        fullscreenStrategy: fullscreenStrategy,
        dismissTarget: dismissTarget
      )
      controller.show()
      windowsByDisplayId[display.id] = controller
    }
  }

  func updateVisibleOverlay(
    settings: OverlaySettingsDto,
    interactionStrategy: InteractionStrategy,
    fullscreenStrategy: FullscreenStrategy,
    dismissTarget: DismissGestureTarget
  ) {
    for controller in windowsByDisplayId.values {
      controller.update(
        display: controller.display,
        settings: settings,
        interactionStrategy: interactionStrategy,
        fullscreenStrategy: fullscreenStrategy,
        dismissTarget: dismissTarget
      )
    }
  }

  func hideOverlay() {
    for controller in windowsByDisplayId.values {
      controller.configureDismissTarget(.none, onDismissGesture: nil)
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

  private(set) var display: NativeDisplayTarget
  private let window: OverlayWindow
  private let overlayView: OverlayVisualView

  func update(
    display: NativeDisplayTarget,
    settings: OverlaySettingsDto,
    interactionStrategy: InteractionStrategy,
    fullscreenStrategy: FullscreenStrategy,
    dismissTarget: DismissGestureTarget
  ) {
    self.display = display

    window.setFrame(display.screen.frame, display: true)
    window.setFrameOrigin(display.screen.frame.origin)
    window.collectionBehavior = fullscreenStrategy.collectionBehavior
    interactionStrategy.apply(to: window)
    window.orderFrontRegardless()

    overlayView.update(
      displayName: display.name,
      blocksInteraction: settings.interactionMode == .blocking,
      dismissTarget: dismissTarget,
      allowEarlyDismiss: settings.allowEarlyDismiss
    )
  }

  func configureDismissTarget(
    _ dismissTarget: DismissGestureTarget,
    onDismissGesture: (() -> Void)?
  ) {
    overlayView.configureDismissGesture(
      dismissTarget: dismissTarget,
      onDismissGesture: onDismissGesture
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
  private var rootDoubleClickGestureRecognizer: NSClickGestureRecognizer?
  private var cardDoubleClickGestureRecognizer: NSClickGestureRecognizer?
  private var onDismissGesture: (() -> Void)?

  func update(
    displayName: String,
    blocksInteraction: Bool,
    dismissTarget: DismissGestureTarget,
    allowEarlyDismiss: Bool
  ) {
    titleLabel.stringValue = "Stop grinding"

    let interactionDescription = blocksInteraction
      ? "\(displayName) is blocked for a break."
      : "\(displayName) is showing the break overlay."
    let dismissDescription = dismissHint(
      dismissTarget: dismissTarget,
      allowEarlyDismiss: allowEarlyDismiss
    )
    subtitleLabel.stringValue = "\(interactionDescription) \(dismissDescription)"
  }

  func configureDismissGesture(
    dismissTarget: DismissGestureTarget,
    onDismissGesture: (() -> Void)?
  ) {
    self.onDismissGesture = onDismissGesture
    clearDismissGestures()

    switch dismissTarget {
    case .none:
      return
    case .anywhere:
      rootDoubleClickGestureRecognizer = installDoubleClickGesture(on: self)
    case .overlayCard:
      cardDoubleClickGestureRecognizer = installDoubleClickGesture(on: backdropView)
    }
  }

  @objc
  private func handleDoubleClickGesture(_ recognizer: NSClickGestureRecognizer) {
    guard recognizer.state == .ended else {
      return
    }

    onDismissGesture?()
  }

  private func clearDismissGestures() {
    if let rootDoubleClickGestureRecognizer {
      removeGestureRecognizer(rootDoubleClickGestureRecognizer)
      self.rootDoubleClickGestureRecognizer = nil
    }

    if let cardDoubleClickGestureRecognizer {
      backdropView.removeGestureRecognizer(cardDoubleClickGestureRecognizer)
      self.cardDoubleClickGestureRecognizer = nil
    }
  }

  private func installDoubleClickGesture(on view: NSView) -> NSClickGestureRecognizer {
    let recognizer = NSClickGestureRecognizer(
      target: self,
      action: #selector(handleDoubleClickGesture(_:))
    )
    recognizer.numberOfClicksRequired = 2
    view.addGestureRecognizer(recognizer)
    return recognizer
  }

  private func dismissHint(
    dismissTarget: DismissGestureTarget,
    allowEarlyDismiss: Bool
  ) -> String {
    guard allowEarlyDismiss else {
      return "Wait for the timer to finish."
    }

    switch dismissTarget {
    case .none:
      return "Wait for the timer to finish."
    case .anywhere:
      return "Double-click anywhere to dismiss early."
    case .overlayCard:
      return "Double-click the break card to dismiss early."
    }
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
    subtitleLabel.maximumNumberOfLines = 0
    subtitleLabel.lineBreakMode = .byWordWrapping

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
