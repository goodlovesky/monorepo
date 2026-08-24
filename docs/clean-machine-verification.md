# Clash RS 桌面端 — 干净机器验证手册

> 适用平台：macOS 14+（arm64/x86_64）、Windows 10/11 x64
> 验证目标：全新机器完成「安装 → 导入 → 启动 → 代理 → 停止 → 异常恢复 → 卸载」闭环

---

## 1. 环境准备

### 1.1 工具链要求

| 工具 | macOS | Windows |
|---|---|---|
| Xcode / Command Line Tools | 15+ | — |
| Rust toolchain | 桌面包不需要 | stable 1.91+ |
| Flutter | 3.47+ | 3.47+ |
| Java | — | 17+ |
| Android NDK | — | Flutter bundled |
| cmake | — | 3.21+ |
| 管理员权限 | 启动 TUN 模式时需要 | 启动 TUN/WinTun 时需要 |

### 1.2 macOS 编译步骤

```bash
# 打包 mihomo、签名 App 并生成 DMG；永久 setuid helper 已移除。
./tools/build_macos.sh
```

### 1.3 Windows 编译步骤

```powershell
.\tools\build_windows.ps1 -Clean            # 生成 portable zip
.\tools\build_windows.ps1 -Installer -Clean # 生成安装包、清单和 SHA-256
```

---

## 2. 干净机器安装

### 2.1 macOS

```bash
# 1. 下载 DMG
curl -L -O https://example.com/Clash-RS-macOS.dmg
shasum -a 256 Clash-RS-macOS.dmg  # 对照 SHA256.txt 校验

# 2. 挂载 DMG
hdiutil mount Clash-RS-macOS.dmg

# 3. 拖拽 Clash RS.app 到 /Applications
# （或 cp -R "/Volumes/Clash RS/Clash RS.app" /Applications/）

# 4. 卸载 DMG
hdiutil unmount "/Volumes/Clash RS"
```

### 2.2 首次启动

1. 打开「系统设置 → 隐私与安全性」，确认「Clash RS」已被允许打开
2. 双击启动 Clash RS.app
3. macOS 弹出 Gatekeeper 提示时选「打开」

> **release 模式已知 bug**（已修复）：`AppDelegate.applicationDidFinishLaunching`
> 在 Swift 5 + Whole Module Optimization 下可能被去 `@objc` 元数据，导致
> `NSNotificationCenter` 找不到 selector 抛 "unrecognized selector" 异常。
> 修复方式：方法加 `@objc override` 显式声明，并把自定义初始化逻辑
> （菜单栏、MethodChannel）延后到下一个 runloop async 块中执行。

### 2.3 数据存储路径

macOS App Sandbox 默认开启，应用数据写到容器内：

```
~/Library/Containers/com.proxyapp.app/Data/Library/Application Support/com.proxyapp.app/
├── config.yaml            # 默认配置（启动时如不存在会写默认）
├── settings.json          # AppSettings 持久化
├── profiles/
│   ├── index.json         # 订阅列表
│   └── <profile-id>/
│       └── config.yaml    # 每个订阅的 YAML
├── geo/                   # 导入的 GeoData 文件
└── network-recovery.json  # 网络恢复标记（snapshot + helper PID）
```

> **注意**：路径在 release 模式下是 sandbox container；debug 模式下因为 entitlements
> 不同，可能直接写到 `~/Library/Application Support/com.proxyapp.app/`。要清理数据时
> 两个位置都要查。

---

## 3. 核心功能验证清单

### 3.1 窗口与导航（P0 阶段 A）

- [ ] 窗口尺寸严格 `960 × 720`，无放大/缩放
- [ ] 左侧 8 个图标（首页/代理/订阅/连接/规则/日志/测试/设置）全部可见，无需滚动
- [ ] 每个页面都可通过侧栏切换，无 RenderFlex 溢出
- [ ] macOS 上窗口在最大可用屏幕居中
- [ ] DPI 100% / 125% / 150% 下界面均正常（macOS：系统设置 → 显示器）

