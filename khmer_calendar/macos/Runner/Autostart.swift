import Foundation
import ServiceManagement

/// Login-item registration that launches the app in background-only mode.
/// macOS 13+: SMAppService.mainApp (Settings > General > Login Items).
/// The registered item is the main app; we pass --autostart via a small
/// LaunchAgent so the process starts headless. On older macOS we use a
/// login item that points at a helper script, or the app itself (AppDelegate
/// detects --autostart from a LaunchAgent plist we install).
enum KhmerAutostart {
  private static let agentLabel = "com.mounsokdara.khmercalendar.background"

  static func enable() -> Bool {
    // Prefer a LaunchAgent that runs the app with --autostart (true background).
    if installLaunchAgent() {
      return true
    }
    // Fallback: SMAppService / login item (still starts headless via AppDelegate
    // when the process was launched by the agent; direct login-item launch may
    // show briefly then hide).
    if #available(macOS 13.0, *) {
      do {
        try SMAppService.mainApp.register()
      } catch {
        if SMAppService.mainApp.status == .requiresApproval {
          SMAppService.openSystemSettingsLoginItems()
        }
        return SMAppService.mainApp.status == .enabled
      }
      if SMAppService.mainApp.status == .requiresApproval {
        SMAppService.openSystemSettingsLoginItems()
      }
      return SMAppService.mainApp.status == .enabled || agentInstalled()
    }
    return setLoginItemLegacy(enabled: true)
  }

  static func disable() -> Bool {
    removeLaunchAgent()
    if #available(macOS 13.0, *) {
      do {
        try SMAppService.mainApp.unregister()
      } catch {
        return SMAppService.mainApp.status != .enabled && !agentInstalled()
      }
      return SMAppService.mainApp.status != .enabled && !agentInstalled()
    }
    return setLoginItemLegacy(enabled: false) && !agentInstalled()
  }

  static func isEnabled() -> Bool {
    if agentInstalled() { return true }
    if #available(macOS 13.0, *) {
      return SMAppService.mainApp.status == .enabled
    }
    return loginItemLegacyEnabled()
  }

  // MARK: - LaunchAgent (background-only)

  private static func agentPlistURL() -> URL {
    let dir = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    return dir.appendingPathComponent("\(agentLabel).plist")
  }

  private static func agentInstalled() -> Bool {
    FileManager.default.fileExists(atPath: agentPlistURL().path)
  }

  private static func installLaunchAgent() -> Bool {
    let exe = Bundle.main.executableURL?.path ?? Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS")
      .appendingPathComponent(Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? "Khmer Calendar")
      .path
    let plist: [String: Any] = [
      "Label": agentLabel,
      "ProgramArguments": [exe, "--autostart"],
      "RunAtLoad": true,
      "KeepAlive": false,
      "ProcessType": "Background",
      "LimitLoadToSessionType": "Aqua",
    ]
    let url = agentPlistURL()
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try PropertyListSerialization.data(
        fromPropertyList: plist,
        format: .xml,
        options: 0
      )
      try data.write(to: url, options: .atomic)
      // Load without requiring user interaction when possible.
      let proc = Process()
      proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
      proc.arguments = ["load", "-w", url.path]
      try? proc.run()
      proc.waitUntilExit()
      return true
    } catch {
      return false
    }
  }

  private static func removeLaunchAgent() {
    let url = agentPlistURL()
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    proc.arguments = ["unload", "-w", url.path]
    try? proc.run()
    proc.waitUntilExit()
    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Legacy login item

  private static func appPath() -> String {
    Bundle.main.bundlePath
  }

  private static func quote(_ value: String) -> String {
    value.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }

  private static func runAppleScript(_ source: String) -> NSAppleEventDescriptor? {
    var error: NSDictionary?
    let script = NSAppleScript(source: source)
    let out = script?.executeAndReturnError(&error)
    if error != nil { return nil }
    return out
  }

  private static func setLoginItemLegacy(enabled: Bool) -> Bool {
    let path = quote(appPath())
    let source: String
    if enabled {
      source = """
      tell application "System Events"
        if (count of (every login item whose path is "\(path)")) = 0 then
          make login item at end with properties {path:"\(path)", hidden:true}
        end if
      end tell
      """
    } else {
      source = """
      tell application "System Events"
        delete (every login item whose path is "\(path)")
      end tell
      """
    }
    _ = runAppleScript(source)
    return enabled ? loginItemLegacyEnabled() : !loginItemLegacyEnabled()
  }

  private static func loginItemLegacyEnabled() -> Bool {
    let path = quote(appPath())
    let source = """
    tell application "System Events"
      return (count of (every login item whose path is "\(path)")) > 0
    end tell
    """
    guard let out = runAppleScript(source) else { return false }
    return out.booleanValue
  }
}
