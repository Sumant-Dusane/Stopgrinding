import Cocoa
import FlutterMacOS

enum AppLogger {
  static func debug(_ scope: String, _ message: String) {
    log(level: "DEBUG", scope: scope, message: message)
  }

  static func info(_ scope: String, _ message: String) {
    log(level: "INFO", scope: scope, message: message)
  }

  static func warning(_ scope: String, _ message: String) {
    log(level: "WARNING", scope: scope, message: message)
  }

  static func error(_ scope: String, _ message: String) {
    log(level: "ERROR", scope: scope, message: message)
  }

  private static func log(level: String, scope: String, message: String) {
    NSLog("[\(level)] [\(scope)] \(message)")
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  private var overlayApiImpl: OverlayApiImpl?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    AppLogger.info("AppDelegate", "Application did finish launching.")
    super.applicationDidFinishLaunching(notification)
  }

  func configureOverlayApi(binaryMessenger: FlutterBinaryMessenger) {
    guard overlayApiImpl == nil else {
      AppLogger.debug("AppDelegate", "Overlay API already configured.")
      return
    }

    AppLogger.info("AppDelegate", "Configuring overlay API bridge.")
    let overlayApiImpl = OverlayApiImpl(binaryMessenger: binaryMessenger)
    OverlayHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: overlayApiImpl)
    self.overlayApiImpl = overlayApiImpl
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
