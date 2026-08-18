# Android Clash Meta 五页完整还原设计

日期：2026-08-18  
状态：已确认  
基准截图：`$HOME/Downloads/aa1001.jpg` 至 `aa1005.jpg`

## 1. 目标

在不破坏现有 Android `VpnService` 全设备接管、clash-rs 0.9.7 和 VLESS Reality 节点能力的前提下，完整还原五张 1080×2412 截图中的视觉、导航与功能：主页、代理页、配置列表页、创建配置页和配置编辑页。

“完整还原”同时包含：

- 像素级接近截图的颜色、字号、字距、圆角、间距、双列布局、选中态和系统栏样式。
- 真实 VPN 启停、流量统计、代理组浏览、节点选择和延迟测试。
- 配置创建、URL 下载、文件导入、二维码扫描、保存、刷新、启用、编辑和删除。
- 配置切换时正确协调 Clash 核心、TUN 文件描述符与 Android VPN 生命周期。

## 2. 范围

### 2.1 本次实现

1. 主页视觉和交互重建。
2. 代理页分组、节点卡片、选择和测速。
3. 配置仓库和配置列表。
4. URL、文件、二维码三类导入。
5. 配置编辑、校验、保存、更新和删除。
6. 运行配置生成、VPN 重启和状态恢复。
7. Flutter 单元/Widget 测试、APK 构建和 Android 真机逐页测试。

### 2.2 明确边界

- 第一版以 Android 为完整功能平台。
- TUN 接管继续采用 IPv4 默认路由；IPv6维持不可达，避免泄漏。
- 二维码支持订阅 URL，以及 VLESS、VMess、Trojan、Shadowsocks 单节点链接。
- 导入内容必须最终转换为 Clash YAML，并通过核心解析校验。
- 截图中的节点名称和流量数据仅作为布局参考，实际页面展示当前配置的真实数据。

## 3. 架构

当前 `main.dart` 超过 1300 行。重建时保留入口，但把状态、页面、服务和复用组件分离：

```text
lib/
├── main.dart
├── app/
│   ├── app_routes.dart
│   └── app_theme.dart
├── features/
│   ├── home/home_page.dart
│   ├── proxy/
│   │   ├── proxy_page.dart
│   │   └── proxy_category.dart
│   └── profile/
│       ├── profile_list_page.dart
│       ├── profile_create_page.dart
│       └── profile_edit_page.dart
├── models/
│   └── proxy_profile.dart
├── services/
│   ├── profile_import_service.dart
│   ├── profile_repository.dart
│   └── proxy_runtime_service.dart
└── widgets/
    ├── clash_header.dart
    ├── screenshot_app_bar.dart
    └── screenshot_card.dart
```

### 3.1 边界

- `ProxyRuntimeService`：唯一负责核心、VPN、运行配置和状态同步。
- `ProfileRepository`：唯一负责配置元数据和 YAML 文件持久化。
- `ProfileImportService`：唯一负责下载、识别、转换和校验导入数据。
- 页面只调用服务公开接口，不直接操作文件描述符或散落读写 JSON。
- 现有 `ClashBridge`、`ClashController`、`VpnController` 继续作为底层适配器。

## 4. 视觉系统

### 4.1 基准与响应式规则

- 基准画布：1080×2412。
- Flutter 使用逻辑像素布局，并按照可用宽度计算统一缩放系数。
- 小屏保持内容比例；节点页和菜单页允许纵向滚动。
- 系统状态栏、导航栏使用 `#101010` 背景和浅色图标。

### 4.2 色彩

| 角色 | 色值 |
|---|---|
| 页面背景 | `#101010` |
| 主卡片 | `#202020` |
| 次级卡片 | `#2D2D2D` |
| 选中蓝 | `#237FD5` |
| 主文字/图标 | `#F4F4F4` |
| 次级文字 | `#A7A7A7` |
| 分隔线 | `#6C6C6C` |

### 4.3 字体与图标

- 中文标题和正文使用 Android 系统中文衬线回退链。
- 英文标题和数据使用衬线体，并保留截图中的宽字距。
- Material 图标选择最接近截图轮廓的实心/线性变体。
- 首页 Clash 猫标使用本地矢量绘制，避免位图缩放失真。
- 不增加渐变、额外阴影、动画和截图之外的装饰。

## 5. 页面设计

### 5.1 主页

- 顶部为 Clash 猫标和 `Clash Meta for Android`。
- 运行卡片：停止时深灰，运行时蓝色；点击同时启停 VPN 与核心；副文本显示累计转发量。
- 代理卡片：显示“代理 / 规则模式”，点击进入代理页。
- 配置卡片：显示当前配置名称或“新配置 已激活”，点击进入配置页。
- 日志、设置、帮助、关于按截图排列。
- 运行状态只有在核心运行且 Android VPN 存在时才显示“运行中”。

### 5.2 代理页

- 顶部返回、批量测速和更多菜单。
- 横向标签对应真实代理组；当前标签蓝色并带底部指示条。
- 节点采用两列等宽卡片；当前节点整卡蓝色。
- 卡片显示节点名、协议和延迟；未测速为 `—`，失败为“超时”。
- 点击节点调用 Clash Controller，接口成功后才更新选中态。
- 测速任务限制并发，避免大量瞬时连接。