### 3.2 配置导入（P0 阶段 B）

- [ ] **URL 导入**：订阅页输入 `https://...` → 导入成功，列表多一项
- [ ] **剪贴板导入**：复制 URL → 点剪贴板按钮 → 填到输入框 → 导入
- [ ] **文件导入**：点文件按钮 → 选 `.yaml` → 导入
- [ ] **剪贴板 YAML 导入**：复制一段 Clash YAML → 粘贴 → 导入
- [ ] **VLESS 链接导入**：粘贴 `vless://...` → 自动生成 PROXY 组
- [ ] **YAML 校验失败**：粘贴不含 `proxies` 段的 YAML → 显示错误，旧配置不丢失
- [ ] **空 proxies 列表**：粘贴 `proxies: []` → 显示「proxies 列表为空」错误
- [ ] **重复节点名**：粘贴两个同名节点的配置 → 显示「重复的节点名」错误
- [ ] **代理组自引用**：粘贴 `proxy-groups` 引用自身 → 显示「不能引用自身」错误
- [ ] **激活**：点非激活配置卡片的「激活」按钮 → 切换激活状态
- [ ] **重命名**：菜单选重命名 → 改名成功
- [ ] **删除**：至少保留一个配置；删除最后一个会失败

### 3.3 订阅刷新与自动刷新（P0 阶段 B）

- [ ] **手动刷新**：URL 配置点「更新」按钮 → 下载最新配置
- [ ] **刷新失败保留旧配置**：拔网线 → 手动刷新 → 显示「刷新失败（已保留旧配置）」
- [ ] **订阅卡显示失败标记**：刷新失败后订阅卡显示红色「上次刷新失败：xx:xx」
- [ ] **自动刷新**：开启「每 N 分钟」自动刷新（`autoUpdateIntervalMinutes`）→ 后台定时触发
- [ ] **到期时间**：订阅含 `subscription-userinfo: expire=...` → 订阅卡显示到期时间
- [ ] **流量**：订阅含 `subscription-userinfo: upload=...;download=...;total=...` → 显示进度条

### 3.4 代理与网络接管（P0 阶段 C）

#### 3.4.1 系统代理模式

- [ ] **开启系统代理**：点「系统代理」按钮 → 弹出 sudo 授权 → 完成后状态变绿
- [ ] **验证出口变化**：
  - 关闭代理时 `curl -I https://google.com` 走默认出口
  - 开启系统代理后 `curl -I https://google.com` 走代理出口
- [ ] **关闭恢复**：点「关闭」按钮 → 系统代理恢复启用前的状态
  - macOS: `networksetup -getwebproxy Wi-Fi` 应显示原状态
- [ ] **快速切换**：1s 内连续点 systemProxy → off → systemProxy → 无残留

#### 3.4.2 虚拟网卡模式

- [ ] **开启 TUN**：点「虚拟网卡」按钮 → 弹出 sudo 授权 → 等待 5-10s → 状态变绿
- [ ] **验证 TUN 接管**：所有 app 的网络请求都走代理（浏览器、Terminal 均可验证）
- [ ] **路由表检查**：`netstat -rn | grep utun` 应显示 clash-rs 添加的路由
- [ ] **DNS 劫持**：`scutil --dns | grep nameserver` 应显示 fake-ip（198.18.x.x）
- [ ] **关闭 TUN**：点关闭 → 路由/DNS 恢复 → 网络正常
- [ ] **TUN 启动超时**：故意删 helper 进程 → 启动 TUN → 应在 15s 内报错而不是卡死

#### 3.4.3 三态互斥

- [ ] **systemProxy → TUN**：先开 systemProxy，再开 TUN → systemProxy 先关闭，TUN 启动
- [ ] **TUN → systemProxy**：先开 TUN，再开 systemProxy → TUN 先关闭，systemProxy 启动
- [ ] **快速连点**：1s 内点 5 次切换按钮 → 最终状态 = 最后一次请求，不卡死
- [ ] **失败回滚**：故意让 sudo 取消 → 状态应回滚到切换前

