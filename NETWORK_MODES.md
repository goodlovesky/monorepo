# 桌面网络模式

首页“网络设置”提供三个互斥状态：关闭、系统代理、虚拟网卡模式。切换失败会恢复到切换前状态。

## 系统代理

1. 启动 bundle 中的 mihomo，并等待 `127.0.0.1:9090` REST API。
2. mihomo 监听默认 HTTP `17890`、SOCKS `17891`，端口可在设置页修改。
3. macOS 使用 `networksetup`，Windows 使用 Internet Settings 注册表和 WinINet 广播。
4. 停止时还原启用前的精确代理快照，并终止本应用托管的 mihomo。

适用于遵循系统代理的浏览器和桌面应用。

## 虚拟网卡模式

mihomo 根据 `runtime-macos-tun.yaml` 或 `runtime-windows-tun.yaml` 创建 TUN，支持 System/gVisor/Mixed 栈、自动路由、DNS 劫持和 IPv6 设置。

- macOS：首次启用会进行一次系统管理员认证，为 `clash-rs-helper` 安装运行权限；helper 以提升后的身份启动 mihomo/utun。
- Windows：应用清单请求管理员运行，mihomo 与官方签名 `wintun.dll` 同目录分发。

适用于不读取系统代理设置的应用。

## 关闭

停止普通核心或 TUN 核心，清空运行统计并恢复平台网络快照。应用正常退出、托盘退出和下一次异常恢复都会走相同清理路径。

## 运行文件

应用支持目录中可能出现：

- `runtime-desktop.yaml`
- `runtime-macos-tun.yaml` / `runtime-windows-tun.yaml`
- `desktop-core.pid`
- `network-recovery.json` / `windows-network-recovery.json`
- `mihomo-desktop.log` / `macos-tun.log`

控制 API 固定为 `http://127.0.0.1:9090`。
