# Clash RS 桌面端缺陷与风险清单

> 更新日期：2026-08-24
> 当前分支：`feature/mihomo-desktop`
> 本文件区分“已修复源码缺陷”和“必须在目标环境闭环的发布风险”。

## 已修复

| 编号 | 原问题 | 修复结果 | 自动化/证据 |
|---|---|---|---|
| BUG-001 | macOS 系统代理恢复未等待 | HTTP/HTTPS/SOCKS 按服务顺序 await；失败保留恢复状态 | `mac_network_service.dart`、`mac_network_service_test.dart` |
| BUG-002 | TUN 恢复文件没有可靠进程身份 | 保存 PID、可执行路径、启动标识，恢复前防 PID 复用 | macOS 网络服务与身份往返测试 |
| BUG-003 | TUN 超时未强杀/清理未验证 | TERM/KILL 后复查进程、控制端口和新增 utun | macOS 网络服务与契约测试 |
| BUG-004 | 永久 setuid helper 可被滥用 | 删除安装/打包路径，改为固定 mihomo 按次管理员授权 | clean release 包不含 helper |
| BUG-005 | 控制端口 16170/9090 不一致 | 单一 `controllerPort`，默认 9090 | 设置联动测试 |
| BUG-006 | URL 测试始终 Dart 直连 | 显式选择 DIRECT/本地代理/TUN 并展示路径 | `desktop_improvements_test.dart` |
| BUG-009 | 更新缓存和 0.1.0 错误 | 正确时间方向，当前版本 1.0.0，仅检查更新 | 更新检查测试 |
| BUG-010 | Merge/Script 未应用 | 真实运行配置合并、受限 DSL、验证、回滚 | `config_extensions_test.dart` |
| BUG-011 | 缺少 mihomo 日志 | 接入可取消 `/logs` NDJSON 流并脱敏 | 日志流测试 |
| BUG-012 | 桌面 autoRestart 无效 | 进程异常退出最多三次退避恢复 | 控制器实现 |
| BUG-013 | 备份非事务且重复 | 替换/合并/去重/预校验/回滚 | 设置与备份流程 |
| BUG-014 | IP timer 未取消 | 所有 timer、日志流取消，销毁后禁止通知 | 控制器生命周期 |
| BUG-015 | 内核版本硬编码 | 读取打包 mihomo `-v` | 首页信息与构建验证 |
| BUG-016 | 显示 Darwin Version | macOS 使用 `sw_vers -productVersion` | 桌面系统信息 |
| BUG-017 | 侧栏内存固定 0 | 绑定 `controller.memoryMb` | 实时数据模型 |
| BUG-018 | 三个目录指向同一路径 | 分别使用配置、App Resources、日志目录 | 设置页联动 |
| BUG-019 | Telegram/GitHub 行为错误 | 使用真实 Telegram/GitHub 地址 | 设置顶栏 |
| BUG-020 | 主题色无效 | 主色与桌面选中态即时消费 `accentColor` | 主题单测 |
| BUG-021 | IP 明文单数据源 | HTTPS 主备服务，代理模式切换立即刷新 | IP 解析测试 |
| BUG-022 | DMG 与源码不同步 | 已由当前源码重新生成并校验 | `dist/macos`、`VERIFICATION.txt` |
| BUG-023 | 外部 TUN 崩溃后状态停滞 | 连续三次 API 失败触发最多三次重建 | 外部核心 watchdog 契约测试 |
| BUG-024 | 睡眠唤醒/网络切换不恢复 | `NSWorkspace` + `NWPathMonitor` 驱动健康检查与恢复 | 原生生命周期契约测试 |
| BUG-025 | 系统代理首个恢复错误中断全部流程 | 汇总所有服务/协议失败并保留 recovery | macOS 网络服务实现 |
| BUG-026 | 开机自启仅写 plist | 使用 launchctl bootstrap/bootout，重复实例自动退出 | 启动注册契约测试 |
| BUG-027 | 公证顺序错误 | App 公证与 staple 完成后才制作、公证和 staple DMG | 构建顺序契约测试 |
| BUG-028 | Linux 被当作移动端且网络服务误用 macOS 实现 | Linux 接入共用桌面 UI、专用网络服务、核心路径、URL/脚本及开机自启 | Linux 网络服务与打包合同测试 |
| BUG-029 | 缺少统一跨平台发布入口 | 根目录 `cmd/` 统一调度四个平台原生打包并输出清单和 SHA-256 | `cross_platform_packaging_contract_test.dart` |

## 已实现但仍需视觉矩阵复核

### BUG-007：浅色/跟随系统主题

- **源码状态**：已修复强制深色；Material、窗口背景、侧栏、顶栏、通用卡片和主色会随主题变化。
- **剩余验收**：逐页浅色截图仍需在 macOS 与 Windows 目标机复核，尤其是历史页面内自定义色块。

### BUG-008：English 业务文案

- **源码状态**：Material locale、桌面主导航和页面标题已经联动 English。
- **剩余验收**：复杂内容页仍含中文业务术语；1.0.0 默认语言为中文，不影响代理功能。完整英文内容列入 UI 文案复核，不再伪装成已全部翻译。

## 目标环境发布风险

### RISK-001：Apple 正式签名与公证凭据缺失（P0）

- 当前生成的 DMG 为 ad-hoc 签名。
- 构建脚本已经支持 Developer ID、Hardened Runtime、notarytool、staple 和 Gatekeeper。
- 闭环条件：提供签名 identity 与 Keychain 公证 profile 后执行 `tools/build_macos.sh`。

### RISK-002：Windows x64 真机产物与网络行为（P0）

- 构建、固定依赖下载与 SHA-256 校验、资源校验、版本化安装器、构建清单和 CI 安装/卸载冒烟已实现。
- 当前 macOS 主机不运行 Windows 二进制；CI/Windows 10/11 仍需生成并安装产物。
- 注册表快照/恢复和 WinINet 广播已有三项自动化测试。

### RISK-003：干净机网络恢复矩阵（P0）

必须保留实际机器证据：系统代理/TUN 前后状态、强退、睡眠唤醒、网络切换、取消提权、卸载。

### RISK-004：长期运行（P2）

8 小时/24 小时 soak 需要真实时间与流量。自动重启、定时器取消、日志上限已实现，但仍需留存长期资源曲线。

### RISK-005：Linux 桌面环境矩阵（P1）

- Ubuntu GitHub Actions 已完成 Flutter release、DEB、tar.gz、文件清单和 SHA-256 验证。
- GNOME/KDE 代理命令与恢复状态已有自动化测试；Wayland/X11、真实桌面会话和 TUN capability 仍需目标机留存验收证据。

## 当前测试覆盖

- Flutter 完整测试：见 `VERIFICATION.txt`。
- macOS 特权入口：永久 helper 已移除；Release App 不包含 `clash-rs-helper`。
- Windows 网络服务：注册表快照、恢复、广播、失败回滚测试通过。
- 真实打包 mihomo：本机契约冒烟覆盖版本、代理、流量、内存、连接、规则、日志入口和模式切换。
- 目标机检查步骤：`docs/clean-machine-verification.md`、`docs/desktop-release-checklist.md`。
