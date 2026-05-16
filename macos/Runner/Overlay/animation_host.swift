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
    mediaView.startPlayback(duration: duration)
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
    hasAnimatedIn = false
    placeholderLabel.isHidden = true
    AppLogger.debug(
      "OverlayMediaView",
      "Configured native AVFoundation playback from \(assetURL.path)."
    )
  }

  func startPlayback(duration: TimeInterval) {
    guard let sourceAssetURL else {
      AppLogger.warning(
        "OverlayMediaView",
        "Playback was requested without a configured native video player."
      )
      return
    }

    configurePlayer(
      for: playbackMode,
      assetURL: sourceAssetURL,
      playbackDuration: duration
    )
    guard let player else {
      return
    }

    runEntranceAnimationIfNeeded()
    player.seek(to: .zero)
    player.play()
  }

  func stopPlayback() {
    player?.pause()
    player?.seek(to: .zero)
    hasAnimatedIn = false
  }

  private func configurePlayer(
    for mode: PlaybackMode,
    assetURL: URL,
    playbackDuration: TimeInterval
  ) {
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
      let asset = makeTimedPlaybackComposition(
        assetURL: assetURL,
        playbackDuration: playbackDuration,
        loopRange: loopRange,
        includeIntro: true
      )
      let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
      player.actionAtItemEnd = .pause
      nextPlayer = player
    case .loopOnly(let loopRange):
      let asset = makeTimedPlaybackComposition(
        assetURL: assetURL,
        playbackDuration: playbackDuration,
        loopRange: loopRange,
        includeIntro: false
      )
      let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
      player.actionAtItemEnd = .pause
      nextPlayer = player
    }

    nextPlayer.isMuted = true
    self.player = nextPlayer
    playerLayer?.player = nextPlayer
  }

  private func showPlaceholder(_ title: String) {
    player?.pause()
    player = nil
    sourceAssetURL = nil
    playbackMode = .fullAsset
    hasAnimatedIn = false
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

  private func makeTimedPlaybackComposition(
    assetURL: URL,
    playbackDuration: TimeInterval,
    loopRange: CMTimeRange,
    includeIntro: Bool
  ) -> AVAsset {
    let composition = AVMutableComposition()
    let targetDuration = CMTime(
      seconds: max(playbackDuration, 0),
      preferredTimescale: 600
    )

    do {
      let asset = AVAsset(url: assetURL)
      let videoTrack = asset.tracks(withMediaType: .video).first
      let audioTrack = asset.tracks(withMediaType: .audio).first
      var insertionPoint = CMTime.zero

      if includeIntro {
        let introDuration = CMTimeMinimum(loopRange.start, targetDuration)
        if CMTimeCompare(introDuration, .zero) > 0 {
          let introRange = CMTimeRange(start: .zero, duration: introDuration)
          try insert(timeRange: introRange, fromVideoTrack: videoTrack, audioTrack: audioTrack, into: composition, at: insertionPoint)
          insertionPoint = insertionPoint + introDuration
        }
      }

      while CMTimeCompare(insertionPoint, targetDuration) < 0 {
        let remainingDuration = targetDuration - insertionPoint
        let segmentDuration = CMTimeMinimum(loopRange.duration, remainingDuration)
        guard CMTimeCompare(segmentDuration, .zero) > 0 else {
          break
        }

        let segmentRange = CMTimeRange(start: loopRange.start, duration: segmentDuration)
        try insert(timeRange: segmentRange, fromVideoTrack: videoTrack, audioTrack: audioTrack, into: composition, at: insertionPoint)
        insertionPoint = insertionPoint + segmentDuration
      }
    } catch {
      AppLogger.error(
        "OverlayMediaView",
        "Failed to build playback composition for \(assetURL.lastPathComponent): \(error.localizedDescription)"
      )
      return AVAsset(url: assetURL)
    }

    return composition
  }

  private func insert(
    timeRange: CMTimeRange,
    fromVideoTrack videoTrack: AVAssetTrack?,
    audioTrack: AVAssetTrack?,
    into composition: AVMutableComposition,
    at insertionPoint: CMTime
  ) throws {
    if let videoTrack,
       let compositionVideoTrack = composition.tracks(withMediaType: .video).first
        ?? composition.addMutableTrack(
          withMediaType: .video,
          preferredTrackID: kCMPersistentTrackID_Invalid
        ) {
      try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: insertionPoint)
      compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
    }

    if let audioTrack,
       let compositionAudioTrack = composition.tracks(withMediaType: .audio).first
        ?? composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
        ) {
      try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: insertionPoint)
    }
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
