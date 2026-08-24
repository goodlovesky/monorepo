# Clash RS

简体中文 · [English](README.md)

[![Windows x64](https://github.com/goodlovesky/monorepo/actions/workflows/desktop-windows.yml/badge.svg)](https://github.com/goodlovesky/monorepo/actions/workflows/desktop-windows.yml)
[![Linux x64](https://github.com/goodlovesky/monorepo/actions/workflows/desktop-linux.yml/badge.svg)](https://github.com/goodlovesky/monorepo/actions/workflows/desktop-linux.yml)
![版本](https://img.shields.io/badge/version-1.0.0-1688f0)
![Flutter](https://img.shields.io/badge/Flutter-cross--platform-02569B?logo=flutter&logoColor=white)
![支持平台](https://img.shields.io/badge/platforms-Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-2d3345)

**Clash RS 是一个使用 Flutter 开发的跨平台代理客户端、VPN 客户端和 Mihomo GUI，支持 Android、macOS、Windows 和 Linux。** 它在一套界面中提供订阅管理、代理节点选择、网络延迟检测、规则/全局/直连路由、系统代理、虚拟网卡（TUN）模式、活动连接、日志、IP 信息和实时流量监控。

桌面端使用固定版本的 [mihomo](https://github.com/MetaCubeX/mihomo) 作为代理核心；Android 使用系统 `VpnService` 和 Rust `core-bridge`。

> 当前应用版本：**1.0.0**。桌面窗口固定为 **960 × 720**。

**[下载安装](#下载安装)** · **[新手使用](#新手快速使用)** · **[打包说明](#分平台打包)** · **[English](README.md)**

## 下载安装

普通用户请前往 [GitHub Releases 下载页](https://github.com/goodlovesky/monorepo/releases/latest)，下载 Clash RS 安装包及其校验文件。

| 下载内容 | 下载位置 | 说明 |
| --- | --- | --- |
| macOS 1.0.0 | [直接下载 DMG](https://github.com/goodlovesky/monorepo/releases/download/v1.0.0/Clash-RS-macOS.dmg) | Universal DMG，使用 ad-hoc 签名，尚未公证 |
| 稳定安装包 | [下载最新版](https://github.com/goodlovesky/monorepo/releases/latest) | 已发布的安装包、构建清单和 SHA-256 校验文件 |
| 历史版本 | [全部 Releases](https://github.com/goodlovesky/monorepo/releases) | 查看旧版本和版本说明 |
| Windows x64 测试构建 | [Windows Actions](https://github.com/goodlovesky/monorepo/actions/workflows/desktop-windows.yml) | 打开成功任务并下载 `Clash-RS-Windows-x64` |
| Linux x64 测试构建 | [Linux Actions](https://github.com/goodlovesky/monorepo/actions/workflows/desktop-linux.yml) | 打开成功任务并下载 `Clash-RS-Linux-x64` |
| 源码 | [ZIP](https://github.com/goodlovesky/monorepo/archive/refs/heads/main.zip) · [tar.gz](https://github.com/goodlovesky/monorepo/archive/refs/heads/main.tar.gz) | 当前 `main` 分支源码快照 |

当前 Release 已提供 macOS DMG；Windows 和 Linux 安装包正在整理到 Release，在此之前可从上方已经成功的 Actions 任务下载。GitHub Actions 产物主要用于测试，并且只保留有限时间。

## 项目能做什么

- 添加、更新和管理订阅链接。
- 显示代理组和节点，检测节点网络延迟并选择当前节点。
- 在规则、全局、直连三种代理模式之间切换。
- 开启系统代理或者虚拟网卡模式。
- 实时显示上传、下载、内存、连接、规则和核心日志。
- 软件异常退出后恢复原来的系统代理配置。
- macOS、Windows、Linux 共用一套 Flutter 桌面 UI。
- 生成带版本号、构建清单和 SHA-256 校验文件的安装包。

## 平台支持情况

| 平台 | 运行方式 | 打包产物 |
| --- | --- | --- |
| Android | Android `VpnService` + Rust `core-bridge` | APK、AAB |
| macOS | mihomo、系统代理、utun | Universal App、DMG |
| Windows x64 | mihomo、WinINet 系统代理、Wintun | 便携 ZIP、Inno Setup 安装包 |
| Linux x64 | mihomo、GNOME/KDE 系统代理、TUN | DEB、tar.gz |

Windows ARM64、Linux ARM64、RPM 和 AppImage 不属于 1.0.0 版本的发布范围。

## 新手快速使用

如果你只想安装使用，不需要编译源码，请下载与你的操作系统对应的构建产物，然后执行以下步骤：

1. 安装或解压 Clash RS，启动软件。
2. 点击左侧的 **订阅**。
3. 将自己的订阅链接粘贴到顶部输入框，然后点击 **新建**。
4. 等待订阅下载和解析完成。
5. 打开 **代理** 页面，将光标移动到真实代理节点卡片上，点击 **Check** 检测网络。
6. 点击延迟正常的节点。检测完成后，卡片右侧会显示毫秒数。
7. 返回 **首页**。普通浏览器和桌面软件优先开启 **系统代理**；需要接管全部网络时再开启 **虚拟网卡模式**。
8. 打开 **IP 信息**、**连接** 或 **流量统计**，确认出口和实时数据已经变化。

请使用自己有权访问的订阅和节点。提交问题或截图时，不要公开完整订阅链接。

## 系统代理和虚拟网卡模式有什么区别

| 模式 | 适用场景 | 特点 |
| --- | --- | --- |
| 系统代理 | 浏览器以及遵循系统代理设置的应用 | 启动快，通常不需要额外网络权限 |
| 虚拟网卡模式 | 不读取系统代理的应用、游戏、命令行程序、全设备代理 | macOS 可能要求管理员确认，Windows 使用 Wintun，Linux 需要网络 capability |

第一次使用时先选择 **系统代理**。只有目标程序不走系统代理时，再切换到 **虚拟网卡模式**。

## 下载源码和准备环境

下面所有命令默认都从仓库根目录执行。

### 公共环境

需要安装：

- Git
- Flutter stable，并开启对应的桌面平台支持
- Rust stable 和 Cargo
- Python 3

下载代码并安装 Flutter 依赖：

```bash
git clone https://github.com/goodlovesky/monorepo.git proxy-monorepo
cd proxy-monorepo
flutter doctor
cd app
flutter pub get
cd ..
```

`flutter doctor` 中与你准备构建的平台相关的项目应当显示正常。

### Android 环境

需要 Android Studio、Android SDK、Android NDK、Java、Rust，以及 Bash 4 或更高版本。

在 Android Studio 的 SDK Manager 中安装 NDK 后，设置环境变量：

```bash
export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/<已安装版本>"
```

Android 辅助脚本检测不到 `cargo-ndk` 时会自动安装。

### macOS 环境

需要在 macOS 上安装：

- Xcode
- Xcode Command Line Tools
- Flutter
- Rust

本地默认生成 ad-hoc 签名的 App 和 DMG，不需要 Apple Developer ID，也不需要公证账号。正式对外发布时再配置签名和公证信息。

### Windows 环境

需要在 Windows 10/11 x64 上安装：

- Flutter
- Visual Studio，并勾选 **Desktop development with C++**
- Rust MSVC 工具链
- PowerShell
- Inno Setup

macOS 本机不能原生生成 Windows EXE。没有 Windows 构建机时，使用仓库中的 GitHub Actions。

### Linux 环境

Ubuntu/Debian 安装依赖：

```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev \
  liblzma-dev libblkid-dev libcap2-bin dpkg-dev curl
```

确认 Flutter 已开启 Linux 桌面支持：

```bash
flutter config --enable-linux-desktop
flutter doctor
```

## 分平台打包

### Android：APK 和 AAB

从仓库根目录执行：

```bash
./cmd/build-android.sh --clean
```

只生成其中一种格式：

```bash
./cmd/build-android.sh --apk-only
./cmd/build-android.sh --aab-only
```

跳过重复测试：

```bash
./cmd/build-android.sh --skip-tests
```

输出文件：

```text
dist/android/ClashRS-1.0.0-android.apk
dist/android/ClashRS-1.0.0-android.aab
dist/android/BUILD-MANIFEST.json
dist/android/BUILD-ENVIRONMENT.txt
dist/android/SHA256.txt
```

APK 可以直接安装到测试设备；AAB 用于应用商店发布流程。

### macOS：App 和 DMG

必须在 macOS 上执行：

```bash
./cmd/build-macos.sh --clean
```

输出文件：

```text
dist/macos/Clash RS.app
dist/macos/Clash-RS-macOS.dmg
dist/macos/BUILD-MANIFEST.json
dist/macos/BUILD-ENVIRONMENT.txt
dist/macos/SHA256.txt
```

打开 DMG 后，将 **Clash RS** 拖入 **Applications**。当前本地包使用 ad-hoc 签名；正式签名和公证参数见 [`docs/desktop-release-checklist.md`](docs/desktop-release-checklist.md)。

### Windows x64：便携包和安装包

在 Windows PowerShell 中，从仓库根目录执行：

```powershell
.\cmd\build-windows.ps1 -Clean
```

输出文件：

```text
dist/windows/ClashRS-1.0.0-windows-x64-portable.zip
dist/windows/ClashRS-Setup-1.0.0-x64.exe
dist/windows/BUILD-MANIFEST.json
dist/windows/BUILD-ENVIRONMENT.txt
dist/windows/SHA256.txt
```

便携包解压后运行 `clash_rs.exe`；安装包按向导安装即可。

#### 使用 GitHub Actions 打包 Windows

没有 Windows 电脑时：

1. 将代码推送到 GitHub。
2. 打开仓库的 **Actions** 页面。
3. 在左侧选择 **Desktop Windows x64**。
4. 点击 **Run workflow**，选择需要打包的分支并启动。
5. 等待构建、安装和卸载冒烟测试全部完成。
6. 在运行结果底部下载 **Clash-RS-Windows-x64** artifact。
7. 解压 artifact，可以得到安装包、便携包、环境记录和 SHA-256 文件。

工作流文件： [`.github/workflows/desktop-windows.yml`](.github/workflows/desktop-windows.yml)。构建产物默认保留 14 天。

### Linux x64：DEB 和 tar.gz

必须在 Ubuntu/Debian Linux 上执行：

```bash
./cmd/build-linux.sh --clean
```

只生成一种包：

```bash
./cmd/build-linux.sh --deb-only
./cmd/build-linux.sh --tar-only
```

输出文件：

```text
dist/linux/clash-rs_1.0.0_amd64.deb
dist/linux/ClashRS-1.0.0-linux-x64.tar.gz
dist/linux/BUILD-MANIFEST.json
dist/linux/BUILD-ENVIRONMENT.txt
dist/linux/SHA256.txt
```

安装 DEB：

```bash
sudo apt install ./dist/linux/clash-rs_1.0.0_amd64.deb
```

DEB 安装脚本会尝试为内置 mihomo 设置 TUN 所需的 capability。使用 tar.gz 时，第一次开启虚拟网卡模式可能会提示执行 `pkexec setcap`。

没有 Linux 电脑时，也可以打开 GitHub 仓库的 **Actions** 页面，手动运行 **Desktop Linux x64**。任务通过后下载 **Clash-RS-Linux-x64** artifact。工作流文件是 [`.github/workflows/desktop-linux.yml`](.github/workflows/desktop-linux.yml)。

### 构建当前电脑支持的全部平台

```bash
./cmd/build-all.sh --clean
```

- macOS：构建 Android 和 macOS。
- Linux：构建 Android 和 Linux。
- Windows：使用 PowerShell 执行 `.\cmd\build-windows.ps1`。

`build-all.sh` 不会在 macOS 上交叉编译 Windows，也不会在 macOS 上交叉编译 Linux。

## 第一次启动后的完整操作

### 1. 添加订阅

进入 **订阅** 页面，将订阅地址粘贴到输入框并点击 **新建**。订阅卡片显示后，可以点击刷新按钮更新内容。

### 2. 检测和选择节点

进入 **代理** 页面：

- `DIRECT` 表示直连，不是远程代理节点。
- `REJECT` 表示拒绝连接，不进行测速。
- 将光标移动到普通代理节点卡片上，未检测过时会显示 **Check**。
- 点击 **Check** 后应用会检测延迟，并将该节点设为当前节点。
- 成功时显示绿色毫秒数；异常时显示 **代理异常**。

### 3. 选择路由模式

- **规则**：按照订阅规则决定直连或代理，适合日常使用。
- **全局**：所有流量使用当前代理节点。
- **直连**：所有流量绕过代理。

### 4. 开启网络模式

返回首页，在 **系统代理** 和 **虚拟网卡模式** 中选择一种。切换时应用会先启动核心，再修改系统网络配置。

### 5. 检查运行状态

- **流量统计**：查看实时上传、下载、连接数和内存。
- **IP 信息**：确认出口 IP 和地区是否发生变化。
- **连接**：查看当前主机、下载量、上传量、速度和代理链路。
- **日志**：查看核心和应用运行信息。

## 关闭软件和恢复网络

正常关闭时，应用会恢复开启代理前保存的系统网络配置。遇到系统代理残留时：

1. 重新打开 Clash RS。
2. 将系统代理开关打开后再关闭一次。
3. 确认系统设置中的 HTTP、HTTPS 和 SOCKS 代理已经恢复。
4. macOS 还可以使用 `tools/uninstall_macos.sh` 预览或执行数据清理。

不要在 Clash RS 正在切换代理模式时强制结束进程。

## 开发测试

Flutter 静态分析和测试：

```bash
cd app
flutter analyze
flutter test
```

Rust 工作区测试：

```bash
cd ..
RUSTC_BOOTSTRAP=1 cargo test --workspace
```

相关文档：

- [项目架构](ARCHITECTURE.md)
- [网络模式](NETWORK_MODES.md)
- [打包命令说明](cmd/README.md)
- [桌面发布检查清单](docs/desktop-release-checklist.md)
- [干净机器验收](docs/clean-machine-verification.md)
- [验证记录](VERIFICATION.txt)

## 常见问题

### 核心启动失败

- 检查当前订阅是否已经成功下载。
- 检查当前订阅是否包含有效节点。
- 检查软件内置的 `mihomo` 是否存在并具有执行权限。
- 检查混合代理端口或控制端口是否被其他程序占用。
- 打开软件的 **日志** 页面查看并导出诊断信息。

### 节点没有显示延迟

- 光标必须放在真实代理节点卡片上，剩余流量、到期信息、`DIRECT` 和 `REJECT` 不执行普通节点测速逻辑。
- 点击 **Check** 后等待检测完成。
- 检查代理核心是否已经启动。
- 刷新订阅后再次测试。

### 开启系统代理后无法联网

- 先关闭再重新开启一次系统代理。
- 选择一个延迟正常的节点。
- 检查 **连接**、**流量统计** 和 **IP 信息** 是否有实时数据。
- 如果手动修改过系统网络代理，先恢复系统设置，再重新切换 Clash RS。

### 虚拟网卡模式启动失败

- macOS：确认管理员操作提示。
- Windows：确认安装目录中存在 `wintun.dll`。
- Linux：确认内置 mihomo 具有 `cap_net_admin` 和 `cap_net_raw`。

Linux 可以检查：

```bash
getcap /opt/clash-rs/mihomo
```

### 日志在哪里

- macOS：`~/Library/Logs/ClashRS/`
- Windows：打开 **设置 → 高级设置 → 日志目录**
- Linux：打开 **设置 → 高级设置 → 日志目录**；网络恢复状态位于 `$XDG_STATE_HOME` 或 `~/.local/state`

### 如何验证下载文件

macOS/Android：

```bash
cd dist/<平台目录>
shasum -a 256 -c SHA256.txt
```

Linux：

```bash
cd dist/linux
sha256sum -c SHA256.txt
```

Windows PowerShell 可以使用：

```powershell
Get-FileHash .\ClashRS-Setup-1.0.0-x64.exe -Algorithm SHA256
```

然后与 `SHA256.txt` 中对应的值比较。

## 项目目录

```text
app/          Flutter 应用、Android 和桌面原生 Runner
crates/       Rust core-bridge 工作区
cmd/          面向使用者的统一打包命令
tools/        平台构建、依赖下载和安装辅助脚本
docs/         架构、验收、发布和设计文档
dist/         构建后生成的安装包
```

## 许可证

Clash RS 使用 **GPL-3.0-or-later** 许可证。
