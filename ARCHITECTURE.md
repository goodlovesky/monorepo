# Clash RS 桌面架构

## UI 与状态

macOS 和 Windows 共用 `app/lib/features/desktop/`。`DesktopApp` 提供固定 `1000 × 660` 内容窗口、八页导航、快捷键、基础/高级设置和网络三态切换。`ProxyAppController` 管理配置、订阅、mihomo 生命周期、9090 REST API、节点选择、测速、连接、规则、日志和运行恢复。

## 核心

- 系统代理模式：Flutter 启动随包分发的 mihomo，生成 `runtime-desktop.yaml`，记录 PID，等待 `127.0.0.1:9090` 后再设置系统代理。
- TUN 模式：平台网络服务生成带 DNS/TUN 的配置并启动 mihomo。macOS 由 `crates/clash-rs-helper` 提权启动；Windows 由管理员清单启动并加载同目录 `wintun.dll`。
- Android：继续使用 `crates/core-bridge` 和 Android `VpnService`，不依赖桌面 mihomo 路径。

桌面配置保留 mihomo 支持的 AnyTLS、VLESS Reality、Hysteria2 等协议；外部控制端口统一为 9090。

## 网络状态恢复

- macOS 在修改前记录每个网络服务的 HTTP/HTTPS/SOCKS 状态，停止、退出或异常恢复时逐项还原。
- Windows 在注册表写入前保存 `ProxyEnable`、`ProxyServer`、`ProxyOverride`，调用 WinINet 广播刷新，并在退出时恢复。
- 普通 mihomo 使用 `desktop-core.pid`；恢复前校验 PID 对应命令确为 mihomo，避免终止无关进程。
- TUN 服务保存模式和 PID；停止按 TERM → KILL 回退并清理恢复文件。

## 平台壳

### macOS

- 主窗口居中、固定尺寸、禁用最大化。
- 菜单栏提供显示/退出；关闭驻留设置通过 MethodChannel 实时同步。
- 首次启用 TUN 时弹出系统管理员认证，为 bundle helper 设置 root/setuid；后续直接启动。
- 构建同时注入并签名通用架构 Flutter executable、helper 与 mihomo。

### Windows

- Per-monitor DPI 居中，固定窗口样式。
- 互斥锁保证单实例；托盘支持显示、双击恢复和退出。
- `requireAdministrator` 清单支持 TUN、路由与 DNS 操作。
- 构建脚本下载 mihomo 与官方签名 Wintun DLL，生成便携 ZIP，可选生成 Inno Setup 安装包。

## 关键路径

- `app/lib/services/proxy_app_controller.dart`
- `app/lib/core/vpn/vpn_controller.dart`
- `app/lib/platform/macos/mac_network_service.dart`
- `app/lib/platform/windows/windows_network_service.dart`
- `app/lib/features/desktop/`
- `crates/clash-rs-helper/src/main.rs`
- `tools/build_macos.sh`
- `tools/build_windows.ps1`
