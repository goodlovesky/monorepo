# Clash RS 跨平台打包命令与 Linux 桌面运行环境设计

## 目标

在仓库根目录新增统一的 `cmd/` 打包入口，覆盖 Android、macOS、Windows 和 Linux。脚本复用现有 `tools/` 中已经验证的底层构建逻辑，不复制核心实现；Linux 端补齐 Flutter 桌面工程、Mihomo 运行时、系统代理和可分发产物。

版本统一读取 `app/pubspec.yaml`。每个平台输出版本化产物、`SHA256.txt`、`BUILD-MANIFEST.json` 和 `BUILD-ENVIRONMENT.txt`，任何依赖、测试、构建或产物校验失败都返回非零状态。

## 根目录命令结构

```text
cmd/
  build-android.sh
  build-macos.sh
  build-windows.ps1
  build-linux.sh
  build-all.sh
  README.md
```

- `build-android.sh`：检查 Java、Android SDK/NDK、Rust 和 Flutter，构建 Rust JNI 库，执行 Flutter 检查和测试，输出 release APK 与 AAB。
- `build-macos.sh`：检查 Xcode、Rust、Flutter 和 Mihomo，调用现有 macOS 打包流程，输出 `.app` 与 `.dmg`；默认使用临时签名，不要求公证。
- `build-windows.ps1`：检查 Flutter、Rust、Inno Setup，调用现有 Windows 构建器，输出安装程序与便携 ZIP。
- `build-linux.sh`：检查 Linux 桌面依赖，准备固定版本 Mihomo，构建 Flutter Linux release，输出 Debian 包与 tar.gz。
- `build-all.sh`：根据宿主系统执行其可原生构建的平台。macOS 执行 Android 与 macOS；Windows 执行 Android 与 Windows；Linux 执行 Android 与 Linux。脚本不会伪装成可跨系统生成原生产物。

各脚本统一接受 `--clean`、`--skip-tests`，并提供 `--help`。Android 额外接受 `--apk-only`、`--aab-only`；Linux额外接受 `--deb-only`、`--tar-only`。

## Linux Flutter 与运行时

在 `app/linux/` 建立标准 Flutter Linux runner，程序名、窗口标题和桌面标识统一为 Clash RS。应用继续使用现有 Flutter 共用 UI，不建立 Linux 专用页面。

Linux release 目录随包携带：

- `clash_rs` Flutter 可执行文件及 Flutter Linux 依赖；
- 固定版本、固定 SHA256 的 `mihomo`；
- Mihomo 与随包组件许可证；
- `.desktop` 文件和应用图标。

Mihomo 从应用安装目录解析，配置、日志、恢复快照分别写入 XDG 标准目录：

- 配置：`${XDG_CONFIG_HOME:-~/.config}/clash-rs`
- 状态：`${XDG_STATE_HOME:-~/.local/state}/clash-rs`
- 缓存：`${XDG_CACHE_HOME:-~/.cache}/clash-rs`

## Linux 网络模式

### 系统代理

新增 Linux 网络服务并接入现有 `DesktopNetworkService` 工厂：

1. GNOME 环境通过 `gsettings` 读取并保存原 HTTP、HTTPS、SOCKS、忽略主机和模式设置；启用时写入 Clash RS 本地端口，关闭和异常恢复时还原精确快照。
2. KDE Plasma 通过 `kwriteconfig6` 或 `kwriteconfig5` 保存和恢复 `kioslaverc` 代理字段，并通知 KIO 配置刷新。
3. 未识别桌面环境时返回清晰错误，不静默显示成功。

恢复快照采用原子写入；应用下次启动时检测未完成恢复并自动回滚。

### 虚拟网卡模式

Linux TUN 使用随包 Mihomo。Debian 安装脚本对固定的 Mihomo 文件授予 `cap_net_admin,cap_net_raw`；tar.gz 版本提供一次性 `pkexec` 初始化命令。应用启动前检测 capability，缺失时显示可操作的初始化错误，系统代理模式不依赖该能力。

## Linux 产物

默认生成：

```text
dist/linux/ClashRS-<version>-linux-x64.tar.gz
dist/linux/clash-rs_<version>_amd64.deb
dist/linux/SHA256.txt
dist/linux/BUILD-MANIFEST.json
dist/linux/BUILD-ENVIRONMENT.txt
```

Debian 包安装到 `/opt/clash-rs`，桌面入口写入 `/usr/share/applications`，图标写入 `/usr/share/icons/hicolor`。卸载前停止应用与 Mihomo，并恢复 Clash RS 持有的系统代理快照。

首期 Linux 架构为 x86_64/amd64；清单显式记录架构，不生成名称与实际架构不一致的包。

## 错误处理与边界

- 下载的 Mihomo 必须使用仓库内固定版本与 SHA256 校验，禁止使用未固定的 `latest` 产物。
- 清理操作只处理各平台的 build/dist 输出，不删除用户配置。
- `--skip-tests` 只跳过 Flutter 分析与测试，不跳过依赖、运行时哈希和产物完整性检查。
- 不在 macOS 本机假装生成 Windows 或 Linux 原生包；这些产物由对应系统或 CI 生成。
- 脚本输出完整产物绝对路径，并生成可复查构建清单。

## 验证

### 通用合同测试

- 四个平台脚本存在、可执行并提供帮助。
- 所有脚本从 `pubspec.yaml` 读取 `1.0.0+1`，不硬编码应用版本。
- 清单和 SHA256 覆盖所有发布产物。
- `build-all.sh` 只调度当前宿主支持的平台。

### Linux 验证

- `flutter analyze` 与现有稳定测试通过。
- Linux release 包含 `clash_rs`、Flutter 数据、Mihomo、桌面文件和图标。
- Mihomo 版本及哈希校验通过。
- tar.gz 解包后入口可执行。
- Debian 包可安装、文件清单正确、可卸载。
- GNOME/KDE 代理快照可写入、恢复文件可跨重启恢复。
- TUN capability 检查正确区分可用与未初始化状态。

## 完成标准

`cmd/` 四个平台命令均能调用经过验证的底层流程；Linux Flutter 工程可编译，系统代理逻辑接入应用，Mihomo 随包且经过哈希验证，Debian 与 tar.gz 产物合同和自动测试通过。受宿主系统限制而无法在 macOS 本机执行的 Linux/Windows 原生构建，通过对应 CI 验证。
