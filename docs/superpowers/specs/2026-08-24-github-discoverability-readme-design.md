# GitHub 可发现性与 README 优化设计

## 目标

让 GitHub 用户通过项目名称、技术栈、使用场景和目标平台相关关键词，更快理解并搜索到 Clash RS，同时保留现有的新手使用与多平台打包说明。

## 已确认范围

- 仓库设为公开可见。
- 优化英文 `README.md` 和中文 `README_ZH.md` 的首屏信息结构。
- 配置 GitHub About 描述和 Topics。
- 增加必要的状态徽章与清晰导航。
- 保留现有构建教程、功能说明和隐私提示。
- 不修改应用功能、版本号、发布流程或仓库名称。

## 方案选择

采用“README + GitHub 元数据”的完整方案，而不是只修改 README。README 负责解释项目价值和使用方式；About、Topics 与自然语言关键词负责提升 GitHub 内部搜索和分类发现效果。

不采用关键词堆砌方案。关键词必须出现在可读的产品定位、平台说明和功能描述中，避免重复列表影响阅读体验。

## README 信息架构

### 首屏

英文 README 首屏依次展示：

1. `Clash RS` 标题和中英文切换入口。
2. 一句话产品定位：基于 Flutter 的跨平台 Mihomo GUI 与代理客户端。
3. 构建状态、版本、Flutter、平台和许可证徽章。
4. 支持平台与核心能力的短摘要。
5. `Download / Quick Start / Build / 中文文档` 快速导航。

中文 README 使用相同结构，但使用自然中文描述，并保留英文技术关键词，例如 Flutter、Mihomo、TUN 和 System Proxy，方便中英文搜索。

### 正文

保留以下现有内容：

- 功能列表与平台支持表。
- 用户快速开始。
- System Proxy 与 TUN 对比。
- Android、macOS、Windows、Linux 构建前置条件和命令。
- 输出文件、GitHub Actions、测试和故障排查说明。

正文只调整标题、内部链接和重复描述，不删除对新手有用的信息。

## 搜索关键词策略

关键词通过完整句子和准确分类自然出现：

- 产品与生态：`Clash RS`、`Clash client`、`Mihomo GUI`、`Mihomo client`。
- 技术栈：`Flutter`、`Rust`、`VpnService`、`Wintun`。
- 使用场景：`proxy client`、`VPN client`、`system proxy`、`TUN mode`、`subscription management`、`latency test`。
- 平台：`Android`、`macOS`、`Windows`、`Linux`、`cross-platform desktop`。

README 不声称未实现的能力，也不加入真实订阅地址、代理节点或本机路径。

## GitHub 元数据

### About 描述

使用简洁英文描述：

> Cross-platform Flutter proxy client and Mihomo GUI for Android, macOS, Windows and Linux, with system proxy, TUN mode, subscriptions and traffic monitoring.

### Topics

配置以下精准主题：

`clash-rs`, `clash`, `mihomo`, `mihomo-gui`, `flutter`, `rust`, `proxy`, `proxy-client`, `vpn-client`, `android`, `macos`, `windows`, `linux`, `tun`, `system-proxy`, `cross-platform`

Topics 控制在 GitHub 上限以内，并只使用小写字母和连字符。

### Homepage

当前没有单独官网或文档站点，因此暂不设置 Homepage，避免无效链接。发布页继续通过 README 导航访问。

## 徽章设计

仅使用能够准确反映仓库状态的徽章：

- GitHub Actions 桌面构建状态。
- 当前应用版本 `1.0.0`。
- Flutter。
- 支持平台。
- 仓库许可证；若仓库没有许可证文件，则不展示许可证徽章。

徽章链接必须指向本仓库页面或官方技术站点，不使用需要额外账户的统计服务。

## 验证标准

完成后验证：

1. 仓库可见性为 Public。
2. GitHub About 描述和 Topics 与设计一致。
3. 英文、中文 README 的相互链接有效。
4. README 中的工作流徽章引用真实存在的 workflow 文件。
5. 所有目录锚点和仓库内相对链接有效。
6. 搜索关键词自然出现，不存在重复堆砌或未实现功能声明。
7. `git diff --check` 通过，工作区无意外文件。

## 非目标

- 本轮不更改仓库名称 `monorepo`。
- 本轮不创建官网、文档站点或宣传图片。
- 本轮不修改应用源码、构建产物或发布版本。
- 本轮不增加真实代理、订阅或设备信息。
