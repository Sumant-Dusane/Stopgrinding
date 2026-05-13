import Cocoa
import FlutterMacOS
import LaunchAtLogin

private enum ShellWindowAction: String, CaseIterable {
  case showMainWindow
  case hideMainWindow
  case quitApp
}

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  private lazy var shellWindowActionHandlers: [ShellWindowAction: () -> Void] = [
    .showMainWindow: { [weak self] in
      self?.showFromMenuBar()
    },
    .hideMainWindow: { [weak self] in
      self?.orderOut(nil)
    },
    .quitApp: {
      NSApp.terminate(nil)
    },
  ]

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.delegate = self

    FlutterMethodChannel(
      name: "launch_at_startup",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { call, result in
      switch call.method {
      case "launchAtStartupIsEnabled":
        result(LaunchAtLogin.isEnabled)
      case "launchAtStartupSetEnabled":
        if let arguments = call.arguments as? [String: Any] {
          LaunchAtLogin.isEnabled = arguments["setEnabledValue"] as? Bool ?? false
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    FlutterMethodChannel(
      name: "shell_window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "window-deallocated", message: nil, details: nil))
        return
      }

      guard let action = ShellWindowAction(rawValue: call.method),
            let handler = self.shellWindowActionHandlers[action]
      else {
        result(FlutterMethodNotImplemented)
        return
      }

      handler()
      result(nil)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.configureOverlayApi(
        binaryMessenger: flutterViewController.engine.binaryMessenger
      )
    }

    super.awakeFromNib()
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    orderOut(nil)
    return false
  }

  private func showFromMenuBar() {
    NSApp.activate(ignoringOtherApps: true)
    makeKeyAndOrderFront(nil)
  }
}