### 5.3 配置列表页

- 顶部返回、刷新全部、创建配置。
- 每张配置卡片显示名称、来源类型、已用/总流量、到期时间和上次更新相对时间。
- 左侧单选环表示当前配置；右侧菜单包括启用、更新、编辑、删除。
- 删除当前配置前必须选择另一配置；仓库至少保留一个可运行配置。

### 5.4 创建配置页

- 文件、URL、QR Code 三个入口与截图一致。
- 文件入口调用系统文件选择器，仅接受 YAML/YML 和可解析文本。
- URL 入口进入配置编辑页并聚焦 URL 字段。
- QR Code 请求相机权限，扫描后进入确认/编辑流程。

### 5.5 配置编辑页

- 顶部返回、标题“配置”和保存按钮。
- 信息提示：仅接受包含代理/规则的 Clash 配置。
- 字段：名称、URL、自动更新周期、浏览文件。
- 保存前执行下载或文件读取、内容识别、Clash YAML 转换和核心解析。
- 保存成功返回配置列表并高亮新配置；用户明确启用前不改变正在运行的配置。

## 6. 配置模型与存储

```text
ProxyProfile
- id: String
- name: String
- sourceType: bundled | url | file | qr
- source: String?
- localYamlPath: String
- createdAt: DateTime
- updatedAt: DateTime
- lastCheckedAt: DateTime?
- autoUpdateIntervalMinutes: int?
- usedTrafficBytes: int?
- totalTrafficBytes: int?
- expiresAt: DateTime?
- active: bool
```

存储：

```text
<ApplicationSupport>/profiles/index.json
<ApplicationSupport>/profiles/<id>/config.yaml
<ApplicationSupport>/profiles/<id>/runtime-config.yaml
```

写入采用临时文件加原子替换，避免中断造成配置损坏。首次启动时把现有 `config.yaml` 迁移为默认配置，并保持现有用户节点不变。

## 7. 导入与转换

### 7.1 URL

1. 验证 `http`/`https`。
2. 下载并限制响应大小、超时和重定向次数。
3. 读取订阅流量、到期信息等响应头。
4. 依次识别 Clash YAML、Base64 订阅、单节点 URI。
5. 转换并校验 Clash YAML。
6. 保存配置和元数据。

### 7.2 文件

1. 系统选择文件。
2. 读取文本并识别格式。
3. 复制到应用私有目录。
4. 校验后写入仓库。

### 7.3 二维码

- URL：沿用 URL 导入。
- 单节点 URI：生成包含 `PROXY` 选择组和 `MATCH,PROXY` 规则的完整配置。
- 其他文本：显示可执行的格式错误提示并保留扫描结果供复制。

## 8. 配置切换和 VPN 生命周期

运行中切换配置：

1. 停止流量轮询。
2. 停止 Clash 核心。
3. 停止 Android VPN 并关闭 TUN。
4. 校验目标配置并更新 active 元数据。
5. 建立新的 Android `VpnService` TUN。
6. 生成带 `fd://<fd>`、DNS 和 IPv4 TUN 的运行配置。
7. 启动 Clash 核心并提交 FD 所有权。
8. 检查控制器和 VPN 状态。
9. 恢复流量轮询与 UI。

停止状态切换配置只更新 active 元数据，不自动启动。

任何阶段失败都执行核心和 VPN 清理，并保留上一个已验证配置；页面显示失败原因和重试入口。

## 9. 错误与空状态

- 下载失败：显示 HTTP 状态或网络错误，并提供重试。
- 格式错误：指出“不包含有效代理/代理组/规则”中的具体项目。
- 文件访问失败：提示重新选择文件。
- 扫码权限关闭：提供前往系统设置入口。
- 测速失败：单节点显示“超时”，不阻断其他节点。
- 配置列表为空：自动建立内置默认配置，不出现无操作入口的空白页。
- 核心意外退出：自动停止 VPN，主页切回“已停止”。

## 10. 测试与验收

### 10.1 自动测试

- 配置模型 JSON 往返。
- 元数据原子写入和迁移。
- Clash YAML、Base64 和单节点 URI 识别。
- 运行配置的 TUN/DNS 覆盖。
- 五页导航、双列节点、配置选中态和表单校验 Widget 测试。
- Flutter analyze/test、Rust workspace test、Android APK 构建。

### 10.2 真机验收

设备 `WKGET4CAT4YPTSC6`：

1. 五个页面逐页截图，与参考图按 1080×2412 视觉比较。
2. 启动后确认 `VPN CONNECTED`、`tun0 198.18.0.1/24`、默认 IPv4 路由。
3. Chrome 查询出口为 `203.0.113.10`，系统全局 HTTP 代理保持 `null`。
4. 节点选择和延迟测试真实生效。
5. URL、文件、二维码各完成一次真实导入。
6. 配置切换后 VPN 与核心使用新配置。
7. 停止后 VPN 和 TUN 消失；再次启动恢复。

## 11. 回滚

实施前保存本次涉及文件的 SHA-256 和原始副本。交付时生成：

- `MODIFIED_FILE`
- `DIFF_FILE`
- `VERIFICATION.txt`
- 可执行 `ROLLBACK.sh`

回滚脚本先在隔离副本验证原文件哈希恢复和新增文件删除，真实工作树保留完成后的修改。
