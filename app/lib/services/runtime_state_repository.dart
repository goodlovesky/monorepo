import 'dart:convert';
import 'dart:io';

/// 桌面端运行态持久化：保存当前运行模式 + helper/engine PID，
/// 启动时用于检测 orphan 进程并清理。
///
/// 写文件用原子替换（tmp + rename），避免崩溃中途半写。
class RuntimeStateRepository {
  RuntimeStateRepository(this.supportDirectory);

  final Directory supportDirectory;

  File get _stateFile => File('${supportDirectory.path}/runtime-state.json');
  File get _tmpFile => File('${supportDirectory.path}/runtime-state.json.tmp');

  Future<RuntimeState?> load() async {
    if (!await _stateFile.exists()) return null;
    try {
      final root = jsonDecode(await _stateFile.readAsString());
      if (root is! Map) return null;
      return RuntimeState.fromJson(root.cast<String, dynamic>());
    } catch (_) {
      // 文件损坏视为无状态
      try {
        await _stateFile.delete();
      } catch (_) {}
      return null;
    }
  }

  Future<void> save(RuntimeState state) async {
    if (!await supportDirectory.exists()) {
      await supportDirectory.create(recursive: true);
    }
    await _tmpFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
      flush: true,
    );
    if (await _stateFile.exists()) await _stateFile.delete();
    await _tmpFile.rename(_stateFile.path);
  }

  Future<void> clear() async {
    if (await _stateFile.exists()) await _stateFile.delete();
    if (await _tmpFile.exists()) await _tmpFile.delete();
  }
}

/// 桌面运行态快照。
///
/// 字段允许为 null：表示该项未运行/未知。序列化时忽略 null，
/// 反序列化时缺失等同于 null。
class RuntimeState {
  /// 当前运行模式。
  final RuntimeRuntimeMode mode;

  /// macOS TUN 核心进程号。字段名为兼容旧恢复文件而保留。
  final int? helperPid;

  /// 普通核心（clash-rs engine in-process）启动时间戳。
  final DateTime? engineStartedAt;

  /// 启动模式时控制端口。
  final int? controllerPort;

  /// 最近一次模式切换时间。
  final DateTime? updatedAt;

  const RuntimeState({
    this.mode = RuntimeRuntimeMode.off,
    this.helperPid,
    this.engineStartedAt,
    this.controllerPort,
    this.updatedAt,
  });

  RuntimeState copyWith({
    RuntimeRuntimeMode? mode,
    int? helperPid,
    bool clearHelperPid = false,
    DateTime? engineStartedAt,
    bool clearEngineStartedAt = false,
    int? controllerPort,
    bool clearControllerPort = false,
    DateTime? updatedAt,
  }) => RuntimeState(
    mode: mode ?? this.mode,
    helperPid: clearHelperPid ? null : (helperPid ?? this.helperPid),
    engineStartedAt: clearEngineStartedAt
        ? null
        : (engineStartedAt ?? this.engineStartedAt),
    controllerPort: clearControllerPort
        ? null
        : (controllerPort ?? this.controllerPort),
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'mode': mode.name,
    if (helperPid != null) 'helperPid': helperPid,
    if (engineStartedAt != null)
      'engineStartedAt': engineStartedAt!.toIso8601String(),
    if (controllerPort != null) 'controllerPort': controllerPort,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  factory RuntimeState.fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'] as String? ?? 'off';
    return RuntimeState(
      mode: RuntimeRuntimeMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => RuntimeRuntimeMode.off,
      ),
      helperPid: (json['helperPid'] as num?)?.toInt(),
      engineStartedAt: json['engineStartedAt'] is String
          ? DateTime.tryParse(json['engineStartedAt'] as String)
          : null,
      controllerPort: (json['controllerPort'] as num?)?.toInt(),
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

enum RuntimeRuntimeMode { off, systemProxy, tun }
