import AVFoundation
import AppKit
import Foundation

protocol AnimationHost {
  var gestureTargetView: NSView { get }

  func attach(to containerView: NSView)
  func updateLayout(in bounds: NSRect)
  func updateOverlayMedia(_ item: OverlayMediaItem)
  func play(duration: TimeInterval)
  func stop()
}

final class NativeOverlayMediaHost: AnimationHost {
  init() {
    mediaView = OverlayMediaView(frame: .zero)
  }

  var gestureTargetView: NSView {
    mediaView
  }

  private let mediaView: OverlayMediaView
  private weak var containerView: NSView?

  func attach(to containerView: NSView) {
    self.containerView = containerView
    mediaView.isHidden = true
    containerView.addSubview(mediaView)
    updateLayout(in: containerView.bounds)
  }

  func updateLayout(in bounds: NSRect) {
    mediaView.frame = bounds
  }

  func updateOverlayMedia(_ item: OverlayMediaItem) {
    mediaView.updateOverlayMedia(item)
  }

  func play(duration: TimeInterval) {
    guard containerView != nil else {
      return
    }

    AppLogger.debug(
      "NativeOverlayMediaHost",
      "Starting native video overlay playback for up to \(duration)s."
    )
    mediaView.alphaValue = 1
    mediaView.isHidden = false
    mediaView.startPlayback()
  }

  func stop() {
    AppLogger.debug("NativeOverlayMediaHost", "Stopping native video overlay playback.")
    mediaView.stopPlayback()
    mediaView.isHidden = true
  }
}

private final class OverlayMediaView: NSView {
  override init(frame frameRect: NSRect) {
    placeholderLabel = NSTextField(labelWithString: "MISSING VIDEO")
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override func layout() {
    super.layout()
    playerLayer?.frame = bounds
  }

  private let placeholderLabel: NSTextField
  private var playerLayer: AVPlayerLayer?
  private var queuePlayer: AVQueuePlayer?
  private var playerLooper: AVPlayerLooper?

  func updateOverlayMedia(_ item: OverlayMediaItem) {
    AppLogger.info(
      "OverlayMediaView",
      "Rendering video media \(item.id) from \(item.assetPath)."
    )

    guard VideoAssetFormat.isSupported(assetPath: item.assetPath) else {
      AppLogger.warning(
        "OverlayMediaView",
        "Unsupported video extension for \(item.assetPath)."
      )
      showPlaceholder(item.title)
      return
    }

    guard let assetURL = AssetLocator.url(forFlutterAsset: item.assetPath) else {
      AppLogger.error(
        "OverlayMediaView",
        "Video asset could not be resolved for \(item.id) at \(item.assetPath)."
      )
      showPlaceholder(item.title)
      return
    }

    configurePlayer(with: assetURL)
    placeholderLabel.isHidden = true
    AppLogger.debug(
      "OverlayMediaView",
      "Configured native AVFoundation playback from \(assetURL.path)."
    )
  }

  func startPlayback() {
    guard let queuePlayer else {
      AppLogger.warning(
        "OverlayMediaView",
        "Playback was requested without a configured native video player."
      )
      return
    }

    queuePlayer.seek(to: .zero)
    queuePlayer.play()
  }

  func stopPlayback() {
    queuePlayer?.pause()
    queuePlayer?.seek(to: .zero)
  }

  private func configurePlayer(with assetURL: URL) {
    let playerItem = AVPlayerItem(url: assetURL)
    let queuePlayer = AVQueuePlayer()
    queuePlayer.isMuted = true
    queuePlayer.actionAtItemEnd = .none
    let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

    if playerLayer == nil {
      let layer = AVPlayerLayer()
      layer.frame = bounds
      layer.videoGravity = .resizeAspectFill
      self.layer?.addSublayer(layer)
      playerLayer = layer
    }

    self.queuePlayer?.pause()
    self.queuePlayer = queuePlayer
    playerLooper = looper
    playerLayer?.player = queuePlayer
  }

  private func showPlaceholder(_ title: String) {
    queuePlayer?.pause()
    queuePlayer = nil
    playerLooper = nil
    playerLayer?.player = nil
    placeholderLabel.stringValue = "MISSING VIDEO\n\(title.uppercased())"
    placeholderLabel.isHidden = false
  }

  private func configure() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor

    placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
    placeholderLabel.font = .systemFont(ofSize: 22, weight: .black)
    placeholderLabel.textColor = .white
    placeholderLabel.alignment = .center
    placeholderLabel.maximumNumberOfLines = 2
    placeholderLabel.lineBreakMode = .byWordWrapping

    addSubview(placeholderLabel)

    NSLayoutConstraint.activate([
      placeholderLabel.leadingAnchor.constraint(
        greaterThanOrEqualTo: leadingAnchor,
        constant: 24
      ),
      placeholderLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: trailingAnchor,
        constant: -24
      ),
      placeholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
      placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }
}

enum VideoAssetFormat {
  static func isSupported(assetPath: String) -> Bool {
    switch URL(fileURLWithPath: assetPath).pathExtension.lowercased() {
    case "mov", "mp4", "m4v":
      return true
    default:
      return false
    }
  }
}
