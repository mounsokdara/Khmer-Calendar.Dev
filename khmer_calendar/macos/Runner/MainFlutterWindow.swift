import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var autostartChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()

    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    autostartChannel = FlutterMethodChannel(
      name: "khmer.autostart",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    autostartChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "enable":
        result(KhmerAutostart.enable())
      case "disable":
        result(KhmerAutostart.disable())
      case "isEnabled":
        result(KhmerAutostart.isEnabled())
      case "ensureRunning":
        result(KhmerAutostart.ensureRunning())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let args = ProcessInfo.processInfo.arguments
    let background =
      args.contains("--autostart") || args.contains("--background")
    if background {
      self.orderOut(nil)
      self.isReleasedWhenClosed = false
      self.canHide = true
      self.isExcludedFromWindowsMenu = true
      // Tiny frame so nothing flashes if orderOut is delayed.
      self.setFrame(NSRect(x: 0, y: 0, width: 1, height: 1), display: false)
    }

    super.awakeFromNib()
  }

  override func close() {
    let args = ProcessInfo.processInfo.arguments
    let background =
      args.contains("--autostart") || args.contains("--background")
    if background {
      // Do not close: keep the process (and Dart reminder loop) alive.
      self.orderOut(nil)
      return
    }
    super.close()
  }
}
