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
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let args = ProcessInfo.processInfo.arguments
    let background = args.contains("--autostart") || args.contains("--background")
    if background {
      // Do not show the main window when launched as background service.
      self.orderOut(nil)
      self.isReleasedWhenClosed = false
    }

    super.awakeFromNib()
  }
}
