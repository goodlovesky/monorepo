import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/proxy_app_controller.dart';
import '../desktop_app.dart' show DesktopColors;

/// 面向用户统一隐藏底层 Socket/Timeout/HTTP 异常细节。
String proxyProbeFailureLabel(Object? _) => '代理异常';

/// mac-1009 解锁测试页面。
class TestPage extends StatefulWidget {
  final ProxyAppController controller;
  const TestPage({super.key, required this.controller});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  static final _defaults = <_Target>[
    _Target('Apple', 'https://www.apple.com/library/test/success.html'),
    _Target('GitHub', 'https://github.com'),
    _Target('Google', 'https://www.google.com/generate_204'),
    _Target('YouTube', 'https://www.youtube.com/generate_204'),
    _Target('ChatGPT iOS', 'https://ios.chat.openai.com'),
    _Target('ChatGPT Web', 'https://chatgpt.com'),
    _Target('Claude', 'https://claude.ai'),
    _Target('Disney+', 'https://www.disneyplus.com'),
    _Target('Gemini', 'https://gemini.google.com'),
    _Target('Netflix', 'https://www.netflix.com'),
    _Target('Prime Video', 'https://www.primevideo.com'),
    _Target('Spotify', 'https://open.spotify.com'),
    _Target('TikTok', 'https://www.tiktok.com'),
    _Target('YouTube Premium', 'https://www.youtube.com/premium'),
  ];
  late List<_Target> _targets;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _targets = _decodeTargets(widget.controller.settings.meta['test.targets']);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _runOne(_Target t) async {
    t
      ..state = _State.running
      ..error = null
      ..latency = null
      ..path = null
      ..statusCode = null;
    setState(() {});
    final result = await widget.controller.probeUrl(
      t.uri.toString(),
      timeoutMs: 6000,
    );
    if (!mounted || _cancelled) return;
    if (result.ok) {
      t
        ..latency = result.latencyMs
        ..statusCode = result.statusCode
        ..path = result.path
        ..state = _State.success;
    } else {
      t
        ..error = proxyProbeFailureLabel(result.error)
        ..statusCode = result.statusCode
        ..path = result.path
        ..state = _State.failed;
    }
    t.updatedAt = DateTime.now();
    setState(() {});
  }

  Future<void> _runAll() async {
    _cancelled = false;
    for (final t in _targets) {
      if (!mounted) return;
      await _runOne(t);
    }
  }

