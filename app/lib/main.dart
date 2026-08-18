// lib/main.dart
//
// Phase 1.1 - 模仿 Clash Meta for Android 主屏设计
// 风格：暗色 + 大卡片 + 衬线字体
// 顶部 Logo + 标题
// 启动状态大卡片（点击切换）
// 配置大卡片
// 列表：日志 / 设置 / 帮助 / 关于

import 'dart:async';
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
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF000000),
          primary: Color(0xFFE0E0E0),
          onPrimary: Color(0xFF000000),
          secondary: Color(0xFFB0B0B0),
          onSurface: Color(0xFFE8E8E8),
          surfaceContainer: Color(0xFF1A1A1A),
          surfaceContainerHigh: Color(0xFF242424),
          surfaceContainerLow: Color(0xFF141414),
        ),
        textTheme: const TextTheme(
          // 标题用衬线（接近原版"Clash Meta for Android"标题）
          displayLarge: TextStyle(
            fontFamily: 'serif',
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: Color(0xFFE8E8E8),
            letterSpacing: 0.5,
          ),
          // 中文大标题（卡片主文字）
          headlineLarge: TextStyle(
            fontFamily: 'serif',
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: Color(0xFFE8E8E8),
          ),
          headlineMedium: TextStyle(
            fontFamily: 'serif',
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: Color(0xFFE8E8E8),
          ),
          // 副标题
          titleMedium: TextStyle(
            fontFamily: 'serif',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFFB0B0B0),
          ),
          // 列表项
          bodyLarge: TextStyle(
            fontFamily: 'serif',
            fontSize: 18,
            color: Color(0xFFE8E8E8),
          ),
          bodyMedium: TextStyle(
            fontFamily: 'serif',
            fontSize: 14,
            color: Color(0xFFB0B0B0),
          ),
        ),
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
  int _upRate = 0;
  int _downRate = 0;
  Timer? _trafficTimer;
  int _totalUp = 0;
  int _totalDown = 0;

  // 节点（启动后才填）
  Map<String, ProxyGroup> _groups = {};
  String? _selectedGroup;
  Map<String, int> _delays = {};
  bool _checkingDelays = false;

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

  Future<void> _bootstrap() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      _cwd = supportDir.path;
      final cfgFile = File('$_cwd/config.yaml');
      if (!await cfgFile.exists()) {
        await cfgFile.writeAsString(_buildTestConfig());
      }
      _configPath = cfgFile.path;

      final cfg = await cfgFile.readAsString();
      final ctrl = ClashConfigParser.parseController(cfg);
      if (ctrl != null) {
        _controller = ClashController(
          baseUrl: 'http://${ctrl.host}:${ctrl.port}',
          secret: ctrl.secret.isEmpty ? null : ctrl.secret,
        );
      }

      _version = _bridge.version();
      _bridge.init(homeDir: _cwd!, version: _version, sdk: 35);
      _engineRunning = _bridge.engineIsRunning();
    } catch (e) {
      _lastError = e.toString();
    }
    if (mounted) setState(() {});
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

  Future<void> _toggleEngine() async {
    if (_busy) return;
    if (_engineRunning) {
      await _stopEngine();
    } else {
      await _startEngine();
    }
  }

  Future<void> _startEngine() async {
    if (_configPath == null || _cwd == null) return;
    setState(() => _busy = true);
    try {
      final rc = _bridge.engineStart(configPath: _configPath!, cwd: _cwd!);
      if (rc != 0) {
        _lastError = '启动失败: $rc (${_bridge.lastErrorMessage(rc)})';
        _engineRunning = _bridge.engineIsRunning();
        return;
      }
      _lastError = null;
      _engineRunning = _bridge.engineIsRunning();
      await Future.delayed(const Duration(milliseconds: 800));
      await _refreshGroups();
      _startTrafficTimer();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopEngine() async {
    setState(() => _busy = true);
    _trafficTimer?.cancel();
    _trafficTimer = null;
    try {
      final rc = _bridge.engineStop();
      if (rc != 0) {
        _lastError = '停止失败: $rc (${_bridge.lastErrorMessage(rc)})';
      } else {
        _lastError = null;
      }
      _engineRunning = _bridge.engineIsRunning();
      _traffic = TrafficStats.zero;
      _upRate = 0;
      _downRate = 0;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ============================================================
  // 节点 / 流量
  // ============================================================

  Future<void> _refreshGroups() async {
    if (_controller == null) return;
    try {
      final groups = await _controller!.getProxies();
      final preferred = ['Auto', 'Manual', 'Selector'];
      String? selected;
      for (final p in preferred) {
        if (groups.containsKey(p)) {
          selected = p;
          break;
        }
      }
      selected ??= groups.isNotEmpty ? groups.keys.first : null;
      _groups = groups;
      _selectedGroup = selected;
    } catch (_) {}
  }

  Future<void> _selectNode(String name) async {
    if (_controller == null || _selectedGroup == null) return;
    try {
      await _controller!.selectNode(_selectedGroup!, name);
      await _refreshGroups();
    } catch (e) {
      _lastError = '切换失败: $e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _checkAllDelays() async {
    if (_controller == null || _selectedGroup == null) return;
    setState(() => _checkingDelays = true);
    try {
      _delays = await _controller!.healthCheckGroup(_selectedGroup!);
    } catch (e) {
      _lastError = '延迟测试失败: $e';
    }
    if (mounted) setState(() => _checkingDelays = false);
  }

  void _startTrafficTimer() {
    _trafficTimer?.cancel();
    var prev = TrafficStats.zero;
    var lastT = DateTime.now();
    _trafficTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_controller == null || !_engineRunning) return;
      try {
        final stats = await _controller!.getTraffic();
        final now = DateTime.now();
        final dt = now.difference(lastT).inMilliseconds / 1000.0;
        if (dt > 0) {
          _upRate = ((stats.up - prev.up) / dt).clamp(0, 1e9).toInt();
          _downRate = ((stats.down - prev.down) / dt).clamp(0, 1e9).toInt();
        }
        prev = stats;
        lastT = now;
        _traffic = stats;
        _totalUp = stats.up;
        _totalDown = stats.down;
        if (mounted) setState(() {});
      } catch (_) {}
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

  // ============================================================
  // 详情页（点击列表项进入）
  // ============================================================

  void _openLogs() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('日志', style: TextStyle(fontFamily: 'serif'))),
        body: const Center(
          child: Text('日志页面 (Phase 2)', style: TextStyle(fontFamily: 'serif')),
        ),
      ),
    ));
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _SettingsPage(version: _version),
    ));
  }

  void _openHelp() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const _HelpPage(),
    ));
  }

  void _openAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Proxy App',
      applicationVersion: '0.1.0',
      applicationLegalese: 'Apache-2.0',
      children: const [
        SizedBox(height: 16),
        Text(
          'Flutter + Rust (clash-rs) 跨平台代理客户端',
          style: TextStyle(fontFamily: 'serif'),
        ),
        SizedBox(height: 8),
        Text('仓库: github.com/goodlovesky/monorepo',
            style: TextStyle(fontFamily: 'serif', fontSize: 12)),
      ],
    );
  }

  void _openProxy() {
    // 节点选择页（启动后才进）
    if (!_engineRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先启动引擎')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ProxyPage(
        controller: _controller!,
        groups: _groups,
        selectedGroup: _selectedGroup,
        delays: _delays,
        onSelectGroup: (g) => setState(() => _selectedGroup = g),
        onSelectNode: _selectNode,
        onCheckDelays: _checkAllDelays,
        checkingDelays: _checkingDelays,
        upRate: _upRate,
        downRate: _downRate,
        totalUp: _totalUp,
        totalDown: _totalDown,
        formatBytes: _formatBytes,
        formatRate: _formatRate,
      ),
    )).then((_) => _refreshGroups().then((_) => setState(() {})));
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const SizedBox(height: 8),

            // ========== 标题 ==========
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.shield, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Proxy App',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFE8E8E8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Flutter × clash-rs · $_version',
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 13,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ========== 启动状态大卡片 ==========
            _StatusHeroCard(
              running: _engineRunning,
              busy: _busy,
              upRate: _upRate,
              downRate: _downRate,
              onTap: _toggleEngine,
              onOpenProxy: _openProxy,
              formatRate: _formatRate,
            ),

            const SizedBox(height: 16),

            // ========== 配置卡片 ==========
            _ConfigCard(
              active: true,
              proxyCount: _engineRunning ? _groups.length : 0,
              onTap: _openProxy,
            ),

            const SizedBox(height: 36),

            // ========== 列表 ==========
            _MenuItem(
              icon: Icons.description_outlined,
              title: '日志',
              onTap: _openLogs,
            ),
            const SizedBox(height: 24),
            _MenuItem(
              icon: Icons.settings_outlined,
              title: '设置',
              onTap: _openSettings,
            ),
            const SizedBox(height: 24),
            _MenuItem(
              icon: Icons.help_outline,
              title: '帮助',
              onTap: _openHelp,
            ),
            const SizedBox(height: 24),
            _MenuItem(
              icon: Icons.info_outline,
              title: '关于',
              onTap: _openAbout,
            ),

            if (_lastError != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D1F1F),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFFF6B6B), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastError!,
                        style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 13,
                            color: Color(0xFFFFB0B0)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============== 启动状态大卡片 ==============

