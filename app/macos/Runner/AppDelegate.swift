import Cocoa
import FlutterMacOS
import Network

@main
class AppDelegate: FlutterAppDelegate {
  private var statusItem: NSStatusItem?
  private var lifecycleChannel: FlutterMethodChannel?
  private var closeToTray = true
  private var trayClickAction = "show"
  private var statusMenu: NSMenu?
  private let pathMonitor = NWPathMonitor()
  private let pathMonitorQueue = DispatchQueue(label: "com.proxyapp.clashrs.network-monitor")
  private var lastNetworkAvailable: Bool?
  private var workspaceObservers: [NSObjectProtocol] = []
  private var duplicateInstance = false

  @objc override func applicationWillFinishLaunching(_ notification: Notification) {
    guard let bundleID = Bundle.main.bundleIdentifier else { return }
    let currentPID = ProcessInfo.processInfo.processIdentifier
    let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
      .first { $0.processIdentifier != currentPID }
    guard let existing = existing else { return }
    duplicateInstance = true
    if !ProcessInfo.processInfo.arguments.contains("--silent") {
      existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
    DispatchQueue.main.async { NSApp.terminate(nil) }
  }

  // 显式 @objc 防止 whole-module optimization 在 release 模式下去掉
  // Objective-C selector 元数据（NSNotificationCenter 找不到 selector 会抛
  // "unrecognized selector sent to instance" 异常）。
  //
  // Release 模式下 Swift 优化会重写 super.applicationDidFinishLaunching 的
  // 调用顺序，导致 NSApplication 内部的 delegate callback 找不到 selector
  // 元数据。我们把 super 调用延后到下一个 runloop，确保父类的注册逻辑先
  // 跑完，再做自己的事。
  @objc override func applicationDidFinishLaunching(_ notification: Notification) {
    guard !duplicateInstance else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      // 显式调 super 一次（不调 super 的方法体，但确保父类初始化完成）
      // NSApp 已经就绪，下面挂菜单和 channel 都安全。
      self.installStatusItem()
      self.installLifecycleChannel()
      self.installSystemObservers()
    }
  }

  private func installSystemObservers() {
    let center = NSWorkspace.shared.notificationCenter
    workspaceObservers.append(center.addObserver(
      forName: NSWorkspace.willSleepNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in self?.emitLifecycle("systemWillSleep") })
    workspaceObservers.append(center.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in self?.emitLifecycle("systemDidWake") })

    pathMonitor.pathUpdateHandler = { [weak self] path in
      let available = path.status == .satisfied
      DispatchQueue.main.async {
        guard let self = self, self.lastNetworkAvailable != available else { return }
        self.lastNetworkAvailable = available
        self.emitLifecycle(available ? "networkAvailable" : "networkUnavailable")
      }
    }
    pathMonitor.start(queue: pathMonitorQueue)
  }

  private func emitLifecycle(_ method: String) {
    lifecycleChannel?.invokeMethod(method, arguments: nil)
  }

  @objc override func applicationWillTerminate(_ notification: Notification) {
    pathMonitor.cancel()
    let center = NSWorkspace.shared.notificationCenter
    workspaceObservers.forEach { center.removeObserver($0) }
    workspaceObservers.removeAll()
  }

  private func installStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.title = "CRS"
    item.button?.toolTip = "Clash RS"
    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "显示 Clash RS", action: #selector(showMainWindow), keyEquivalent: "o"))
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "退出 Clash RS", action: #selector(quitApplication), keyEquivalent: "q"))
    statusMenu = menu
    item.button?.target = self
    item.button?.action = #selector(handleStatusItemClick)
    item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    statusItem = item
  }

  private func installLifecycleChannel() {
    if let controller = NSApplication.shared.windows.first?.contentViewController as? FlutterViewController {
      lifecycleChannel = FlutterMethodChannel(
        name: "com.proxyapp.app/desktop_lifecycle",
        binaryMessenger: controller.engine.binaryMessenger)
      lifecycleChannel?.setMethodCallHandler { [weak self] call, result in
        if call.method == "setCloseToTray" {
          self?.closeToTray = (call.arguments as? Bool) ?? true
          result(nil)
        } else if call.method == "setTrayClickAction" {
          self?.trayClickAction = (call.arguments as? String) == "quit" ? "quit" : "show"
          result(nil)
        } else if call.method == "quit" {
          result(nil)
          DispatchQueue.main.async { self?.quitApplication() }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  @objc private func showMainWindow() {
    NSApplication.shared.activate(ignoringOtherApps: true)
    NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
  }

  @objc private func handleStatusItemClick() {
    if NSApp.currentEvent?.type == .rightMouseUp {
      if let button = statusItem?.button, let menu = statusMenu {
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
      }
      return
    }
    if trayClickAction == "quit" {
      quitApplication()
    } else {
      showMainWindow()
    }
  }

  @objc private func quitApplication() {
    guard let channel = lifecycleChannel else {
      NSApplication.shared.terminate(nil)
      return
    }
    channel.invokeMethod("prepareForQuit", arguments: nil) { _ in
      DispatchQueue.main.async {
        NSApplication.shared.terminate(nil)
      }
    }
  }

  @objc override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return !closeToTray
  }

  @objc override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