  void _cancel() {
    _cancelled = true;
    for (final t in _targets) {
      if (t.state == _State.running) t.state = _State.cancelled;
    }
    setState(() {});
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final url = TextEditingController(text: 'https://');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加测试项'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: url,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final uri = Uri.tryParse(url.text.trim());
      if (name.text.trim().isNotEmpty &&
          uri != null &&
          {'http', 'https'}.contains(uri.scheme)) {
        setState(() => _targets.add(_Target(name.text.trim(), uri.toString())));
        await _persistTargets();
      }
    }
    name.dispose();
    url.dispose();
  }

  Future<void> _edit(int index) async {
    final target = _targets[index];
    final name = TextEditingController(text: target.name);
    final url = TextEditingController(text: target.uri.toString());
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑测试项'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: url,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final uri = Uri.tryParse(url.text.trim());
      if (name.text.trim().isNotEmpty &&
          uri != null &&
          {'http', 'https'}.contains(uri.scheme)) {
        setState(() {
          target
            ..name = name.text.trim()
            ..uri = uri
            ..state = _State.idle
            ..latency = null
            ..error = null;
        });
        await _persistTargets();
      }
    }
    name.dispose();
    url.dispose();
  }

  List<_Target> _decodeTargets(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return _defaults.map((t) => _Target(t.name, t.uri.toString())).toList();
    }
    try {
      final values = jsonDecode(encoded) as List;
      final parsed = values
          .whereType<Map>()
          .map(
            (item) => _Target(
              item['name']?.toString() ?? '',
              item['url']?.toString() ?? '',
            ),
          )
          .where(
            (item) =>
                item.name.isNotEmpty &&
                {'http', 'https'}.contains(item.uri.scheme),
          )
          .toList();
      return parsed.isEmpty
          ? _defaults.map((t) => _Target(t.name, t.uri.toString())).toList()
          : parsed;
    } catch (_) {
      return _defaults.map((t) => _Target(t.name, t.uri.toString())).toList();
    }
  }

  Future<void> _persistTargets() => widget.controller.updateSettings(
    widget.controller.settings.copyWith(
      meta: {
        ...widget.controller.settings.meta,
        'test.targets': jsonEncode(
          _targets
              .map((t) => {'name': t.name, 'url': t.uri.toString()})
              .toList(),
        ),
      },
    ),
    restartVpn: false,
  );

  Future<void> _resetTargets() async {
    setState(() {
      _targets = _defaults
          .map((t) => _Target(t.name, t.uri.toString()))
          .toList();
    });
    await _persistTargets();
  }

  Future<void> _copyTargets() async {
    await Clipboard.setData(
      ClipboardData(
        text: jsonEncode(
          _targets
              .map((t) => {'name': t.name, 'url': t.uri.toString()})
              .toList(),
        ),
      ),
    );
  }

  Future<void> _pasteTargets() async {
    final text = (await Clipboard.getData('text/plain'))?.text;
    final parsed = _decodeTargets(text);
    setState(() => _targets = parsed);
    await _persistTargets();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '解锁测试',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                tooltip: '从剪贴板导入',
                onPressed: _pasteTargets,
                icon: const Icon(Icons.content_paste),
              ),
              IconButton(
                tooltip: '导出到剪贴板',
                onPressed: _copyTargets,
                icon: const Icon(Icons.copy_all_outlined),
              ),
              IconButton(
                tooltip: '恢复默认',
                onPressed: _resetTargets,
                icon: const Icon(Icons.restore),
              ),
              IconButton(
                tooltip: '添加',
                onPressed: _add,
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: '取消',
                onPressed: _cancel,
                icon: const Icon(Icons.stop),
              ),
              FilledButton.icon(
                onPressed: _runAll,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF168BFA),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('测试全部'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisExtent: 130,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: _targets.length,
              itemBuilder: (_, i) => _TargetCard(
                target: _targets[i],
                onRun: () => _runOne(_targets[i]),
                onEdit: () => _edit(i),
                onDelete: () async {
                  setState(() => _targets.removeAt(i));
                  await _persistTargets();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _State { idle, running, success, failed, cancelled }

class _Target {
  String name;
  Uri uri;
  _State state = _State.idle;
  int? latency;
  String? error;
  String? path;
  int? statusCode;
  DateTime? updatedAt;
  _Target(this.name, String url) : uri = Uri.parse(url);
}

class _TargetCard extends StatelessWidget {
  final _Target target;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TargetCard({
    required this.target,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (target.state) {
      _State.success => const Color(0xFF2AD364),
      _State.failed => Colors.redAccent,
      _State.running => const Color(0xFF168BFA),
      _State.cancelled => const Color(0xFFFFA20F),
      _State.idle => DesktopColors.muted,
    };
    final baseStateText = switch (target.state) {
      _State.success => target.latency == null ? '成功' : '${target.latency} ms',
      _State.failed => target.error ?? '代理异常',
      _State.running => '检测中…',
      _State.cancelled => '已取消',
      _State.idle => '待检测',
    };
    final stamp = target.updatedAt;
    final details = [
      if (target.path != null) target.path!,
      if (target.statusCode != null) 'HTTP ${target.statusCode}',
    ].join(' · ');
    final stateText = stamp == null
        ? baseStateText
        : '$baseStateText · ${stamp.hour.toString().padLeft(2, '0')}:${stamp.minute.toString().padLeft(2, '0')}:${stamp.second.toString().padLeft(2, '0')}${details.isEmpty ? '' : ' · $details'}';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF292C39),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  target.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onRun,
                child: Icon(
                  Icons.refresh,
                  color: const Color(0xFF168BFA),
                  size: 22,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '编辑测试项',
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
                icon: const Icon(Icons.more_horiz, size: 20),
              ),
            ],
          ),
          Text(
            target.uri.host,
            style: const TextStyle(color: DesktopColors.muted, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.face_retouching_natural, size: 12, color: color),
                const SizedBox(width: 4),
                Text(stateText, style: TextStyle(color: color, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
