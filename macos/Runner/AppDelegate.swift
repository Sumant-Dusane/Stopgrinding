import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var overlayApiImpl: OverlayApiImpl?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
  }

  func configureOverlayApi(binaryMessenger: FlutterBinaryMessenger) {
    guard overlayApiImpl == nil else {
      return
    }

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
