# mihomo 桌面集成记录

状态：已实现。Android 保留 Rust FFI/VpnService；macOS 与 Windows 桌面路径统一使用 mihomo `127.0.0.1:9090` REST API。

## 已交付

- 普通模式由 `ProxyAppController` 启动/停止 bundle mihomo，生成运行配置、检查端口、保存 PID、检测意外退出。
- macOS TUN 对 App 内固定 mihomo 按次请求管理员权限；Windows TUN 使用 mihomo + 官方 Wintun DLL。
- `/proxies`、节点选择、代理模式、测速、`/traffic`、连接、规则、版本和健康检查已接入。
- 系统代理与 TUN 三态互斥，失败回滚；网络状态在启动前快照并在停止/退出/异常恢复时还原。
- AnyTLS 等 mihomo 支持协议在桌面运行配置中保持原样。
- macOS arm64/x86_64 的 Flutter executable、helper、mihomo 均为通用架构；Windows x64 构建脚本输出安装包和便携包。

## 关键实现

- `app/lib/services/proxy_app_controller.dart`
- `app/lib/services/mihomo_client.dart`
- `app/lib/core/vpn/vpn_controller.dart`
- `app/lib/platform/macos/mac_network_service.dart`
- `app/lib/platform/windows/windows_network_service.dart`
- `app/lib/platform/macos/mac_network_service.dart`
- `tools/download_mihomo.sh`
- `tools/download_mihomo_windows.ps1`
- `tools/build_macos.sh`
- `tools/build_windows.ps1`

## 验证

```bash
cd app && flutter analyze && flutter test
cd .. && RUSTC_BOOTSTRAP=1 cargo test --workspace
./tools/build_macos.sh
```

分发验证同时检查 App 签名、DMG 校验、三份 Mach-O 的 `x86_64 arm64` 架构，以及 bundle mihomo 的 9090 API和 mixed-port 代理链路。
