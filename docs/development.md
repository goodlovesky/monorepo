# 开发指南

> core-bridge crate 内部细节、Dart 端 FFI 绑定模板、调试技巧

---

## 模块结构

```
crates/core-bridge/src/
├── lib.rs       # FFI 导出层 (extern "C" 函数)
│                # - Phase 0.2: 基本 FFI (init/shutdown/version/pong)
│                # - Phase 0.3: 引擎 FFI (engine_start/stop/is_running/status)
├── engine.rs    # clash-lib 包装层
│                # - 全局单例引擎句柄
│                # - start/stop/is_running/status
└── (future)
    ├── config.rs    # 配置文件解析 (YAML → InternalConfig)
    ├── stats.rs     # 流量统计
    ├── selector.rs  # 代理组/节点选择
    └── health.rs    # 健康检查
```

## FFI 函数清单

| 函数 | Phase | 说明 |
|---|---|---|
| `proxy_version()` | 0.2 | 库版本号（返回 C 字符串） |
| `proxy_init(home, ver, sdk)` | 0.2 | 初始化"门面"状态（不做实际工作） |
| `proxy_shutdown()` | 0.2 | 关闭门面状态 |
| `proxy_query_state()` | 0.2 | 查询门面状态（JSON） |
| `proxy_pong(input)` | 0.2 | 简单的回显接口（FFI 链路测试） |
| `proxy_last_error_message(code)` | 0.2 | 错误码 → 人类可读消息 |
| `proxy_free_string(ptr)` | 0.2 | 释放 C 字符串（对称用） |
| `proxy_engine_start(config, cwd, log)` | 0.3 | 启动 clash 内核 |
| `proxy_engine_stop()` | 0.3 | 停止 clash 内核 |
| `proxy_engine_is_running()` | 0.3 | 查询是否运行（0/1） |
| `proxy_engine_status()` | 0.3 | 查询状态（JSON） |

## 内存所有权约定

| 调用方向 | 字符串所有权 |
|---|---|
| Dart → Rust (入参) | Dart 拥有，C 函数借走 |
| Rust → Dart (返回) | Rust 分配，Dart 调 `proxy_free_string` 或 `calloc.free()` 释放 |

## 错误码

```c
enum ErrorCode {
    ERROR_CODE_ERROR_CODE_OK = 0,
    ERROR_CODE_ERROR_CODE_INVALID_ARG = -1,
    ERROR_CODE_ERROR_CODE_NULL_POINTER = -2,
    ERROR_CODE_ERROR_CODE_UTF8 = -3,
    ERROR_CODE_ERROR_CODE_NOT_INITIALIZED = -4,
    ERROR_CODE_ERROR_CODE_ALREADY_INITIALIZED = -5,
    ERROR_CODE_ERROR_CODE_INTERNAL = -100,
    ERROR_CODE_ERROR_CODE_NOT_IMPLEMENTED = -101,
};
```

完整定义见 `bindings/core_bridge.h`。

## Dart 端 FFI 绑定模板

