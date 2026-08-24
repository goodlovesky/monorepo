import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let positionKeyPrefix = "ClashRS.window.position"
  private var lifecycleChannel: FlutterMethodChannel?
  private var pendingFrameOrigin: NSPoint?

  override func awakeFromNib() {
    super.awakeFromNib()

    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // 两个平台共用 960x720 逻辑像素基准，禁止缩放与最大化。
    let fixedSize = NSSize(width: 960, height: 720)
    self.minSize = fixedSize
    self.maxSize = fixedSize
    // 移除 .resizable（窗口不可缩放，无最大化按钮也不可拖拽边缘）
    self.styleMask.remove(.resizable)

    // 优先恢复用户上次窗口位置；屏幕不再存在时回退到主屏中央。
    if let savedOrigin = MainFlutterWindow.loadSavedPosition(),
       NSScreen.screens.contains(where: { $0.frame.contains(savedOrigin) }) {
      self.setFrame(NSRect(origin: savedOrigin, size: fixedSize), display: true)
    } else if let screen = NSScreen.main {
      // 居中到主屏
      let visible = screen.visibleFrame
      self.setFrame(NSRect(
        x: visible.midX - fixedSize.width / 2,
        y: visible.midY - fixedSize.height / 2,
        width: fixedSize.width,
        height: fixedSize.height
      ), display: true)
    } else {
      self.setContentSize(fixedSize)
      self.center()
    }
    self.title = "Clash RS"
    self.isReleasedWhenClosed = false

    // 监听移动：保存位置以便下次启动恢复（尺寸固定不再保存）。
    NotificationCenter.default.addObserver(
      self, selector: #selector(windowDidMoveOrResize),
      name: NSWindow.didMoveNotification, object: self)

    // 暴露窗口位置读写给 Flutter 端。
    let channel = FlutterMethodChannel(
      name: "com.proxyapp.app/desktop_window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "getPosition":
        let p = self.frame.origin
        result(["x": Double(p.x), "y": Double(p.y)])
      case "setPosition":
        if let args = call.arguments as? [String: Any],
           let x = args["x"] as? Double, let y = args["y"] as? Double {
          self.setFrameOrigin(NSPoint(x: x, y: y))
          MainFlutterWindow.persistPosition(self.frame.origin)
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "setPosition 需要 {x,y}", details: nil))
        }
      case "recenter":
        // 重新居中到 keyWindow 所在屏幕的 visibleFrame 中心
        if let screen = self.screen ?? NSScreen.main {
          let visible = screen.visibleFrame
          let frame = self.frame
          self.setFrameOrigin(NSPoint(
            x: visible.midX - frame.width / 2,
            y: visible.midY - frame.height / 2
          ))
          MainFlutterWindow.persistPosition(self.frame.origin)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.lifecycleChannel = channel

    RegisterGeneratedPlugins(registry: flutterViewController)
    // XIB 会在 awakeFromNib 尾声把 APP_NAME 再写回标题；下一轮主循环覆盖为参考 UI 名称。
    DispatchQueue.main.async { [weak self] in
      self?.title = "Clash RS"
      if ProcessInfo.processInfo.arguments.contains("--silent") {
        self?.orderOut(nil)
      }
    }
  }

  @objc private func windowDidMoveOrResize() {
    // 窗口尺寸固定，只持久化位置
    MainFlutterWindow.persistPosition(self.frame.origin)
  }

  private static func persistPosition(_ origin: NSPoint) {
    UserDefaults.standard.set(Double(origin.x), forKey: positionKeyPrefix + ".x")
    UserDefaults.standard.set(Double(origin.y), forKey: positionKeyPrefix + ".y")
  }

  private static func persistFrame(_ frame: NSRect) {
    UserDefaults.standard.set(Double(frame.origin.x), forKey: positionKeyPrefix + ".x")
    UserDefaults.standard.set(Double(frame.origin.y), forKey: positionKeyPrefix + ".y")
    UserDefaults.standard.set(Double(frame.size.width), forKey: positionKeyPrefix + ".w")
    UserDefaults.standard.set(Double(frame.size.height), forKey: positionKeyPrefix + ".h")
  }

  private static func loadSavedPosition() -> NSPoint? {
    let x = UserDefaults.standard.double(forKey: positionKeyPrefix + ".x")
    let y = UserDefaults.standard.double(forKey: positionKeyPrefix + ".y")
    if x == 0 && y == 0 { return nil }
    return NSPoint(x: x, y: y)
  }

  /// 同时还原 origin + size（如果用户之前调整过）。
  private static func loadSavedFrame() -> NSRect? {
    let x = UserDefaults.standard.double(forKey: positionKeyPrefix + ".x")
    let y = UserDefaults.standard.double(forKey: positionKeyPrefix + ".y")
    let w = UserDefaults.standard.double(forKey: positionKeyPrefix + ".w")
    let h = UserDefaults.standard.double(forKey: positionKeyPrefix + ".h")
    if x == 0 && y == 0 && w == 0 && h == 0 { return nil }
    return NSRect(x: x, y: y, width: w == 0 ? 960 : w, height: h == 0 ? 720 : h)
  }
}
