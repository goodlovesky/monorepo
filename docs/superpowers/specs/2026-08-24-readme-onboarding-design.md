# Clash RS README 与新手指南设计

## 目标

重写根目录项目说明，让第一次接触 Clash RS 的用户能够理解项目用途、支持平台、构建方式和基本使用流程。`README.md` 作为英文主文档，`README_ZH.md` 作为结构一致、说明更细的完整中文版。

## 文档边界

- 仅描述当前仓库已经实现并验证的 Android、macOS、Windows 和 Linux 功能。
- 所有构建命令统一引用根目录 `cmd/` 入口。
- 不承诺 Apple 正式签名、公证、Windows ARM64、Linux ARM64、RPM 或 AppImage。
- 不在文档中保存订阅地址、账号、密钥或其他本地数据。

## README.md

英文主文档包含：

1. 项目定位和主要能力。
2. 中文文档入口。
3. 支持平台、核心实现和发布格式。
4. 新手快速开始与环境要求。
5. Android、macOS、Windows、Linux 分平台构建命令。
6. 产物路径和安装方式。
7. 导入订阅、选择节点、测速、系统代理和 TUN 的基本流程。
8. 系统代理与 TUN 的差异。
9. 常见问题、日志路径、测试命令和项目结构。
10. GPL-3.0-or-later 许可证信息。

## README_ZH.md

中文版与英文版保持章节对应，并增加适合初学者的解释：

- 明确所有命令应从仓库根目录执行。
- 列出 Flutter、Rust、平台工具链和 Linux 依赖。
- 解释 macOS 本机不能原生构建 Windows/Linux 产物，Windows 使用 GitHub Actions 或 Windows 主机构建。
- 说明每个平台的输出文件名和目录。
- 解释首次运行、订阅导入、节点测速和代理模式选择。
- 说明 Linux TUN capability、macOS 管理员确认和 Windows Wintun。
- 给出核心启动、系统代理、测速、连接和 IP 信息异常的日志排查入口。

## 一致性与验证

- `README.md` 和 `README_ZH.md` 的平台、版本、命令和产物路径必须一致。
- 文档中的脚本必须真实存在，并通过 `--help` 或 PowerShell 参数合同检查。
- Markdown 链接和本地文件引用必须存在。
- 版本统一为 `1.0.0`，应用名称统一为 `Clash RS`。
