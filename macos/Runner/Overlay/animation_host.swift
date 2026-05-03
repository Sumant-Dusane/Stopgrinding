import AppKit
import Foundation

protocol AnimationHost {
  var gestureTargetView: NSView { get }

  func attach(to containerView: NSView)
  func updateLayout(in bounds: NSRect)
  func play(duration: TimeInterval)
  func stop()
}

final class NativeCatAnimationHost: AnimationHost {
  init() {
    catView = CatSpriteView(frame: NSRect(x: 0, y: 0, width: 104, height: 92))
  }

  var gestureTargetView: NSView {
    catView
  }

  private let catView: CatSpriteView
  private weak var containerView: NSView?
  private var currentBounds: NSRect = .zero
  private var currentPhase: AnimationPhase = .hidden
  private var pendingExitWorkItem: DispatchWorkItem?

  func attach(to containerView: NSView) {
    self.containerView = containerView
    catView.isHidden = true
    containerView.addSubview(catView)
    updateLayout(in: containerView.bounds)
  }

  func updateLayout(in bounds: NSRect) {
    currentBounds = bounds
    catView.frame = frame(for: currentPhase, in: bounds)
  }

  func play(duration: TimeInterval) {
    guard containerView != nil else {
      return
    }

    stop()

    let totalDuration = max(duration, 1.2)
    let entranceDuration = min(max(totalDuration * 0.22, 0.35), 1.1)
    let exitDuration = min(max(totalDuration * 0.22, 0.35), 1.1)
    let idleDuration = max(totalDuration - entranceDuration - exitDuration, 0.25)

    currentPhase = .entering
    catView.alphaValue = 1
    catView.isHidden = false
    catView.frame = frame(for: .entering, in: currentBounds)
    catView.setFacingRight(true)
    catView.startIdleAccent()

    animate(
      to: frame(for: .idle, in: currentBounds),
      duration: entranceDuration
    ) { [weak self] in
      guard let self else {
        return
      }

      self.currentPhase = .idle
      self.scheduleExit(after: idleDuration, duration: exitDuration)
    }
  }

  func stop() {
    pendingExitWorkItem?.cancel()
    pendingExitWorkItem = nil
    currentPhase = .hidden
    catView.layer?.removeAllAnimations()
    catView.stopIdleAccent()
    catView.isHidden = true
  }

  private func scheduleExit(after delay: TimeInterval, duration: TimeInterval) {
    let workItem = DispatchWorkItem { [weak self] in
      guard let self else {
        return
      }

      self.currentPhase = .exiting
      self.catView.setFacingRight(false)
      self.animate(
        to: self.frame(for: .exiting, in: self.currentBounds),
        duration: duration
      ) { [weak self] in
        guard let self else {
          return
        }

        self.currentPhase = .hidden
        self.catView.stopIdleAccent()
        self.catView.isHidden = true
      }
    }

    pendingExitWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  private func animate(
    to frame: NSRect,
    duration: TimeInterval,
    completion: @escaping () -> Void
  ) {
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = duration
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      catView.animator().frame = frame
    }, completionHandler: completion)
  }

  private func frame(for phase: AnimationPhase, in bounds: NSRect) -> NSRect {
    let size = catView.frame.size
    let baselineY = bounds.midY - 10
    let centerY = baselineY - (size.height / 2)

    switch phase {
    case .hidden, .entering:
      return NSRect(x: bounds.minX - size.width - 36, y: centerY, width: size.width, height: size.height)
    case .idle:
      return NSRect(x: bounds.midX - (size.width / 2), y: centerY, width: size.width, height: size.height)
    case .exiting:
      return NSRect(x: bounds.maxX + 36, y: centerY, width: size.width, height: size.height)
    }
  }
}

private enum AnimationPhase {
  case hidden
  case entering
  case idle
  case exiting
}

private final class CatSpriteView: NSView {
  override init(frame frameRect: NSRect) {
    self.catLabel = NSTextField(labelWithString: "🐈")
    self.shadowLabel = NSTextField(labelWithString: "")
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    return nil
  }

  private let catLabel: NSTextField
  private let shadowLabel: NSTextField

  func setFacingRight(_ facingRight: Bool) {
    let direction: CGFloat = facingRight ? 1 : -1
    layer?.setAffineTransform(CGAffineTransform(scaleX: direction, y: 1))
  }

  func startIdleAccent() {
    guard let layer else {
      return
    }

    let bobAnimation = CABasicAnimation(keyPath: "transform.translation.y")
    bobAnimation.fromValue = -3
    bobAnimation.toValue = 3
    bobAnimation.duration = 0.45
    bobAnimation.autoreverses = true
    bobAnimation.repeatCount = .infinity
    bobAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    layer.add(bobAnimation, forKey: "idle-bob")
  }

  func stopIdleAccent() {
    layer?.removeAnimation(forKey: "idle-bob")
  }

  private func configure() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor

    shadowLabel.translatesAutoresizingMaskIntoConstraints = false
    shadowLabel.stringValue = " "
    shadowLabel.wantsLayer = true
    shadowLabel.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
    shadowLabel.layer?.cornerRadius = 16

    catLabel.translatesAutoresizingMaskIntoConstraints = false
    catLabel.font = .systemFont(ofSize: 64)
    catLabel.alignment = .center

    addSubview(shadowLabel)
    addSubview(catLabel)

    NSLayoutConstraint.activate([
      shadowLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
      shadowLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
      shadowLabel.widthAnchor.constraint(equalToConstant: 58),
      shadowLabel.heightAnchor.constraint(equalToConstant: 14),

      catLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
      catLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -2),
    ])
  }
}
