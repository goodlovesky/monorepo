# Clash RS

Flutter 全平台代理客户端。Android 保留 Rust `core-bridge` + `VpnService`；macOS 与 Windows 共用同一套 Flutter 桌面 UI，并统一使用 mihomo 作为桌面代理核心。

## 当前实现

- Android：`VpnService`、应用分流、Rust FFI 核心。
- macOS：系统代理、mihomo TUN、网络快照恢复、菜单栏、单实例、通用架构 App/DMG。
- Windows x64：系统代理、mihomo + Wintun TUN、托盘、单实例、固定窗口、便携包和 Inno Setup 脚本。
- 桌面 UI：首页、代理、订阅、连接、规则、日志、测试、基础/高级设置；设计参考位于 `docs/guide/`。

## 架构

```text
Flutter shared desktop UI
  ├─ ProxyAppController ── mihomo REST API (127.0.0.1:9090)
  ├─ macOS NetworkService ── networksetup / 按次管理员授权 / utun
  └─ Windows NetworkService ── WinINet registry / mihomo / Wintun

Android UI ── MethodChannel + Rust core-bridge ── Android VpnService
```

## 开发验证

```bash
cd app
flutter pub get
flutter analyze
flutter test

cd ..
PATH="$HOME/.rustup/toolchains/stable-aarch64-apple-darwin/bin:$PATH" \
RUSTC_BOOTSTRAP=1 cargo test --workspace
```

## 构建

```bash
# macOS arm64 + x86_64 App/DMG
./tools/download_mihomo.sh
./tools/build_macos.sh

# Windows x64（在 Windows + Visual Studio/Flutter 环境执行）
powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1 -Installer -Clean
```

输出：

- `dist/macos/Clash-RS-macOS.dmg`
- `dist/windows/ClashRS-1.0.0-windows-x64-portable.zip`
- `dist/windows/ClashRS-Setup-1.0.0-x64.exe`
- `dist/windows/BUILD-MANIFEST.json`
- `dist/windows/SHA256.txt`

详细说明见 `ARCHITECTURE.md`、`NETWORK_MODES.md` 和 `docs/desktop-verification.md`。

## License

GPL-3.0-or-later
