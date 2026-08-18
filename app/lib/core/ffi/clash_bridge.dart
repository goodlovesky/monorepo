// lib/core/ffi/clash_bridge.dart
//
// Rust 端 FFI 的 Dart 绑定 —— 对应 `bindings/core_bridge.h`
//
// 调用流程：
//   1. DynamicLibrary.open(...) 加载 .dylib / .so / .dll
//   2. lookupFunction 拿到 C 函数指针
//   3. 用 dart:ffi 的类型包装（C 的 *mut c_char 对应 Pointer<Utf8>）
//   4. 调用 + 手动管理内存（用完 .toDartString() 拷贝出来，再 .free() 释放原指针）

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ========================================================================
// C 函数签名
// ========================================================================

// char *proxy_version(void);
typedef _ProxyVersionNative = Pointer<Utf8> Function();
typedef _ProxyVersionDart = Pointer<Utf8> Function();

// int32_t proxy_init(const char *home_dir, const char *version, int32_t sdk);
typedef _ProxyInitNative = Int32 Function(
    Pointer<Utf8> home, Pointer<Utf8> version, Int32 sdk);
typedef _ProxyInitDart = int Function(
    Pointer<Utf8> home, Pointer<Utf8> version, int sdk);

// int32_t proxy_shutdown(void);
typedef _ProxyShutdownNative = Int32 Function();
typedef _ProxyShutdownDart = int Function();

// char *proxy_query_state(void);
typedef _ProxyQueryStateNative = Pointer<Utf8> Function();
typedef _ProxyQueryStateDart = Pointer<Utf8> Function();

// char *proxy_pong(const char *input);
typedef _ProxyPongNative = Pointer<Utf8> Function(Pointer<Utf8> input);
typedef _ProxyPongDart = Pointer<Utf8> Function(Pointer<Utf8> input);

// int32_t proxy_engine_start(const char *config_path, const char *cwd, const char *log_file);
typedef _ProxyEngineStartNative = Int32 Function(
    Pointer<Utf8> config, Pointer<Utf8> cwd, Pointer<Utf8> log);
typedef _ProxyEngineStartDart = int Function(
    Pointer<Utf8> config, Pointer<Utf8> cwd, Pointer<Utf8> log);

// int32_t proxy_engine_stop(void);
typedef _ProxyEngineStopNative = Int32 Function();
typedef _ProxyEngineStopDart = int Function();

// int32_t proxy_engine_is_running(void);
typedef _ProxyEngineIsRunningNative = Int32 Function();
typedef _ProxyEngineIsRunningDart = int Function();

// char *proxy_engine_status(void);
typedef _ProxyEngineStatusNative = Pointer<Utf8> Function();
typedef _ProxyEngineStatusDart = Pointer<Utf8> Function();

// char *proxy_last_error_message(int32_t code);
typedef _ProxyLastErrorMessageNative = Pointer<Utf8> Function(Int32 code);
typedef _ProxyLastErrorMessageDart = Pointer<Utf8> Function(int code);

// void proxy_free_string(char *ptr);
typedef _ProxyFreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef _ProxyFreeStringDart = void Function(Pointer<Utf8> ptr);

// ========================================================================
// 错误码
// ========================================================================

/// 对应 C 的 ErrorCode enum
class ErrorCode {
  static const int ok = 0;
  static const int invalidArg = -1;
  static const int nullPointer = -2;
  static const int utf8 = -3;
  static const int notInitialized = -4;
  static const int alreadyInitialized = -5;
  static const int internal = -100;
  static const int notImplemented = -101;

  /// 错误码 -> 人类可读消息
  static String message(int code) {
    switch (code) {
      case ok:
        return 'ok';
      case invalidArg:
        return 'invalid argument';
      case nullPointer:
        return 'null pointer';
      case utf8:
        return 'utf-8 decode error';
      case notInitialized:
        return 'not initialized';
      case alreadyInitialized:
        return 'already initialized';
      case internal:
        return 'internal error';
      case notImplemented:
        return 'not implemented';
      default:
        return 'unknown error ($code)';
    }
  }
}

// ========================================================================
// FFI 包装类
// ========================================================================

/// Rust core-bridge 的 Dart 封装。
/// 单例。
class ClashBridge {
  late final DynamicLibrary _lib;
  late final _ProxyVersionDart _version;
  late final _ProxyInitDart _init;
  late final _ProxyShutdownDart _shutdown;
  late final _ProxyQueryStateDart _queryState;
  late final _ProxyPongDart _pong;
  late final _ProxyEngineStartDart _engineStart;
  late final _ProxyEngineStopDart _engineStop;
  late final _ProxyEngineIsRunningDart _engineIsRunning;
  late final _ProxyEngineStatusDart _engineStatus;
  late final _ProxyLastErrorMessageDart _lastErrorMessage;
  late final _ProxyFreeStringDart _freeString;

