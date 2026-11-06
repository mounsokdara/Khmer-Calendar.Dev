import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var autostartChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let processArgs = ProcessInfo.processInfo.arguments
    let dartArgs = processArgs.count > 1 ? Array(processArgs.dropFirst()) : [String]()
    let background =
      dartArgs.contains("--autostart") || dartArgs.contains("--background")

    // Build project with args before the engine starts so main(List<String>) receives them.
    let project = FlutterDartProject()
    project.dartEntrypointArguments = dartArgs
    let flutterViewController = FlutterViewController(project: project, nibName: nil, bundle: nil)

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

    if background {
      // Do not show the main window when launched as background service.
      self.orderOut(nil)
      self.isReleasedWhenClosed = false
    }

    super.awakeFromNib()
  }
}
