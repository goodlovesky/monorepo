# Clash RS Windows x64 打包设计

## 目标

在 Windows GitHub Actions 原生环境中构建 Clash RS 1.0.0，输出可直接解压运行的便携包和可安装、覆盖升级、卸载的 Inno Setup 安装包。macOS 本机仅执行跨平台源码、脚本合同和 Flutter 回归验证。

## 发行物

- `ClashRS-1.0.0-windows-x64-portable.zip`
- `ClashRS-Setup-1.0.0-x64.exe`
- `SHA256.txt`
- `BUILD-MANIFEST.json`
- `BUILD-ENVIRONMENT.txt`

## 构建链路

1. 从 `app/pubspec.yaml` 读取应用版本并拒绝无效版本。
2. 固定下载 mihomo `v1.19.30` 和 Wintun `0.14.1`，下载后执行 SHA-256 校验。
3. 运行 Flutter 依赖解析、静态分析、测试和 Windows Release 构建。
4. 将 mihomo、Wintun 和第三方许可证放入 Release 目录。
5. 验证 Windows 运行目录中的 EXE、DLL、ICU 和 Flutter assets。
6. 生成便携 ZIP、Inno Setup 安装包、构建清单和哈希文件。
7. CI 临时安装安装包，验证安装目录内容，然后静默卸载。

## 安装与升级

安装器使用固定 AppId 保持升级身份，使用应用互斥量和 Restart Manager 关闭旧版本，禁止同时运行多个安装器。覆盖升级前删除旧的易残留运行文件，但保留用户应用数据。卸载时停止 Clash RS 和由安装目录启动的 mihomo；用户配置默认保留。

## 签名

签名不是当前构建的硬依赖。构建脚本接受可选的签名命令；CI 后续配置证书时可以在不改变发行结构的情况下启用 Authenticode。

## 验证边界

macOS 环境验证脚本结构、固定版本、资源合同、Flutter 分析与测试；Windows CI 验证真实 EXE、ZIP、安装、卸载和产物哈希。最终网络功能仍需在 Windows 10/11 目标机进行系统代理与 Wintun 验收。