### 3.5 节点与代理模式（P0 阶段 B + C）

- [ ] **节点选择**：代理页选节点 → 状态变蓝色边框
- [ ] **选择持久化**：选节点 → 关 app → 重开 → 节点仍生效
- [ ] **模式切换**：规则/全局/直连三选一 → 立即生效，状态显示在侧栏
- [ ] **模式持久化**：切换全局 → 关 app → 重开 → 仍是全局
- [ ] **单节点测速**：点节点卡片右下角测速按钮 → 显示延迟或失败
- [ ] **分组测速**：代理页右上「全部测速」→ 测试当前分组所有节点
- [ ] **测速取消**：测试中点「取消」→ 立即停止，不再写入结果
- [ ] **超长测速**：500+ 节点配置下，UI 不卡顿

### 3.6 首页流量与诊断（P1 阶段 D）

- [ ] **实时速度**：下载文件时上传/下载速度 > 0
- [ ] **累计流量**：开始时 0，运行 1h 后非零
- [ ] **连接数**：浏览器访问网页时连接数 > 0
- [ ] **折线图**：上下行曲线绘制最近 N 个采样点
- [ ] **停止清零**：点停止 → 速度和流量都归零
- [ ] **网络测试**：点「网络测试」按钮 → 1-3s 返回结果
- [ ] **IP 信息**：自动或手动刷新 → 显示 IP/国家/ASN
- [ ] **Clash 信息**：核心版本号、运行时间显示
- [ ] **系统信息**：macOS 版本、运行模式、版本号

### 3.7 连接/规则/日志（P1 阶段 E）

- [ ] **连接表**：访问 https 网站时连接表出现新行
- [ ] **关闭单条连接**：点单条连接的关闭按钮 → 该行消失
- [ ] **关闭全部连接**：点「关闭全部」→ 表清空
- [ ] **规则列表**：启动后规则数量 > 0
- [ ] **规则过滤**：输入「google」→ 只显示相关规则
- [ ] **日志刷新**：启动后日志区显示 INFO 启动信息
- [ ] **日志级别过滤**：选 WARN → 只显示 WARN/ERROR
- [ ] **日志暂停**：开启暂停 → 滚动到新日志时不刷新
- [ ] **日志清空**：点清空 → 日志区为空

### 3.8 测试页（P1 阶段 F）

- [ ] **单项测试**：点 Apple 卡片测试按钮 → 显示延迟或失败原因
- [ ] **全部测试**：点「全部测试」→ 依次执行 4 个预设
- [ ] **取消**：测试中点「取消」→ 立即停止
- [ ] **添加测试项**：点添加 → 输入名称和 URL → 加入列表
- [ ] **测试状态颜色**：成功绿、失败红、运行中蓝

### 3.9 设置（P1 阶段 F）

- [ ] **端口修改**：修改 HTTP 端口为 17890→27890 → 保存 → 重启 core → 生效
- [ ] **端口冲突**：设置 HTTP 端口为已占用端口 → 保存 → 明确错误
- [ ] **开机启动**：勾选 → 注销登录后 Clash RS 自动启动
- [ ] **静默启动**：勾选 → 启动时不在 dock 显示图标
- [ ] **主题**：深色/浅色/系统 → 立即生效
- [ ] **DNS 覆写**：勾选 → 重启后 fake-ip 生效
- [ ] **备份/恢复**：导出 → 看到 backup.json；导入 → 配置恢复
- [ ] **恢复默认值**：点恢复 → 所有设置回默认

---

## 4. 异常场景验证

### 4.1 异常退出恢复（P0 阶段 A）

