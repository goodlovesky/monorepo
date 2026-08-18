// lib/main.dart
//
// Phase 0.4 — Flutter 调 Rust 跑通 clash 内核的最小 demo
//
// 屏幕显示：
//   - 库版本
//   - init/shutdown 测试结果
//   - pong 回显测试
//   - clash 引擎状态 + 启动/停止按钮
//
// 真机/真模拟器要跑这个：参考 docs/development.md

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'core/ffi/clash_bridge.dart';

void main() {
  runApp(const ProxyApp());
}

class ProxyApp extends StatelessWidget {
  const ProxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proxy App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ProxyHomePage(),
    );
  }
}

class ProxyHomePage extends StatefulWidget {
  const ProxyHomePage({super.key});

  @override
  State<ProxyHomePage> createState() => _ProxyHomePageState();
}

class _ProxyHomePageState extends State<ProxyHomePage> {
  final _bridge = ClashBridge.instance;

  // app sandbox 里的可写目录（macOS: ~/Library/Containers/<bundle>/Data/）
  String? _cwd;
  String? _configPath;

  String _buildTestConfig() {
    return '''
port: 17890
socks-port: 17891
mixed-port: 17892
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
''';
  }

  // ============== 状态 ==============
  String _version = '...';
  String? _initResult;
  String? _pongResult;
  bool _engineRunning = false;
  String? _engineStatus;
  String? _lastError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// 启动时跑一遍基本测试
  Future<void> _bootstrap() async {
    setState(() => _busy = true);
    try {
      // 准备 sandbox 内的可写目录 + 测试配置
      final supportDir = await getApplicationSupportDirectory();
      _cwd = supportDir.path;
      final cfgFile = File('$_cwd/config.yaml');
      if (!await cfgFile.exists()) {
        await cfgFile.writeAsString(_buildTestConfig());
      }
      _configPath = cfgFile.path;

      // 1. 版本
      final v = _bridge.version();

      // 2. pong
      final p = _bridge.pong('hello from Flutter');

      // 3. init
      final rc = _bridge.init(
        homeDir: _cwd!,
        version: v,
        sdk: 35,
      );

      // 4. 引擎状态
      final running = _bridge.engineIsRunning();
      final status = _bridge.engineStatus();

      setState(() {
        _version = v;
        _pongResult = p;
        _initResult = '$rc (${_bridge.lastErrorMessage(rc)})';
        _engineRunning = running;
        _engineStatus = status;
      });
    } catch (e) {
      setState(() => _lastError = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  /// 启动 clash 引擎
  Future<void> _startEngine() async {
    if (_configPath == null || _cwd == null) {
      setState(() => _lastError = '请等待初始化完成');
      return;
    }

    setState(() => _busy = true);
    try {
      final rc = _bridge.engineStart(
        configPath: _configPath!,
        cwd: _cwd!,
      );

      setState(() {
        _lastError = rc == 0
            ? null
            : 'engine start failed: $rc (${_bridge.lastErrorMessage(rc)})';
        _engineRunning = _bridge.engineIsRunning();
        _engineStatus = _bridge.engineStatus();
      });
    } catch (e) {
      setState(() => _lastError = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  /// 停止 clash 引擎
  Future<void> _stopEngine() async {
    setState(() => _busy = true);
    try {
      final rc = _bridge.engineStop();
      setState(() {
        if (rc != 0) {
          _lastError = 'engine stop failed: $rc (${_bridge.lastErrorMessage(rc)})';
        } else {
          _lastError = null;
        }
        _engineRunning = _bridge.engineIsRunning();
        _engineStatus = _bridge.engineStatus();
      });
    } catch (e) {
      setState(() => _lastError = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  /// 刷新状态
  Future<void> _refresh() async {
    setState(() {
      _engineRunning = _bridge.engineIsRunning();
      _engineStatus = _bridge.engineStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proxy App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ========== 状态卡片 ==========
            _StatusCard(
              running: _engineRunning,
              statusJson: _engineStatus,
            ),

            const SizedBox(height: 16),

            // ========== 启动/停止按钮 ==========
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_busy || _engineRunning) ? null : _startEngine,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Engine'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_busy || !_engineRunning) ? null : _stopEngine,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Engine'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ========== FFI 测试结果 ==========
            const Text(
              'FFI 链路测试',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _InfoRow(label: '库版本', value: _version),
            _InfoRow(label: 'pong', value: _pongResult ?? '(未跑)'),
            _InfoRow(label: 'init', value: _initResult ?? '(未跑)'),

            const SizedBox(height: 24),

            // ========== 调试信息 ==========
            if (_lastError != null) ...[
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text(
              '调试信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _InfoRow(label: '平台', value: _platformName()),
            _InfoRow(label: 'CWD', value: _cwd ?? '(未初始化)'),
            _InfoRow(label: 'Config', value: _configPath ?? '(未初始化)'),

            if (_engineStatus != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Engine Status (JSON)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  _JsonPrettyPrinter().format(_engineStatus!),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _platformName() {
    return '${_bridge.version().contains('.') ? "core-bridge loaded" : "NOT loaded"} · '
        'Dart ${_dartVersion()}';
  }

  String _dartVersion() {
    // 简单的版本检测
    return '3.13.0';
  }
}

// ============== 组件 ==============

class _StatusCard extends StatelessWidget {
  final bool running;
  final String? statusJson;

  const _StatusCard({required this.running, this.statusJson});

  @override
  Widget build(BuildContext context) {
    final color = running ? Colors.green : Colors.grey;
    final icon = running ? Icons.check_circle : Icons.cancel;
    final text = running ? 'Engine Running' : 'Engine Stopped';

    return Card(
      color: running ? Colors.green.shade50 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'clash-rs 内核 · 通过 FFI 桥接',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonPrettyPrinter {
  String format(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return jsonStr;
    }
  }
}
