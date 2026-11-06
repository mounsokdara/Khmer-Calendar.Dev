import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var autostartChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()

    // Forward process args (e.g. --autostart) so Dart main(List<String> args) sees them.
    let processArgs = ProcessInfo.processInfo.arguments
    if processArgs.count > 1 {
      let dartArgs = Array(processArgs.dropFirst()) // drop executable path
      flutterViewController.engine.project.dartEntrypointArguments = dartArgs
    }

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

    let background = processArgs.contains("--autostart") || processArgs.contains("--background")
    if background {
      // Do not show the main window when launched as background service.
      self.orderOut(nil)
      self.isReleasedWhenClosed = false
    }

    super.awakeFromNib()
  }
}