```bash
# 1. 启动 TUN 模式
# 2. 强制 kill 主进程
pkill -9 'Clash RS'

# 3. 验证：系统代理/路由/DNS 不能有残留
networksetup -getwebproxy Wi-Fi  # 应为原状态
netstat -rn | grep utun            # 应无 clash-rs 路由

# 4. 重新启动 app
open /Applications/Clash\ RS.app

# 5. 验证：app 启动时 recover() 触发 → 清理 orphan helper → 网络状态恢复
```

### 4.2 端口冲突

```bash
# 故意让 9090 端口被占用
python3 -c "import socket; s=socket.socket(); s.bind(('127.0.0.1', 9090)); s.listen(); import time; time.sleep(600)"

# 启动 app → 点启动代理 → 应显示「控制端口 9090 已被占用」
```

### 4.3 TUN 核心异常退出

```bash
# 启动 TUN
# 找到 Clash RS App 内的 mihomo PID 后结束它
pgrep -fl '/Clash RS.app/Contents/Resources/mihomo'
sudo kill -9 <pid>

# 连续三次控制 API 失败后，App 应执行最多三次 TUN 自动重建。
```

### 4.4 异常网络环境

- [ ] **睡眠唤醒**：TUN 模式下 Mac 进入睡眠 → 唤醒后代理仍工作
- [ ] **切换 Wi-Fi**：从 A Wi-Fi 切到 B Wi-Fi → TUN 应自动跟随
- [ ] **断网后恢复**：拔网 → 连网 → 流量曲线重新活跃

---

## 5. 卸载

### 5.1 macOS

```bash
# 1. 关闭 app
osascript -e 'tell application "Clash RS" to quit'

# 2. 等待核心退出
sleep 2

# 3. 删除 app
rm -rf /Applications/Clash\ RS.app

# 4. 清理用户数据
rm -rf "$HOME/Library/Application Support/Clash RS"
rm -rf "$HOME/Library/Caches/Clash RS"
rm -rf "$HOME/Library/Containers/Clash RS"

# 5. 清理网络状态残留（如果有）
osascript -e 'do shell script "/usr/sbin/networksetup -setwebproxystate Wi-Fi off" with administrator privileges'
osascript -e 'do shell script "/usr/sbin/networksetup -setsecurewebproxystate Wi-Fi off" with administrator privileges'
osascript -e 'do shell script "/usr/sbin/networksetup -setsocksfirewallproxystate Wi-Fi off" with administrator privileges'
rm -f "$HOME/Library/Application Support/Clash RS/network-recovery.json"

# 6. 清理开机启动
rm -f "$HOME/Library/LaunchAgents/com.proxyapp.clashrs.plist"

# 7. 验证系统代理为原始状态
networksetup -getwebproxy Wi-Fi
```

### 5.2 Windows

```powershell
# 1. 关闭 app
Stop-Process -Name clash_rs -Force

# 2. 卸载安装包版本（控制面板 → 卸载程序）
# 或删除 portable 版本
Remove-Item "$env:LOCALAPPDATA\Clash RS" -Recurse -Force
Remove-Item "$env:APPDATA\Clash RS" -Recurse -Force

# 3. 清理注册表系统代理
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /f

# 4. 清理开机启动
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "Clash RS" /f

# 5. 清理 Wintun 驱动（可选，会影响其他 VPN 客户端）
# wintun uninstall
```

---

## 6. 验证记录模板

每次完整跑过一遍后，按下面模板留档：

```markdown
### 验证日期：YYYY-MM-DD
- 机器：MacBook Pro M2 (macOS 26.6.1)
- 构建版本：v1.0.0
- App SHA256：xxx
- DMG SHA256：xxx

#### 阶段 A 桌面壳与窗口
- [x] 窗口 960×720 固定
- [x] DPI 100% 正常
- [x] DPI 125% 正常
- [x] DPI 150% 正常
- [x] 8 页面无溢出

#### 阶段 B 配置与订阅
- [x] URL 导入
- [x] 失败回滚
- ...

#### 异常场景
- [x] 强制退出后网络状态恢复
- [x] TUN 启动超时
- ...

#### 已知问题
- 无
```
