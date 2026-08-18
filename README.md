# Proxy App Monorepo

> 全平台代理软件 —— **Flutter UI** + **Rust 内核 (clash-rs)** + 平台原生 VPN

## 项目状态

🚧 **Phase 0: 技术验证**（进行中）

## 架构

```
┌─────────────────────────────────────┐
│  Flutter (Dart) — UI / 业务编排     │
└─────────────────┬───────────────────┘
                  │ FFI / MethodChannel
┌─────────────────▼───────────────────┐
│  Rust — clash-rs 内核 + FFI 桥      │
│  (核心协议 / 规则 / DNS / TUN)       │
└─────────────────┬───────────────────┘
                  │ 系统 API
┌─────────────────▼───────────────────┐
│  平台原生                            │
│  Android VpnService / iOS NetworkExtension / macOS utun / Windows wintun / Linux tun │
└─────────────────────────────────────┘
```

## 仓库结构

```
.
├── crates/                  # Rust workspace
│   └── core-bridge/         # FFI 桥（暴露给 Dart 的 C ABI）
├── app/                     # Flutter 应用
├── tools/                   # 构建脚本
└── docs/                    # 设计文档
```

## 开发

### 前置依赖

| 工具 | 版本 | 用途 |
|---|---|---|
| Rust | 1.75+ | 内核开发 |
| Cargo | 1.75+ | Rust 包管理 |
| Flutter | 3.x stable | UI 开发 |
| Dart | 3.x | Flutter 配套 |
| Android NDK | r26+ | Android .so 编译 |
| Xcode | 15+ | iOS / macOS |
| CMake | 3.29+ | clash-rs 编译依赖 |
| nasm | latest | Windows 编译 |

### 编译 Rust

```bash
# 检查
cargo check --workspace

# 测试
cargo test --workspace

# 编译 release
cargo build --release
```

### 编译 FFI 库

```bash
# macOS
cargo build --release --target aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin

# iOS
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim

# Android
cargo build --release --target aarch64-linux-android
cargo build --release --target armv7-linux-androideabi
```

### 生成 C 头文件

```bash
cargo install cbindgen
cbindgen --config cbindgen.toml --crate core-bridge --output bindings/core_bridge.h
```

## 路线图

- [x] **Phase 0.1**: 搭 monorepo 骨架
- [ ] **Phase 0.2**: 最小 Rust FFI demo
- [ ] **Phase 0.3**: 集成 clash-rs
- [ ] **Phase 0.4**: Flutter app 骨架
- [ ] **Phase 1**: Rust FFI 完整封装
- [ ] **Phase 2**: Flutter UI
- [ ] **Phase 3**: Android VpnService
- [ ] **Phase 4**: iOS NetworkExtension
- [ ] **Phase 5**: 完整功能
- [ ] **Phase 6**: 桌面平台
- [ ] **Phase 7**: 优化打磨
- [ ] **Phase 8**: 灰度发布

## 协议

GPL-3.0-or-later
