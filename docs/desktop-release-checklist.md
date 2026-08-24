# Clash RS 1.0.0 桌面发布检查清单

## 共同检查

- [x] 应用名称统一为 **Clash RS**，应用版本 `1.0.0`。
- [x] 固定客户端窗口 `960 × 720`，禁止最大化和用户缩放。
- [x] Flutter 静态分析和完整测试通过。
- [x] 控制端口由单一设置源驱动，默认 `9090`。
- [x] 订阅、Merge、Script、备份、日志、实时流量、连接和出口 IP 已连接运行数据。
- [x] 更新入口明确为“仅检查更新”，不暗示自动安装。
- [ ] 使用带真实节点的验收订阅完成系统代理和 TUN 出口测试。
- [ ] 在 8 小时和 24 小时持续运行后记录内存、句柄、日志大小和异常重启次数。

## macOS

- [x] 当前源码生成 Universal App 和 DMG。
- [x] App、mihomo、特权 helper 均包含 `arm64` 与 `x86_64`。
- [x] DMG 校验通过并生成 SHA-256。
- [x] Release App 不包含永久 setuid helper；旧开发版 helper 由卸载脚本显式清理。
- [x] TUN 使用固定打包 mihomo 的按次管理员授权，并验证 PID 身份与清理状态。
- [ ] 使用 `Developer ID Application` 签名并启用 Hardened Runtime。
- [ ] 使用 Apple 公证凭据提交、staple，并通过 Gatekeeper 检查。
- [ ] 在全新 macOS 用户账户完成安装、代理/TUN、强退恢复、睡眠唤醒、网络切换和卸载。

签名构建：

```bash
SIGN_IDENTITY="Developer ID Application: …" \
NOTARY_PROFILE="ClashRS" \
./tools/build_macos.sh
```

## Windows x64

- [x] 版本化便携包、Inno Setup 安装包、构建清单、SHA-256 和构建环境脚本已实现。
- [x] mihomo 与 Wintun 固定版本、下载哈希校验和运行资源记录已实现。
- [x] 安装器覆盖升级、旧进程优雅清理、安装/卸载流程已实现。
- [x] GitHub Actions Windows x64 构建、资源校验、临时安装和静默卸载任务已加入仓库。
- [x] 注册表快照、恢复与 WinINet 广播具有自动化测试。
- [ ] 在 Windows 构建任务生成并下载实际产物。
- [ ] Windows 10/11 完成系统代理、Wintun、崩溃恢复、启动/退出、升级和卸载测试。
- [ ] 完成 100%/125%/150% DPI、多屏和负坐标显示器截图验收。

CI 手动入口：`.github/workflows/desktop-windows.yml`。
