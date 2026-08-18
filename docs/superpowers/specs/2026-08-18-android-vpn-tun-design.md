# Android 全设备 VPN 接管设计

## 目标

当用户在主界面启动代理并看到“运行中”时，Android 系统通过 `VpnService` 将除本应用自身之外的全部 IPv4 流量送入 clash-rs。停止代理、引擎启动失败或服务退出时，系统 VPN 同步撤销，不留下无出口的黑洞路由。

首版范围限定为 Android 全设备 IPv4、TCP、UDP 和 DNS。IPv6 不发布半接管状态：VPN 建立时不声明 IPv6 地址和路由，后续单独补齐双栈支持。

## 采用方案

Android `VpnService` 创建 TUN，并把已建立的文件描述符直接交给 clash-rs。clash-rs 0.9.7 已支持 `tun.device-id: fd://<number>`，因此不引入 tun2socks，也不重复实现 TCP/UDP 转发。

应用包 `com.proxyapp.app` 通过 `VpnService.Builder.addDisallowedApplication` 排除在 VPN 外。clash-rs 发往 VLESS/Reality 服务端的出口套接字由同一应用进程创建，排除自身可阻止出口流量再次进入 TUN 形成递归。

## 组件

### `ProxyVpnService`

- 继承 `android.net.VpnService`，运行在应用默认进程。
- 建立前台通知和常驻服务。
- 使用以下 Builder 参数：
  - session：`Proxy App`
  - address：`198.18.0.1/24`
  - route：`0.0.0.0/0`
  - DNS：`1.1.1.1`、`8.8.8.8`
  - MTU：`1500`
  - disallowed application：`com.proxyapp.app`
- 调用 `establish()` 后通过 `detachFd()` 转移 TUN FD 所有权；服务不得再次关闭该 FD。
- 建立失败时关闭通知并返回结构化错误。
- 接收停止动作时撤销 VPN、停止前台状态并结束服务。

### `MainActivity` MethodChannel

通道名称：`com.proxyapp.app/vpn`。

方法：

- `prepare`：调用 `VpnService.prepare()`；已确认时立即返回，未确认时启动系统确认页并等待 Activity Result。
- `establish`：启动 `ProxyVpnService`，等待服务建立结果，返回正整数 `tunFd`。
- `stop`：发送停止动作并等待服务完成清理。
- `status`：返回 `permissionGranted`、`serviceRunning`。

所有返回值使用 Map，至少包含 `ok`、`code`、`message`；`establish` 成功时额外包含 `tunFd`。

### Flutter `VpnController`

- 封装 MethodChannel，Android 以外平台保持显式的不支持状态。
- 负责权限、TUN 建立、停止和状态查询。
- 不直接管理 clash-rs 生命周期。

### 运行配置

启动时基于持久化的节点配置生成独立运行时文件 `runtime-config.yaml`，不覆盖用户配置。运行时文件追加：

```yaml
tun:
  enable: true
  device-id: "fd://<tunFd>"
  gateway: 198.18.0.1/24
  route-all: false
  mtu: 1500
  dns-hijack: true
```

Android 路由由 `VpnService.Builder` 建立；`route-all` 保持 `false`，避免 clash-rs 再操作 Android 系统路由。

## 启动与停止时序

### 启动

1. Flutter 将 UI 置为忙碌状态。
2. `VpnController.prepare()` 获取系统 VPN 确认。
3. `VpnController.establish()` 建立 TUN 并取得 FD。
4. Flutter 写入 `runtime-config.yaml`，其中 `device-id` 指向该 FD。
5. Flutter 调用 `proxy_engine_start`。
6. 轮询引擎状态并检查 controller API；两者均正常后才显示“运行中”。
7. 任一步失败时停止引擎、停止 VPN 服务，并显示具体阶段和错误。

### 停止

1. 停止流量轮询。
2. 调用 `proxy_engine_stop`，让 clash-rs 关闭 TUN FD。
3. 调用 `VpnController.stop()` 撤销系统 VPN 和前台通知。
4. 确认引擎与服务均停止后显示“已停止”。

### 异常恢复

- App 冷启动时同时读取引擎状态和 VPN 服务状态；状态不一致时执行完整停止清理。
- `ProxyVpnService.onDestroy()`、`onRevoke()` 发出状态变化并停止自身。
- 引擎启动超时或 controller API 不可达时不得显示“运行中”。
- 进程被系统终止后，系统自动关闭该进程持有的 TUN FD并撤销 VPN。

## Android 配置

Manifest 新增：

- `android.permission.INTERNET`
- `android.permission.FOREGROUND_SERVICE`
- Android 14+ 的 VPN 前台服务权限和类型。
- `ProxyVpnService`，声明 `android.permission.BIND_VPN_SERVICE`、`android:exported="false"` 与 `android.net.VpnService` intent filter。

通知渠道在 Android 8+ 创建。前台服务通知持续显示代理运行状态。

## 验收与测试

### 静态和单元测试

- Kotlin：权限已确认、拒绝、TUN 建立失败、重复启动、停止幂等。
- Dart：启动成功、权限拒绝、VPN 建立失败、引擎失败后的回滚、停止顺序。
- Rust：现有 workspace 测试继续通过，运行时配置可解析 `fd://` TUN。

### 真机验收

1. 清除 Android 全局 HTTP 代理，避免旧代理设置干扰。
2. 启动 App，接受系统 VPN 确认。
3. UI 显示“运行中”，系统状态栏出现 VPN 图标，`dumpsys connectivity` 显示本应用 VPN network。
4. 手机浏览器访问出口查询页，出口为代理节点 `203.0.113.10`。
5. 通过浏览器和 DNS 测试验证 TCP、UDP/DNS 流量增长。
6. 停止 App 后 VPN 图标消失，出口恢复为手机原网络。
7. 强制停止 App 后系统 VPN 立即撤销。

## 完成标准

- “运行中”严格表示 VpnService、TUN、clash-rs 和 controller API 全部正常。
- 除本应用自身外的全设备 IPv4 流量进入 TUN，并由当前 VLESS/Reality 节点转发。
- 启动失败和停止操作均恢复原网络，不留下 VPN 路由或前台服务。
- 可重复执行启动、停止、重启和强制停止测试。
