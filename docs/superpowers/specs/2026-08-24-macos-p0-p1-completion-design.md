# Clash RS macOS P0/P1 完成设计

日期：2026-08-24  
分支：`feature/mihomo-desktop`  
批准来源：用户在 macOS 未完成项审计后明确要求完成全部 P0 与 P1。

## 目标

完成 macOS 发布前的网络接管、恢复、进程身份、生命周期、开机启动和签名打包闭环，同时保留固定 `960 × 720` Flutter UI 与现有配置格式。

## 方案比较

### A. 永久 setuid helper 加固

继续安装 `4755 root` helper，限制参数、固定二进制路径并保存 root-owned PID 文件。

优点：启停 TUN 较少出现授权提示。  
缺点：任何本地用户都能调用永久 root 程序；代码审计和升级/卸载负担最大。

### B. SMAppService / XPC 特权服务

使用 Apple 官方特权服务、代码签名 requirement 和 XPC 协议。

优点：正式发布架构最佳。  
缺点：实现量大，依赖 Developer ID 签名和完整 XPC 工程；当前机器缺少对应发布证书，无法形成可验证闭环。

### C. 按次管理员操作（采用）

删除永久 setuid 安装流程。TUN 启动和停止通过固定、完整转义的管理员命令执行；只允许打包的 mihomo、运行配置和日志路径。每次终止前验证 PID、可执行路径和进程启动标识。

优点：当前环境可完整测试；不存在长期驻留的通用 root 入口；卸载无需清理 setuid 文件。  
代价：TUN 首次启动以及缓存失效后的停止可能再次出现管理员提示。

## 组件设计

### MacNetworkService

- TUN 启动前保存基线 utun 接口、控制端口和进程身份。
- 使用固定 bundled mihomo 路径启动管理员进程，解析真实 PID。
- 恢复文件保存 PID、可执行路径、启动标识、控制端口和基线 utun。
- 停止前核对 PID 身份；身份不匹配时禁止发送信号。
- TERM 超时后使用 KILL；验证 PID、控制端口和新 utun 接口全部消失后才删除恢复文件。
- 系统代理逐项恢复，单个服务失败不阻断其他服务，最终汇总失败项。

### 外部 TUN 看门狗

- 实时 API 连续三次失败才判定外部核心失联，避免瞬时抖动。
- Controller 通过异步回调通知 DesktopApp。
- DesktopApp 串行执行 TUN restore → enableTun → attachExternalEngine。
- 最多三次，使用 1/2/4 秒退避；达到上限保留错误和恢复文件。

### macOS 生命周期

- AppDelegate 监听睡眠、唤醒和网络路径变化。
- 通过现有 lifecycle MethodChannel 通知 Flutter。
- 睡眠只暂停刷新；唤醒/网络恢复后检查控制 API，刷新节点与出口；TUN 失联时走统一看门狗恢复。

### 开机启动与卸载清理

- 写入 LaunchAgent 后执行当前 GUI session 的 `launchctl bootstrap`。
- 关闭时执行 `bootout` 后删除 plist。
- 新增 macOS 清理入口，停止网络、移除 LaunchAgent、删除旧版遗留 setuid helper 和恢复标记。

### 发布打包

- 默认 ad-hoc 包继续用于本地测试。
- 正式流程：签名 App → 公证临时 ZIP → staple App → 创建 DMG → 公证 DMG → staple DMG → Gatekeeper 验证。
- 文档明确 Release 未启用 App Sandbox，最低系统为 macOS 12。

## 错误与恢复

- 所有恢复失败均保留 JSON 恢复文件。
- PID 身份冲突显示明确错误，不终止未知进程。
- 生命周期恢复由互斥锁串行化，重复事件合并。
- 退出时优先恢复网络，再终止应用。

## 测试

- macOS 代理聚合恢复和含空格服务名。
- PID 身份序列化与匹配。
- TUN 恢复文件、utun 差异和控制端口检查。
- 外部核心连续失败阈值、退避和重复事件合并。
- LaunchAgent bootstrap/bootout 命令契约。
- Flutter analyze、完整测试、Release build、DMG 校验和启动冒烟。
