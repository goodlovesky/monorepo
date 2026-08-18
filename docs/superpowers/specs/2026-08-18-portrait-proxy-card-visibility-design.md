# 竖屏锁定与代理卡片显示规则

## 目标

应用在所有页面保持竖屏。首页“代理”卡片仅在代理核心与 Android VPN 均处于运行状态时显示；停止、启动中、启动失败或状态不一致时从布局中完全移除，不保留空白。

## 实现

- `main.dart` 在 `runApp` 前通过 `SystemChrome.setPreferredOrientations` 限定 `DeviceOrientation.portraitUp`。
- `AndroidManifest.xml` 为 `MainActivity` 声明 `android:screenOrientation="portrait"`，覆盖系统自动旋转和横屏启动请求。
- `home_page.dart` 将代理卡片及其下方间距放入 `if (controller.isRunning)` 条件集合；启动卡片和配置卡片保持常驻。
- 不新增设置项，不改变 VPN 启停、配置管理、页面导航和持久化格式。

## 验收

1. 代理停止：主页没有“代理/规则模式”卡片，配置卡片紧接启动卡片。
2. 代理启动成功：代理卡片出现且可进入节点页。
3. 代理停止：代理卡片立即消失。
4. 真机发送横屏方向请求后，Activity 仍报告 portrait。
5. `flutter analyze`、`flutter test` 和 debug APK 构建通过。
