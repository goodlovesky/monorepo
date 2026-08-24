# Clash RS 桌面端完成状态

> 更新日期：2026-08-24
> 当前分支：`feature/mihomo-desktop`
> 桌面基准：Flutter 共用 UI，macOS / Windows / Linux 固定窗口 `960 × 720`，应用版本 `1.0.0`。

## P0 — 已完成的实现

- [x] macOS 系统代理按网络服务、HTTP/HTTPS/SOCKS 顺序等待恢复；失败保留恢复文件和具体服务名。
- [x] macOS `networksetup` 使用参数数组传递含空格的服务名称。
- [x] TUN 上线后原子保存 mihomo PID、可执行路径和启动标识；TERM 超时执行 SIGKILL，并防止 PID 复用误杀。
- [x] 移除永久 `setuid root` helper；仅对 App 内固定 mihomo 执行按次管理员授权，打包产物确认不含旧 helper。
- [x] TUN 停止/恢复后复查进程、控制端口和新增 utun；异常时保留恢复状态，不伪报成功。
- [x] 外部 TUN 控制 API 连续失败三次后按 1/2 秒退避重建，最多三次；睡眠唤醒和网络恢复共用健康检查。
- [x] 系统代理恢复聚合全部服务/协议错误，单项失败不再中断后续恢复。
- [x] Windows 注册表快照/恢复、WinINet 广播、Wintun 运行配置、崩溃恢复标记、托盘、单实例和固定窗口实现完成。
- [x] Windows x64 便携包/安装包/构建清单/SHA-256/构建环境脚本完成，产物名携带 `1.0.0` 版本。
- [x] mihomo `v1.19.30` 与 Wintun `0.14.1` 固定版本及下载 SHA-256 校验完成，不再使用 `latest`。
- [x] Windows 安装器支持覆盖升级、旧进程优雅退出、静默安装/卸载和用户配置保留。
- [x] Windows x64 GitHub Actions 构建、资源校验、临时安装与卸载冒烟任务完成：`.github/workflows/desktop-windows.yml`。
- [x] 根目录 `cmd/` 提供 Android、macOS、Windows、Linux 与当前宿主批量打包入口。
- [x] Linux Flutter runner、GNOME/KDE 系统代理快照恢复、TUN capability 检查和 XDG 运行目录接入完成。
- [x] Linux x64 固定 Mihomo `v1.19.30`、DEB/tar.gz、构建清单、SHA-256 与 GitHub Actions 原生构建完成。
- [x] 当前源码重新生成 Universal macOS App 和 DMG；App、helper、mihomo 均为 `arm64+x86_64`。
- [x] macOS DMG 本地完整性、架构、ad-hoc 签名和启动冒烟验证完成。

## P1 — 已完成的功能

- [x] 默认 `9090` 控制端口统一驱动运行配置、API、端口检查、TUN、Web UI 和诊断。
- [x] 深色、浅色、跟随系统主题生效；侧栏、顶栏和通用卡片使用语义色。
- [x] 主题色驱动 Material 主色及桌面选中状态；默认蓝色保持参考图效果。
- [x] 中英文 Material locale 和桌面主导航/页面标题联动。
- [x] 配置目录、内核目录、日志目录指向不同真实路径；Telegram/GitHub 使用真实入口。
- [x] 设置变更按“需要重启核心/无需重启”统一判定，失败时恢复旧设置和运行态。
- [x] 首页和测试页按当前模式使用直连/系统代理/TUN，显示路径、HTTP 状态、耗时和错误。
- [x] 自定义测试项持久化，支持恢复默认及剪贴板导入/导出。
- [x] IP 信息使用 HTTPS 主备服务，网络模式和节点切换后立即刷新。
- [x] Merge 深度合并、规则前后插入、Script 受限 DSL、验证和失败回滚已进入真实运行配置。
- [x] 订阅刷新后弹出完整结构化 diff，包含节点、代理组、规则、流量、到期时间和全部增删节点。
- [x] 自动刷新具有并发控制、指数退避、网络恢复重试及最近成功/失败时间。
- [x] 备份恢复支持替换/合并、去重、预校验和事务回滚。
- [x] 接入 mihomo `/logs` NDJSON 实时流并进行上限控制和脱敏。
- [x] 更新缓存和版本修正为 `1.0.0`，产品入口明确为“仅检查更新”。
- [x] 内核版本从打包 mihomo 的 `-v` 输出读取。
- [x] 桌面核心意外退出按 1/2/4 秒退避自动重启，最多三次。
- [x] 后台实时请求成功后清除历史网络异常。
- [x] 首页流量、内存、连接、规则、IP、连接页数据均来自 mihomo 实时 API。
- [x] macOS 开机自启通过 `launchctl bootstrap/bootout` 真实注册/注销，重复实例会唤醒已有窗口后退出。
- [x] 新增可预览、显式执行的数据保留/彻底清理卸载脚本 `tools/uninstall_macos.sh`。
- [x] 发布脚本按 App 公证→staple→DMG→DMG 公证→staple 顺序执行，并验证 Gatekeeper。

## P2 — 已完成的工程项

- [x] 控制器销毁会取消流量、节点健康、订阅、IP、重启定时器和核心日志流；异步回调不再通知已销毁 UI。
- [x] macOS 系统版本使用 `sw_vers`；侧栏内存绑定 `controller.memoryMb`。
- [x] 订阅、连接、规则、日志、测试、设置的参考布局和稳定 golden 已接入测试。
- [x] 更新检查、主题/语言、Merge/Script、备份、macOS 解析恢复、Windows 注册表恢复具有自动化测试。
- [x] 真实打包 mihomo 契约冒烟覆盖 `/version`、`/proxies`、`/traffic`、`/memory`、`/connections`、`/rules`、`/logs` 流入口和模式切换。
- [x] `PLAN.md`、README、构建文档统一为 `960 × 720`、`1.0.0` 和当前产物状态。
- [x] 发布检查清单已建立：`docs/desktop-release-checklist.md`。

## 仍需目标环境执行的验收（实现已完成）

### P0 外部发布凭据

- [ ] 使用 Apple Developer ID 与公证 Keychain profile 运行 `tools/build_macos.sh`，完成 Hardened Runtime、公证、staple 和 Gatekeeper 验证。
- [ ] 当前机器只具备 ad-hoc 签名条件；签名脚本和检查流程已经就绪。

### P0 真机矩阵

- [ ] 全新 macOS 用户留存发布验收证据：系统代理、TUN、强退恢复、睡眠唤醒、Wi-Fi/有线切换、取消提权、卸载。
- [ ] Windows 10/11 x64：CI 产物安装、系统代理、Wintun、恢复、开机/静默启动、升级、卸载。
- [ ] Windows 100%/125%/150% DPI、多屏及负坐标屏幕。
- [ ] Ubuntu 22.04/24.04 与 KDE Plasma 真机执行系统代理、TUN、强退恢复、开机自启、DEB 升级和卸载验收。
- [ ] 使用真实验收订阅执行出口变化、节点延迟和连续代理测试。
- [ ] 8 小时/24 小时持续运行，留存内存、句柄、进程、定时器和日志增长记录。

## 后续版本路线（不属于 1.0.0 未完成项）

- Windows arm64。
- Linux arm64 与 RPM/AppImage 发布格式。
- 多内核版本管理、升级和回退。
- 配置同步与加密导入导出包。
- 可扩展测试模板和规则/脚本插件体系。

## 当前质量基线

最终自动化、DMG 哈希和构建结果见 `docs/desktop-verification.md` 与根目录 `VERIFICATION.txt`。
