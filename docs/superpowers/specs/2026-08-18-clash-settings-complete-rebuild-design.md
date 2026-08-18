# Clash Meta Android 设置模块完整重建设计

## 目标

以 `bb10003`—`bb10011` 为视觉和交互基准，重建设置主页及“应用、网络、覆写、Meta 特性”四个子页面。界面保持当前黑色背景、Noto Serif CJK 字体、蓝色分组标题、截图比例与滚动密度；每个可操作项必须真实持久化或执行对应系统/配置动作。

## 架构

- `AppSettings`：不可变设置模型，覆盖应用行为、VPN 网络选项、Clash 覆写字段与 Meta 扩展字段。
- `SettingsRepository`：在 Application Support 下用原子 JSON 文件保存设置，首次启动写入与截图一致的默认值。
- `ProxyAppController`：加载、更新和通知设置；运行中修改网络或配置项时按需停止并重启 VPN/Core。
- `VpnController` / Android MethodChannel：把绕过私网、DNS 劫持、允许应用绕过、IPv6、系统 HTTP 代理、访问控制和应用可见性传给 `VpnService.Builder`。
- Flutter 页面：设置首页负责导航；应用/网络页用开关和选择器；覆写/Meta 页用通用可编辑字段列表、分组标题、重置按钮和文件导入。

## 页面与行为

### 设置主页

四个大行：应用、网络、覆写、Meta 特性。点击进入对应页面，位置、图标、字号和留白按截图还原。

### 应用

- 自动重启：持久化；核心意外退出时重新拉起。
- 暗黑模式：提供“跟随系统/暗黑”选择，默认跟随系统。
- 隐藏应用图标：调用 Android PackageManager 启停 launcher component。
- 从最近任务隐藏：调用 Activity 的 `excludeFromRecents` 标记。
- 显示流量：控制 VPN 前台通知是否显示累计流量。

### 网络

- 自动路由系统流量、绕过私网、DNS 劫持、允许应用绕过、IPv6、系统代理。
- Stack Mode：System/GVisor/Mixed 选择并写入运行时 Clash TUN 配置。
- 访问控制模式：允许所有/仅允许列表/排除列表；应用包列表保存并传给 Android VPN builder。
- 影响 TUN 的选项在 VPN 运行时修改后自动重启，使真实路由立即生效。

### 覆写

- 提供截图中的 HTTP/Socks/Redirect/TProxy/Mixed 端口、认证、LAN、IPv6、监听地址、External Controller/TLS/CORS/私网、Secret、模式、日志级别、Hosts、DNS 等字段。
- 每项点击打开编辑器；空值显示“不修改”。
- 顶部重置按钮清空全部覆写。
- 保存后生成运行时配置覆写，不直接破坏导入的原配置文件。

### Meta 特性

- 域名强制解析、跳过域名、跳过源/目标 IP。
- GeoIP/GeoSite/Country/ASN 数据库文件导入到应用支持目录。
- 统一延迟、Geodata 模式、TCP 并发、进程查找、嗅探策略及 HTTP/TLS 端口字段。
- DNS 分组包含策略、H3、监听、追加系统 DNS、IPv6、Hosts、增强模式、Name Server/Fallback 等字段。
- 顶部重置按钮恢复默认“不修改”。

## 错误处理

- 设置写入采用临时文件后 rename；失败保留旧文件并在页面 Snackbar 显示错误。
- Android 参数非法时 MethodChannel 返回明确错误，控制器恢复停止状态。
- 文件导入校验存在性和大小，复制失败不改变现有数据库。
- 配置字段为空表示不覆写；端口验证为 `1..65535`。

## 验证

- 模型 JSON 往返、默认值、持久化、运行时 YAML 生成单测。
- `flutter analyze`、全部 Flutter 测试、Rust core 测试、debug APK 构建。
- 真机验证四级页面、开关持久化、运行中 VPN 重启、`tun0` 全局路由、出口 IP、通知流量和恢复默认。
- 保存原 APK/哈希，生成差异、验证记录和可执行回滚脚本；在隔离副本测试回滚。
