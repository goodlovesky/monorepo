# Clash RS 桌面端验证记录

> 日期：2026-08-24
> 分支：`feature/mihomo-desktop`
> 应用：Clash RS `1.0.0`，固定窗口 `960 × 720`

## 已验证功能

- 共用 Flutter 桌面壳与八个页面。
- URL、剪贴板和文件订阅导入；校验、原子保存、激活、重命名、删除、刷新及 last-known-good 回滚。
- 代理组、模式/节点持久化、单节点与全部测速、运行节点周期健康检查。
- mihomo 实时流量、内存、连接、规则、日志和出口 IP。
- 系统代理/TUN 三态切换、动态控制端口、Merge/Script 运行配置。
- 设置重启判定、失败回滚、备份替换/合并事务。
- macOS 网络快照聚合恢复、进程身份恢复、按次管理员授权、TUN watchdog、睡眠/网络恢复。
- Windows 注册表快照/恢复、WinINet 广播、Wintun 配置、托盘、单实例和 CI 打包任务。

## 自动化结果

### BASELINE

```text
命令：cd $PROJECT_ROOT/app && flutter analyze && flutter test
结果：
No issues found! (ran in 2.9s)
00:12 +72: All tests passed!
退出状态：0
```

### MODIFIED

```text
命令：cd $PROJECT_ROOT/app && flutter analyze && flutter test
结果：
No issues found! (ran in 3.0s)
00:13 +88: All tests passed!
退出状态：0
```

新增验证包括 macOS 按次管理员授权、PID 身份防复用、TUN 清理、外部核心 watchdog、睡眠/网络恢复、LaunchAgent 和公证顺序契约。

## 真实 mihomo 契约冒烟

打包资源 `app/macos/Runner/Resources/mihomo` 使用临时 DIRECT 配置启动，结果：

```text
proxies HTTP 200
connections HTTP 200
rules HTTP 200
traffic HTTP 200 {"up":0,"down":0,"upTotal":0,"downTotal":0}
memory HTTP 200 {"inuse":0,"oslimit":0}
logs stream endpoint opened
mode-switch HTTP 204
version {"meta":true,"version":"v1.19.30"}
```

## macOS 发布产物

- DMG：`$PROJECT_ROOT/dist/macos/Clash-RS-macOS.dmg`
- SHA-256：`919197ae9ab885ca12de9fb7a52e0ef405b1f6d82f73aba421c4a3e6a8455fb4`
- `hdiutil verify`：checksum VALID
- App、mihomo：均为 `x86_64 + arm64`；Release 包不含永久 helper
- App 深度签名验证：valid on disk / satisfies Designated Requirement
- 当前签名：ad-hoc；TeamIdentifier 未设置
- Release 启动冒烟：进程成功运行

## Windows 构建

Windows x64 构建任务位于 `.github/workflows/desktop-windows.yml`，会生成：

- `ClashRS-1.0.0-windows-x64-portable.zip`
- `ClashRS-Setup-1.0.0-x64.exe`
- `BUILD-MANIFEST.json`
- `SHA256.txt`
- `BUILD-ENVIRONMENT.txt`

构建任务固定校验 mihomo `v1.19.30` 和 Wintun `0.14.1`，并在临时目录执行安装、关键文件检查和静默卸载。
- `BUILD-ENVIRONMENT.txt`

macOS 主机不执行 Windows 二进制。安装和 Wintun 验收按 `docs/desktop-release-checklist.md` 在 Windows 10/11 完成。

## 外部闭环

- Apple Developer ID、公证和 staple 需要发布证书与 Keychain profile。
- 新用户、睡眠唤醒、网络切换、Windows DPI/多屏、8/24 小时持续运行需要目标环境留存结果。
