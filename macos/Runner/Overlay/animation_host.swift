import AVFoundation
import AppKit
import Foundation
import CoreMedia

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
    mediaView.gestureTargetView
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
  private enum PlaybackMode {
    case fullAsset
    case introThenLoop(loopRange: CMTimeRange)
    case loopOnly(loopRange: CMTimeRange)
  }

  override init(frame frameRect: NSRect) {
    placeholderLabel = NSTextField(labelWithString: "MISSING VIDEO")
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    return nil
  }

  private let placeholderLabel: NSTextField
  var gestureTargetView: NSView {
    playerContainerView
  }
  private var playerLayer: AVPlayerLayer?
  private var player: AVPlayer?
  private var boundaryObserver: Any?
  private var itemDidReachEndObserver: NSObjectProtocol?
  private var looper: AVPlayerLooper?
  private var sourceAssetURL: URL?
  private var playbackMode: PlaybackMode = .fullAsset
  private var hasAnimatedIn = false
  private let overlayPadding = NSEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)
  private let entranceAnimationDuration: TimeInterval = 0.32

  private lazy var playerContainerView: NSView = {
    let view = NSView(frame: .zero)
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.clear.cgColor
    return view
  }()

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

    sourceAssetURL = assetURL
    playbackMode = makePlaybackMode(for: item, assetURL: assetURL)
    configurePlayer(for: playbackMode, assetURL: assetURL)
    hasAnimatedIn = false
    placeholderLabel.isHidden = true
    AppLogger.debug(
      "OverlayMediaView",
      "Configured native AVFoundation playback from \(assetURL.path)."
    )
  }

  func startPlayback() {
    guard let player else {
      AppLogger.warning(
        "OverlayMediaView",
        "Playback was requested without a configured native video player."
      )
      return
    }

    runEntranceAnimationIfNeeded()
    player.seek(to: .zero)
    player.play()
  }

  func stopPlayback() {
    player?.pause()
    player?.seek(to: .zero)
    clearLoopObserver()
    clearEndObserver()
    hasAnimatedIn = false
  }

  private func configurePlayer(for mode: PlaybackMode, assetURL: URL) {
    clearLoopObserver()
    clearEndObserver()
    looper = nil
    if playerLayer == nil {
      let layer = AVPlayerLayer()
      layer.frame = playerContainerView.bounds
      layer.videoGravity = .resizeAspect
      layer.backgroundColor = NSColor.clear.cgColor
      playerContainerView.layer?.addSublayer(layer)
      playerLayer = layer
    }

    self.player?.pause()
    let nextPlayer: AVPlayer

    switch mode {
    case .fullAsset:
      let playerItem = AVPlayerItem(url: assetURL)
      let player = AVPlayer(playerItem: playerItem)
      player.actionAtItemEnd = .pause
      nextPlayer = player
    case .introThenLoop(let loopRange):
      let playerItem = AVPlayerItem(url: assetURL)
      playerItem.forwardPlaybackEndTime = loopRange.end
      let player = AVPlayer(playerItem: playerItem)
      player.actionAtItemEnd = .pause
      itemDidReachEndObserver = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: playerItem,
        queue: .main
      ) { [weak self] _ in
        self?.startLoopPlayback(loopRange: loopRange)
      }
      nextPlayer = player
    case .loopOnly(let loopRange):
      let loopPlayer = makeLoopingPlayer(assetURL: assetURL, loopRange: loopRange)
      nextPlayer = loopPlayer
    }

    nextPlayer.isMuted = true
    self.player = nextPlayer
    playerLayer?.player = nextPlayer
  }

  private func clearLoopObserver() {
    if let boundaryObserver, let player {
      player.removeTimeObserver(boundaryObserver)
    }
    boundaryObserver = nil
  }

  private func clearEndObserver() {
    if let itemDidReachEndObserver {
      NotificationCenter.default.removeObserver(itemDidReachEndObserver)
    }
    itemDidReachEndObserver = nil
  }

  private func showPlaceholder(_ title: String) {
    player?.pause()
    player = nil
    looper = nil
    sourceAssetURL = nil
    playbackMode = .fullAsset
    hasAnimatedIn = false
    clearLoopObserver()
    clearEndObserver()
    playerLayer?.player = nil
    placeholderLabel.stringValue = "MISSING VIDEO\n\(title.uppercased())"
    placeholderLabel.isHidden = false
  }

  private func makePlaybackMode(for item: OverlayMediaItem, assetURL: URL) -> PlaybackMode {
    let asset = AVAsset(url: assetURL)
    let duration = asset.duration
    let loopStart = CMTime(value: item.loopStartMillis, timescale: 1000)
    let configuredLoopEnd = item.loopEndMillis.map { CMTime(value: $0, timescale: 1000) }
    let loopEnd = configuredLoopEnd ?? duration

    guard
      CMTIME_IS_NUMERIC(duration),
      CMTIME_IS_NUMERIC(loopStart),
      CMTIME_IS_NUMERIC(loopEnd),
      CMTimeCompare(loopStart, .zero) >= 0,
      CMTimeCompare(loopEnd, loopStart) > 0,
      CMTimeCompare(loopEnd, duration) <= 0
    else {
      AppLogger.warning(
        "OverlayMediaView",
        "Loop settings for \(item.id) were invalid. Falling back to whole-file playback."
      )
      return .fullAsset
    }

    let loopRange = CMTimeRange(start: loopStart, end: loopEnd)
    AppLogger.info(
      "OverlayMediaView",
      "Configured loop segment for \(item.id): start=\(item.loopStartMillis)ms end=\(item.loopEndMillis ?? -1)ms."
    )

    if CMTimeCompare(loopStart, .zero) == 0 {
      return .loopOnly(loopRange: loopRange)
    }

    return .introThenLoop(loopRange: loopRange)
  }

  private func startLoopPlayback(loopRange: CMTimeRange) {
    guard let sourceAssetURL else {
      return
    }

    AppLogger.debug(
      "OverlayMediaView",
      "Switching to seamless looping segment at \(CMTimeGetSeconds(loopRange.start))s."
    )

    clearLoopObserver()
    clearEndObserver()
    let loopPlayer = makeLoopingPlayer(assetURL: sourceAssetURL, loopRange: loopRange)
    loopPlayer.play()
    player = loopPlayer
    playerLayer?.player = loopPlayer
  }

  private func makeLoopingPlayer(assetURL: URL, loopRange: CMTimeRange) -> AVQueuePlayer {
    let composition = AVMutableComposition()

    do {
      let asset = AVAsset(url: assetURL)

      if let videoTrack = asset.tracks(withMediaType: .video).first,
         let compositionVideoTrack = composition.addMutableTrack(
           withMediaType: .video,
           preferredTrackID: kCMPersistentTrackID_Invalid
         ) {
        try compositionVideoTrack.insertTimeRange(loopRange, of: videoTrack, at: .zero)
        compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
      }

      if let audioTrack = asset.tracks(withMediaType: .audio).first,
         let compositionAudioTrack = composition.addMutableTrack(
           withMediaType: .audio,
           preferredTrackID: kCMPersistentTrackID_Invalid
         ) {
        try compositionAudioTrack.insertTimeRange(loopRange, of: audioTrack, at: .zero)
      }
    } catch {
      AppLogger.error(
        "OverlayMediaView",
        "Failed to build loop composition for \(assetURL.lastPathComponent): \(error.localizedDescription)"
      )
    }

    let templateItem = AVPlayerItem(asset: composition)
    let queuePlayer = AVQueuePlayer()
    queuePlayer.actionAtItemEnd = .none
    looper = AVPlayerLooper(player: queuePlayer, templateItem: templateItem)
    return queuePlayer
  }

  private func runEntranceAnimationIfNeeded() {
    guard !hasAnimatedIn else {
      return
    }

    hasAnimatedIn = true
    let targetFrame = mediaFrame(in: bounds)
    let startFrame = targetFrame.offsetBy(dx: targetFrame.width + overlayPadding.right, dy: 0)

    playerContainerView.animator().alphaValue = 1
    playerContainerView.frame = startFrame
    NSAnimationContext.runAnimationGroup { context in
      context.duration = entranceAnimationDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      playerContainerView.animator().frame = targetFrame
    }
  }

  private func mediaFrame(in bounds: NSRect) -> NSRect {
    let insetBounds = NSRect(
      x: bounds.minX + overlayPadding.left,
      y: bounds.minY + overlayPadding.bottom,
      width: max(0, bounds.width - overlayPadding.left - overlayPadding.right),
      height: max(0, bounds.height - overlayPadding.top - overlayPadding.bottom)
    )
    if insetBounds.isEmpty {
      return bounds
    }

    let widthScale = insetBounds.width / 1920
    let heightScale = insetBounds.height / 1080
    let scale = min(widthScale, heightScale)
    let fittedSize = NSSize(width: 1920 * scale, height: 1080 * scale)

    return NSRect(
      x: bounds.maxX - overlayPadding.right - fittedSize.width,
      y: bounds.minY + overlayPadding.bottom,
      width: fittedSize.width,
      height: fittedSize.height
    )
  }

  private func configure() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor

    addSubview(playerContainerView)

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

  override func layout() {
    super.layout()
    let frame = mediaFrame(in: bounds)
    if hasAnimatedIn {
      playerContainerView.frame = frame
    } else {
      playerContainerView.frame = frame.offsetBy(
        dx: frame.width + overlayPadding.right,
        dy: 0
      )
    }
    playerLayer?.frame = playerContainerView.bounds
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