class _StatusHeroCard extends StatelessWidget {
  final bool running;
  final bool busy;
  final int upRate;
  final int downRate;
  final VoidCallback onTap;
  final VoidCallback onOpenProxy;
  final String Function(int) formatRate;

  const _StatusHeroCard({
    required this.running,
    required this.busy,
    required this.upRate,
    required this.downRate,
    required this.onTap,
    required this.onOpenProxy,
    required this.formatRate,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: running
                      ? const Color(0xFF2E5B3E)
                      : const Color(0xFF2A2A2A),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: running
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFF606060),
                    width: 2,
                  ),
                ),
                child: busy
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFFB0B0B0),
                          ),
                        ),
                      )
                    : Icon(
                        running ? Icons.check_circle_outline : Icons.do_not_disturb_on,
                        color: running
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFF909090),
                        size: 36,
                      ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      running ? '已连接' : '已停止',
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE8E8E8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      running ? '点此停止' : '点此启动',
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        color: Color(0xFF8A8A8A),
                      ),
                    ),
                    if (running && (upRate > 0 || downRate > 0)) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.arrow_upward,
                              size: 14, color: Colors.orange[300]),
                          const SizedBox(width: 4),
                          Text(
                            formatRate(upRate),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.orange[300],
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.arrow_downward,
                              size: 14, color: Colors.blue[300]),
                          const SizedBox(width: 4),
                          Text(
                            formatRate(downRate),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.blue[300],
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (running)
                IconButton(
                  icon: const Icon(Icons.tune, color: Color(0xFFB0B0B0)),
                  tooltip: '节点选择',
                  onPressed: onOpenProxy,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============== 配置卡片 ==============

class _ConfigCard extends StatelessWidget {
  final bool active;
  final int proxyCount;
  final VoidCallback onTap;

  const _ConfigCard({
    required this.active,
    required this.proxyCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dashboard_customize_outlined,
                    color: Color(0xFFE0E0E0), size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '配  置',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE8E8E8),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      proxyCount > 0
                          ? '$proxyCount 个代理组已激活'
                          : '新配置已激活',
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 14,
                        color: Color(0xFF8A8A8A),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF606060)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============== 列表项 ==============

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFE0E0E0), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18,
                  color: Color(0xFFE8E8E8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============== 节点选择页 ==============

class _ProxyPage extends StatelessWidget {
  final ClashController controller;
  final Map<String, ProxyGroup> groups;
  final String? selectedGroup;
  final Map<String, int> delays;
  final ValueChanged<String> onSelectGroup;
  final ValueChanged<String> onSelectNode;
  final VoidCallback onCheckDelays;
  final bool checkingDelays;
  final int upRate;
  final int downRate;
  final int totalUp;
  final int totalDown;
  final String Function(int) formatBytes;
  final String Function(int) formatRate;

  const _ProxyPage({
    required this.controller,
    required this.groups,
    required this.selectedGroup,
    required this.delays,
    required this.onSelectGroup,
    required this.onSelectNode,
    required this.onCheckDelays,
    required this.checkingDelays,
    required this.upRate,
    required this.downRate,
    required this.totalUp,
    required this.totalDown,
    required this.formatBytes,
    required this.formatRate,
  });

  @override
  Widget build(BuildContext context) {
    final group = selectedGroup != null ? groups[selectedGroup!] : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('节点选择', style: TextStyle(fontFamily: 'serif')),
        backgroundColor: const Color(0xFF000000),
        actions: [
          IconButton(
            icon: checkingDelays
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed),
            tooltip: '健康检查',
            onPressed: checkingDelays ? null : onCheckDelays,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 流量
          Card(
            color: const Color(0xFF1A1A1A),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('↑ 上行',
                              style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 12,
                                  color: Color(0xFF8A8A8A))),
                          Text(formatRate(upRate),
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 18,
                                  color: Colors.orange)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('↓ 下行',
                              style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 12,
                                  color: Color(0xFF8A8A8A))),
                          Text(formatRate(downRate),
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 18,
                                  color: Colors.blue)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('总计 ↑ ${formatBytes(totalUp)}  ↓ ${formatBytes(totalDown)}',
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFF8A8A8A))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 代理组
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('没有代理组', style: TextStyle(fontFamily: 'serif', color: Color(0xFF8A8A8A))),
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: groups.keys.map((g) {
                final selected = g == selectedGroup;
                return ChoiceChip(
                  label: Text(g, style: const TextStyle(fontFamily: 'serif')),
                  selected: selected,
                  selectedColor: const Color(0xFF1E88E5),
                  backgroundColor: const Color(0xFF1F1F1F),
                  labelStyle: TextStyle(
                    fontFamily: 'serif',
                    color: selected ? Colors.white : const Color(0xFFE0E0E0),
                  ),
                  onSelected: (_) => onSelectGroup(g),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (group != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  '${group.name} · ${group.type}',
                  style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 14,
                      color: Color(0xFF8A8A8A)),
                ),
              ),
              ...group.all.map((name) {
                final isCurrent = name == group.now;
                final delay = delays[name];
                return _NodeTile(
                  name: name,
                  isCurrent: isCurrent,
                  delay: delay,
                  onTap: () => onSelectNode(name),
                );
              }),
            ],
          ],
        ],
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
    if (delay == null || delay == 0) return const Color(0xFF606060);
    if (delay! < 100) return const Color(0xFF4ADE80);
    if (delay! < 300) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  String _delayText() {
    if (delay == null) return '—';
    if (delay == 0) return 'timeout';
    return '$delay ms';
  }

  IconData _icon() {
    if (name == 'DIRECT') return Icons.flash_on;
    if (name == 'REJECT') return Icons.block;
    return Icons.public;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent
              ? const Color(0xFF1E88E5).withValues(alpha: 0.15)
              : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: isCurrent
              ? Border.all(color: const Color(0xFF1E88E5), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Icon(_icon(),
                color: isCurrent
                    ? const Color(0xFF1E88E5)
                    : const Color(0xFF8A8A8A),
                size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 15,
                  color: isCurrent ? Colors.white : const Color(0xFFE0E0E0),
                  fontWeight:
                      isCurrent ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            if (delay != null) ...[
              Text(
                _delayText(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: _delayColor(),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (isCurrent)
              const Icon(Icons.check_circle, color: Color(0xFF1E88E5), size: 18),
          ],
        ),
      ),
    );
  }
}

// ============== 设置页 ==============

class _SettingsPage extends StatelessWidget {
  final String version;
  const _SettingsPage({required this.version});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(fontFamily: 'serif')),
        backgroundColor: const Color(0xFF000000),
      ),
      body: ListView(
        children: [
          const _SettingSection(title: '基础'),
          _SettingItem(
            icon: Icons.info_outline,
            title: 'core-bridge 版本',
            subtitle: version,
          ),
          const _SettingSection(title: '调试'),
          _SettingItem(
            icon: Icons.bug_report_outlined,
            title: 'FFI 链路测试',
            subtitle: 'ping/pong',
            onTap: () {
              final p = ClashBridge.instance.pong('hello from settings');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(p ?? 'null')),
              );
            },
          ),
          _SettingItem(
            icon: Icons.refresh,
            title: '重新初始化',
            subtitle: 'proxy_init',
            onTap: () {
              ClashBridge.instance.init(
                  homeDir: '/tmp', version: version, sdk: 35);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已重新 init')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingSection extends StatelessWidget {
  final String title;
  const _SettingSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 12,
            color: Color(0xFF707070),
            letterSpacing: 1.5),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFB0B0B0)),
      title: Text(title, style: const TextStyle(fontFamily: 'serif')),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12, color: Color(0xFF8A8A8A))),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right, color: Color(0xFF606060)),
      onTap: onTap,
    );
  }
}

// ============== 帮助页 ==============

class _HelpPage extends StatelessWidget {
  const _HelpPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('帮助', style: TextStyle(fontFamily: 'serif')),
        backgroundColor: const Color(0xFF000000),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _HelpItem(
            title: '如何导入订阅?',
            body: 'Phase 2 即将支持。本期 demo 内置了几个示例节点。',
          ),
          _HelpItem(
            title: '如何添加节点?',
            body: '手动编辑 config.yaml 加入更多 proxies / proxy-groups。',
          ),
          _HelpItem(
            title: '什么是 clash-rs?',
            body: 'Rust 实现的 Clash.Meta 兼容代理内核，FFI 暴露给 Flutter 端。',
          ),
          _HelpItem(
            title: 'FFI 性能?',
            body: 'dart:ffi 零开销调用 + 静态链接整个内核，无运行时桥接成本。',
          ),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String title;
  final String body;
  const _HelpItem({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE8E8E8))),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 14,
                  color: Color(0xFFA0A0A0),
                  height: 1.5)),
        ],
      ),
    );
  }
}
