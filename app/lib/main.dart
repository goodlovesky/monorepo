// lib/main.dart
//
// Phase 1 — 完整功能 UI
//   - 实时流量
//   - 节点列表
//   - 切换节点
//   - 健康检查
//   - clash 引擎启停

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'core/ffi/clash_bridge.dart';
import 'core/ffi/clash_controller.dart';

void main() {
  runApp(const ProxyApp());
}

class ProxyApp extends StatelessWidget {
  const ProxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proxy App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
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

  // 状态
  String? _cwd;
  String? _configPath;
  ClashController? _controller;
  bool _engineRunning = false;
  bool _busy = false;
  String? _lastError;
  String _version = '...';

  // 流量
  TrafficStats _traffic = TrafficStats.zero;
  TrafficStats _trafficPrev = TrafficStats.zero;
  DateTime _trafficLastUpdate = DateTime.now();
  Timer? _trafficTimer;
  int _upRate = 0; // bytes/sec
  int _downRate = 0;

  // 节点
  Map<String, ProxyGroup> _groups = {};
  String? _selectedGroup;
  Map<String, int> _delays = {};
  bool _checkingDelays = false;

  // 累计流量
  int _totalUp = 0;
  int _totalDown = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _trafficTimer?.cancel();
    super.dispose();
  }

  /// 启动时跑一遍基本测试 + 准备环境
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

      // 读 controller 配置
      final cfg = await cfgFile.readAsString();
      final ctrl = ClashConfigParser.parseController(cfg);
      if (ctrl != null) {
        _controller = ClashController(
          baseUrl: 'http://${ctrl.host}:${ctrl.port}',
          secret: ctrl.secret.isEmpty ? null : ctrl.secret,
        );
      }

      // 1. 版本
      final v = _bridge.version();
      _version = v;

      // 2. init（Phase 0.2 占位）
      _bridge.init(homeDir: _cwd!, version: v, sdk: 35);

      // 3. 引擎状态
      _engineRunning = _bridge.engineIsRunning();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      setState(() => _busy = false);
    }
  }

  String _buildTestConfig() {
    return '''
port: 17890
socks-port: 17891
mixed-port: 17892
allow-lan: false
mode: rule
log-level: info

external-controller: 127.0.0.1:16170
secret: proxy_app_ffi_demo

dns:
  enable: true
  listen: 127.0.0.1:53053
  default-nameserver: [114.114.114.114]
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver: [114.114.114.114]

proxies:
  - name: "DIRECT"
    type: direct
  - name: "REJECT"
    type: reject
  - name: "HK-01"
    type: ss
    server: hk1.example.com
    port: 8388
    cipher: aes-256-gcm
    password: "demo"
  - name: "US-01"
    type: ss
    server: us1.example.com
    port: 8388
    cipher: aes-256-gcm
    password: "demo"
  - name: "JP-01"
    type: ss
    server: jp1.example.com
    port: 8388
    cipher: aes-256-gcm
    password: "demo"
  - name: "SG-01"
    type: ss
    server: sg1.example.com
    port: 8388
    cipher: aes-256-gcm
    password: "demo"

proxy-groups:
  - name: "Manual"
    type: select
    proxies: [HK-01, US-01, JP-01, SG-01, DIRECT, REJECT]
  - name: "Auto"
    type: url-test
    proxies: [HK-01, US-01, JP-01, SG-01]
    url: "http://www.gstatic.com/generate_204"
    interval: 300

rules:
  - MATCH,Auto
''';
  }

  // ============================================================
  // 引擎控制
  // ============================================================

  Future<void> _startEngine() async {
    if (_configPath == null || _cwd == null) return;
    setState(() => _busy = true);
    try {
      final rc = _bridge.engineStart(configPath: _configPath!, cwd: _cwd!);
      if (rc != 0) {
        _lastError = 'engine start failed: $rc (${_bridge.lastErrorMessage(rc)})';
        _engineRunning = _bridge.engineIsRunning();
        return;
      }
      _lastError = null;
      _engineRunning = _bridge.engineIsRunning();
      // 引擎启动后等几秒再拉节点
      await Future.delayed(const Duration(milliseconds: 800));
      await _refreshGroups();
      _startTrafficTimer();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _stopEngine() async {
    setState(() => _busy = true);
    _trafficTimer?.cancel();
    _trafficTimer = null;
    try {
      final rc = _bridge.engineStop();
      if (rc != 0) {
        _lastError = 'engine stop failed: $rc (${_bridge.lastErrorMessage(rc)})';
      } else {
        _lastError = null;
      }
      _engineRunning = _bridge.engineIsRunning();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      setState(() => _busy = false);
    }
  }

  // ============================================================
  // 节点 / 流量
  // ============================================================

  Future<void> _refreshGroups() async {
    if (_controller == null) return;
    try {
      final groups = await _controller!.getProxies();
      // 默认选 "Auto" 或 "Manual" 第一个
      final preferred = ['Auto', 'Manual', 'Selector', 'GLOBAL'];
      String? selected;
      for (final p in preferred) {
        if (groups.containsKey(p)) {
          selected = p;
          break;
        }
      }
      selected ??= groups.isNotEmpty ? groups.keys.first : null;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
      });
    } catch (e) {
      // controller 可能还没起
    }
  }

  Future<void> _selectNode(String name) async {
    if (_controller == null || _selectedGroup == null) return;
    setState(() => _busy = true);
    try {
      await _controller!.selectNode(_selectedGroup!, name);
      await _refreshGroups();
    } catch (e) {
      _lastError = '切换失败: $e';
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _checkAllDelays() async {
    if (_controller == null || _selectedGroup == null) return;
    setState(() => _checkingDelays = true);
    try {
      final delays = await _controller!.healthCheckGroup(_selectedGroup!);
      setState(() => _delays = delays);
    } catch (e) {
      _lastError = '延迟测试失败: $e';
    } finally {
      setState(() => _checkingDelays = false);
    }
  }

  void _startTrafficTimer() {
    _trafficTimer?.cancel();
    _trafficTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_controller == null || !_engineRunning) return;
      try {
        final stats = await _controller!.getTraffic();
        final now = DateTime.now();
        final dt = now.difference(_trafficLastUpdate).inMilliseconds / 1000.0;
        if (dt > 0) {
          final upDelta = stats.up - _trafficPrev.up;
          final downDelta = stats.down - _trafficPrev.down;
          _upRate = (upDelta / dt).clamp(0, 1e9).toInt();
          _downRate = (downDelta / dt).clamp(0, 1e9).toInt();
        }
        _traffic = stats;
        _trafficPrev = stats;
        _trafficLastUpdate = now;
        _totalUp = stats.up;
        _totalDown = stats.down;
        setState(() {});
      } catch (e) {
        // ignore
      }
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _formatRate(int bps) {
    if (bps < 1024) return '$bps B/s';
    if (bps < 1024 * 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
    if (bps < 1024 * 1024 * 1024) return '${(bps / 1024 / 1024).toStringAsFixed(1)} MB/s';
    return '${(bps / 1024 / 1024 / 1024).toStringAsFixed(2)} GB/s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              _engineRunning ? Icons.shield : Icons.shield_outlined,
              color: _engineRunning ? Colors.green : null,
            ),
            const SizedBox(width: 8),
            const Text('Proxy App'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        actions: [
          if (_checkingDelays)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.speed),
              tooltip: '健康检查',
              onPressed: _engineRunning && _selectedGroup != null ? _checkAllDelays : null,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新节点',
            onPressed: _engineRunning ? _refreshGroups : null,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_engineRunning) await _refreshGroups();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ========== 状态卡片 ==========
            _StatusCard(
              running: _engineRunning,
              version: _version,
            ),

            const SizedBox(height: 16),

            // ========== 流量卡片 ==========
            if (_engineRunning) ...[
              _TrafficCard(
                upRate: _upRate,
                downRate: _downRate,
                totalUp: _totalUp,
                totalDown: _totalDown,
                formatBytes: _formatBytes,
                formatRate: _formatRate,
              ),
              const SizedBox(height: 16),
            ],

            // ========== 节点选择 ==========
            if (_groups.isNotEmpty) ...[
              _GroupSelector(
                groups: _groups,
                selectedGroup: _selectedGroup,
                selectedNodeDelays: _delays,
                onSelectGroup: (name) => setState(() => _selectedGroup = name),
                onSelectNode: _selectNode,
                formatBytes: _formatBytes,
              ),
              const SizedBox(height: 16),
            ],

            // ========== 错误 / 提示 ==========
            if (_lastError != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ========== 调试信息 ==========
            _DebugSection(
              cwd: _cwd,
              configPath: _configPath,
              controller: _controller,
              engineRunning: _engineRunning,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || _engineRunning ? null : _startEngine,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('启动'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || !_engineRunning ? null : _stopEngine,
                  icon: const Icon(Icons.stop),
                  label: const Text('停止'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============== 组件 ==============

class _StatusCard extends StatelessWidget {
  final bool running;
  final String version;
  const _StatusCard({required this.running, required this.version});

  @override
  Widget build(BuildContext context) {
    final color = running ? Colors.green : Colors.grey;
    final icon = running ? Icons.shield : Icons.shield_outlined;
    final text = running ? 'Engine Running' : 'Engine Stopped';

    return Card(
      color: running
          ? Colors.green.withValues(alpha: 0.1)
          : Theme.of(context).colorScheme.surfaceContainer,
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
                    'core-bridge $version · clash-rs 内核',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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

class _TrafficCard extends StatelessWidget {
  final int upRate;
  final int downRate;
  final int totalUp;
  final int totalDown;
  final String Function(int) formatBytes;
  final String Function(int) formatRate;

  const _TrafficCard({
    required this.upRate,
    required this.downRate,
    required this.totalUp,
    required this.totalDown,
    required this.formatBytes,
    required this.formatRate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '实时流量',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.arrow_upward, color: Colors.orange, size: 20),
                const SizedBox(width: 6),
                Text(
                  formatRate(upRate),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.arrow_downward, color: Colors.blue, size: 20),
                const SizedBox(width: 6),
                Text(
                  formatRate(downRate),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '总计 ↑ ${formatBytes(totalUp)}  ↓ ${formatBytes(totalDown)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSelector extends StatelessWidget {
  final Map<String, ProxyGroup> groups;
  final String? selectedGroup;
  final Map<String, int> selectedNodeDelays;
  final ValueChanged<String> onSelectGroup;
  final ValueChanged<String> onSelectNode;
  final String Function(int) formatBytes;

  const _GroupSelector({
    required this.groups,
    required this.selectedGroup,
    required this.selectedNodeDelays,
    required this.onSelectGroup,
    required this.onSelectNode,
    required this.formatBytes,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    final selectedGroupObj =
        selectedGroup != null ? groups[selectedGroup!] : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分组选择
            Row(
              children: [
                Icon(Icons.folder, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                const Text('代理组',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: groups.keys.map((g) {
                final isSelected = g == selectedGroup;
                return ChoiceChip(
                  label: Text(g),
                  selected: isSelected,
                  onSelected: (_) => onSelectGroup(g),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 节点列表
            if (selectedGroupObj != null) ...[
              Row(
                children: [
                  Icon(Icons.list, color: Colors.cyan, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${selectedGroupObj.name} (${selectedGroupObj.type})',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (selectedGroupObj.now.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '当前: ${selectedGroupObj.now}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...selectedGroupObj.all.map((name) {
                final isCurrent = name == selectedGroupObj.now;
                final delay = selectedNodeDelays[name];
                return _NodeTile(
                  name: name,
                  isCurrent: isCurrent,
                  delay: delay,
                  onTap: () => onSelectNode(name),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  final String name;
  final bool isCurrent;
  final int? delay;
  final VoidCallback onTap;

  const _NodeTile({
    required this.name,
    required this.isCurrent,
    this.delay,
    required this.onTap,
  });

  Color _delayColor() {
    if (delay == null || delay == 0) return Colors.grey;
    if (delay! < 100) return Colors.green;
    if (delay! < 300) return Colors.orange;
    return Colors.red;
  }

  String _delayText() {
    if (delay == null) return '—';
    if (delay == 0) return 'timeout';
    return '${delay}ms';
  }

  IconData _nodeIcon() {
    if (name == 'DIRECT') return Icons.flash_on;
    if (name == 'REJECT') return Icons.block;
    return Icons.public;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent
              ? Colors.blue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isCurrent
              ? Border.all(color: Colors.blue, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Icon(_nodeIcon(),
                color: isCurrent ? Colors.blue : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent ? Colors.blue : null,
                ),
              ),
            ),
            if (delay != null) ...[
              Text(
                _delayText(),
                style: TextStyle(
                  fontSize: 12,
                  color: _delayColor(),
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (isCurrent)
              const Icon(Icons.check_circle, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DebugSection extends StatelessWidget {
  final String? cwd;
  final String? configPath;
  final ClashController? controller;
  final bool engineRunning;

  const _DebugSection({
    required this.cwd,
    required this.configPath,
    required this.controller,
    required this.engineRunning,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('调试',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            _DebugRow('引擎', engineRunning ? '运行中' : '已停止'),
            _DebugRow('控制器', controller?.baseUrl ?? '(未配置)'),
            _DebugRow('CWD', cwd ?? '-'),
            _DebugRow('Config', configPath ?? '-'),
          ],
        ),
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  final String label;
  final String value;
  const _DebugRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
                maxLines: 3),
          ),
        ],
      ),
    );
  }
}