```dart
// lib/core/ffi/proxy_ffi.dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// C 头文件内容（运行时由 build_runner 生成）
// 这里我们手写声明

typedef _ProxyVersionNative = Pointer<Utf8> Function();
typedef _ProxyVersionDart = Pointer<Utf8> Function();

typedef _ProxyInitNative = Int32 Function(
    Pointer<Utf8> home, Pointer<Utf8> version, Int32 sdk);
typedef _ProxyInitDart = int Function(
    Pointer<Utf8> home, Pointer<Utf8> version, int sdk);

typedef _ProxyEngineStartNative = Int32 Function(
    Pointer<Utf8> config, Pointer<Utf8> cwd, Pointer<Utf8> logFile);
typedef _ProxyEngineStartDart = int Function(
    Pointer<Utf8> config, Pointer<Utf8> cwd, Pointer<Utf8> logFile);

typedef _ProxyEngineStopNative = Int32 Function();
typedef _ProxyEngineStopDart = int Function();

typedef _ProxyEngineIsRunningNative = Int32 Function();
typedef _ProxyEngineIsRunningDart = int Function();

typedef _ProxyEngineStatusNative = Pointer<Utf8> Function();
typedef _ProxyEngineStatusDart = Pointer<Utf8> Function();

typedef _ProxyFreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef _ProxyFreeStringDart = void Function(Pointer<Utf8> ptr);

class ProxyFfi {
  late final DynamicLibrary _lib;
  late final _ProxyVersionDart _version;
  late final _ProxyInitDart _init;
  late final _ProxyEngineStartDart _engineStart;
  late final _ProxyEngineStopDart _engineStop;
  late final _ProxyEngineIsRunningDart _engineIsRunning;
  late final _ProxyEngineStatusDart _engineStatus;
  late final _ProxyFreeStringDart _freeString;

  ProxyFfi._() {
    if (Platform.isMacOS || Platform.isLinux) {
      _lib = DynamicLibrary.process(); // 静态链接
    } else if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libcore_bridge.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else if (Platform.isWindows) {
      _lib = DynamicLibrary.open('core_bridge.dll');
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }

    _version = _lib.lookupFunction<_ProxyVersionNative, _ProxyVersionDart>('proxy_version');
    _init = _lib.lookupFunction<_ProxyInitNative, _ProxyInitDart>('proxy_init');
    _engineStart = _lib.lookupFunction<_ProxyEngineStartNative, _ProxyEngineStartDart>('proxy_engine_start');
    _engineStop = _lib.lookupFunction<_ProxyEngineStopNative, _ProxyEngineStopDart>('proxy_engine_stop');
    _engineIsRunning = _lib.lookupFunction<_ProxyEngineIsRunningNative, _ProxyEngineIsRunningDart>('proxy_engine_is_running');
    _engineStatus = _lib.lookupFunction<_ProxyEngineStatusNative, _ProxyEngineStatusDart>('proxy_engine_status');
    _freeString = _lib.lookupFunction<_ProxyFreeStringNative, _ProxyFreeStringDart>('proxy_free_string');
  }

  static final ProxyFfi instance = ProxyFfi._();

  /// 库版本号（自动 free）
  String version() {
    final ptr = _version();
    if (ptr == nullptr) return 'unknown';
    final s = ptr.toDartString();
    _freeString(ptr);
    return s;
  }

  /// 启动代理引擎
  int engineStart(String configPath, String cwd, {String? logFile}) {
    final configPtr = configPath.toNativeUtf8();
    final cwdPtr = cwd.toNativeUtf8();
    final logPtr = logFile?.toNativeUtf8() ?? nullptr;

    try {
      return _engineStart(configPtr, cwdPtr, logPtr);
    } finally {
      calloc.free(configPtr);
      calloc.free(cwdPtr);
      if (logPtr != nullptr) calloc.free(logPtr);
    }
  }

  int engineStop() => _engineStop();
  bool engineIsRunning() => _engineIsRunning() == 1;

  Map<String, dynamic> engineStatus() {
    final ptr = _engineStatus();
    if (ptr == nullptr) return {};
    final json = ptr.toDartString();
    _freeString(ptr);
    // 解析 JSON...
    return {};
  }
}
```

## 调试技巧

### 1. 验证 FFI 链路（C 程序）

```bash
# 编译
cargo build --release -p core-bridge
clang tools/c-test-ffi.c -L target/release -lcore_bridge -o /tmp/c-test-ffi

# 跑（macOS）
DYLD_LIBRARY_PATH=target/release /tmp/c-test-ffi

# 跑（Linux）
LD_LIBRARY_PATH=target/release /tmp/c-test-ffi
```

### 2. Rust 端日志

```bash
# 启动时设环境变量
RUST_LOG=core_bridge=debug,clash_lib=info cargo run
```

### 3. Clash 配置文件最小可用样例

```yaml
# config.yaml
port: 7890
socks-port: 7891
mixed-port: 7892
allow-lan: false
mode: rule
log-level: info

dns:
  enable: true
  listen: 127.0.0.1:53053
  default-nameserver: [114.114.114.114]
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver: [114.114.114.114]

rules:
  - MATCH,DIRECT
```

## 已知限制

1. **geoip / geosite 数据**：clash-lib 启动需要 GeoIP/GeoSite 数据库，否则匹配规则时会失败。
   - 解决方案：从 https://github.com/MetaCubeX/meta-rules-dat 下载 `geoip.metadb` 和 `geosite.dat`，放到 `cwd/` 下
2. **Windows tun**：需要 `wintun.dll` 同目录
3. **macOS utun**：需要 root 或 launchd 提权

## 下一步

- Phase 0.4: Flutter app 骨架（等 Flutter 装好）
- Phase 1: 完整 FFI 封装（selectors / health / stats / providers）
- Phase 2: Flutter UI
- Phase 3: Android VpnService
- Phase 4: iOS NetworkExtension