  ClashBridge._() {
    _lib = _loadLibrary();
    _version = _lib.lookupFunction<_ProxyVersionNative, _ProxyVersionDart>('proxy_version');
    _init = _lib.lookupFunction<_ProxyInitNative, _ProxyInitDart>('proxy_init');
    _shutdown = _lib.lookupFunction<_ProxyShutdownNative, _ProxyShutdownDart>('proxy_shutdown');
    _queryState = _lib.lookupFunction<_ProxyQueryStateNative, _ProxyQueryStateDart>('proxy_query_state');
    _pong = _lib.lookupFunction<_ProxyPongNative, _ProxyPongDart>('proxy_pong');
    _engineStart = _lib.lookupFunction<_ProxyEngineStartNative, _ProxyEngineStartDart>('proxy_engine_start');
    _engineStop = _lib.lookupFunction<_ProxyEngineStopNative, _ProxyEngineStopDart>('proxy_engine_stop');
    _engineIsRunning = _lib.lookupFunction<_ProxyEngineIsRunningNative, _ProxyEngineIsRunningDart>('proxy_engine_is_running');
    _engineStatus = _lib.lookupFunction<_ProxyEngineStatusNative, _ProxyEngineStatusDart>('proxy_engine_status');
    _lastErrorMessage = _lib.lookupFunction<_ProxyLastErrorMessageNative, _ProxyLastErrorMessageDart>('proxy_last_error_message');
    _freeString = _lib.lookupFunction<_ProxyFreeStringNative, _ProxyFreeStringDart>('proxy_free_string');
  }

  static final ClashBridge instance = ClashBridge._();

  // ============================================================
  // Phase 0.2 基础 FFI
  // ============================================================

  /// 库版本号（自动 free 返回的 C 字符串）
  String version() {
    final ptr = _version();
    if (ptr == nullptr) return 'unknown';
    final s = ptr.toDartString();
    _freeString(ptr);
    return s;
  }

  /// 初始化"门面"状态（Phase 0.2 占位接口）
  int init({required String homeDir, required String version, required int sdk}) {
    final homePtr = homeDir.toNativeUtf8();
    final verPtr = version.toNativeUtf8();
    try {
      return _init(homePtr, verPtr, sdk);
    } finally {
      calloc.free(homePtr);
      calloc.free(verPtr);
    }
  }

  /// 关闭门面状态
  int shutdown() => _shutdown();

  /// 查询门面状态（JSON 字符串）
  String? queryState() {
    final ptr = _queryState();
    if (ptr == nullptr) return null;
    final s = ptr.toDartString();
    _freeString(ptr);
    return s;
  }

  /// FFI 链路测试（ping）
  String? pong(String input) {
    final inputPtr = input.toNativeUtf8();
    try {
      final ptr = _pong(inputPtr);
      if (ptr == nullptr) return null;
      final s = ptr.toDartString();
      _freeString(ptr);
      return s;
    } finally {
      calloc.free(inputPtr);
    }
  }

  /// 错误码 -> 人类可读消息
  String lastErrorMessage(int code) {
    final ptr = _lastErrorMessage(code);
    if (ptr == nullptr) return ErrorCode.message(code);
    final s = ptr.toDartString();
    _freeString(ptr);
    return s;
  }

  // ============================================================
  // Phase 0.3 引擎 FFI
  // ============================================================

  /// 启动代理引擎。
  /// 0 = 成功，非 0 = 失败（用 [lastErrorMessage] 看具体原因）。
  int engineStart({required String configPath, required String cwd, String? logFile}) {
    final configPtr = configPath.toNativeUtf8();
    final cwdPtr = cwd.toNativeUtf8();
    final logPtr = (logFile == null) ? nullptr : logFile.toNativeUtf8();
    try {
      return _engineStart(configPtr, cwdPtr, logPtr);
    } finally {
      calloc.free(configPtr);
      calloc.free(cwdPtr);
      if (logPtr != nullptr) calloc.free(logPtr);
    }
  }

  /// 停止代理引擎（最多 5 秒等线程退出）
  int engineStop() => _engineStop();

  /// 是否在运行
  bool engineIsRunning() => _engineIsRunning() == 1;

  /// 详细状态（JSON 字符串）
  String? engineStatus() {
    final ptr = _engineStatus();
    if (ptr == nullptr) return null;
    final s = ptr.toDartString();
    _freeString(ptr);
    return s;
  }
}

// ========================================================================
// 库加载：跨平台 .dylib / .so / .dll / 静态链接
// ========================================================================

DynamicLibrary _loadLibrary() {
  if (Platform.isMacOS) {
    // macOS 桌面：dylib 在 Contents/Frameworks/ 下（拷贝自 crates/core-bridge）
    return DynamicLibrary.open('libcore_bridge.dylib');
  } else if (Platform.isLinux) {
    return DynamicLibrary.open('libcore_bridge.so');
  } else if (Platform.isWindows) {
    return DynamicLibrary.open('core_bridge.dll');
  } else if (Platform.isAndroid) {
    return DynamicLibrary.open('libcore_bridge.so');
  } else if (Platform.isIOS) {
    // iOS 用静态链接（build_apple.sh 生成 xcframework）
    return DynamicLibrary.process();
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}
