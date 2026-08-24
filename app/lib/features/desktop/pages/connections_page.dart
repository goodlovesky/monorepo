import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/proxy_app_controller.dart';
import '../desktop_app.dart' show DesktopColors;
import 'widgets.dart';

/// mac-1006 连接页面：实时连接表 + 上下行汇总 + 过滤语法。
class ConnectionsPage extends StatefulWidget {
  final ProxyAppController controller;
  const ConnectionsPage({super.key, required this.controller});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  final filter = TextEditingController();
  bool descending = true;
  bool _showActive = true;
  bool _caseSensitive = false;
  bool _regex = false;
  bool _wildcard = false;
  final List<Map<String, dynamic>> _closed = [];
  final Map<String, ({int upload, int download})> _lastBytes = {};
  final Map<String, ({double upload, double download})> _speeds = {};
  DateTime? _lastSampleAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_poll());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  Future<void> _poll() async {
    final before = {
      for (final item in widget.controller.connections)
        if (item['id'] != null)
          item['id'].toString(): Map<String, dynamic>.from(item),
    };
    await widget.controller.refreshConnections();
    final now = DateTime.now();
    final elapsed = _lastSampleAt == null
        ? 0.0
        : now.difference(_lastSampleAt!).inMilliseconds / 1000;
    final nextBytes = <String, ({int upload, int download})>{};
    final nextSpeeds = <String, ({double upload, double download})>{};
    for (final item in widget.controller.connections) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final upload = ((item['upload'] as num?) ?? 0).toInt();
      final download = ((item['download'] as num?) ?? 0).toInt();
      final previous = _lastBytes[id];
      nextBytes[id] = (upload: upload, download: download);
      nextSpeeds[id] = (
        upload: previous == null || elapsed <= 0
            ? 0
            : (upload - previous.upload).clamp(0, double.infinity) / elapsed,
        download: previous == null || elapsed <= 0
            ? 0
            : (download - previous.download).clamp(0, double.infinity) /
                  elapsed,
      );
    }
    _lastBytes
      ..clear()
      ..addAll(nextBytes);
    _speeds
      ..clear()
      ..addAll(nextSpeeds);
    _lastSampleAt = now;
    final activeIds = widget.controller.connections
        .map((item) => item['id']?.toString())
        .whereType<String>()
        .toSet();
    for (final entry in before.entries) {
      if (!activeIds.contains(entry.key) &&
          !_closed.any((item) => item['id']?.toString() == entry.key)) {
        _closed.insert(0, {
          ...entry.value,
          'closedAt': DateTime.now().toIso8601String(),
        });
      }
    }
    if (_closed.length > 500) _closed.removeRange(500, _closed.length);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final source = _showActive ? widget.controller.connections : _closed;
        final items =
            source.where((m) {
              final q = filter.text.trim();
              if (q.isEmpty) return true;
              final value = m.toString();
              if (_regex) {
                try {
                  return RegExp(
                    q,
                    caseSensitive: _caseSensitive,
                  ).hasMatch(value);
                } catch (_) {
                  return false;
                }
              }
              if (_wildcard) {
                return _globMatches(value, q, caseSensitive: _caseSensitive);
              }
              return _caseSensitive
                  ? value.contains(q)
                  : value.toLowerCase().contains(q.toLowerCase());
            }).toList()..sort((a, b) {
              final av =
                  ((a['upload'] as num?) ?? 0).toInt() +
                  ((a['download'] as num?) ?? 0).toInt();
              final bv =
                  ((b['upload'] as num?) ?? 0).toInt() +
                  ((b['download'] as num?) ?? 0).toInt();
              return descending ? bv.compareTo(av) : av.compareTo(bv);
            });

        final totalUp = _showActive
            ? widget.controller.connectionUploadTotal
            : items.fold<int>(
                0,
                (sum, c) => sum + ((c['upload'] as num?) ?? 0).toInt(),
              );
        final totalDown = _showActive
            ? widget.controller.connectionDownloadTotal
            : items.fold<int>(
                0,
                (sum, c) => sum + ((c['download'] as num?) ?? 0).toInt(),
              );

        return Column(
          children: [
            // 顶部：上传/下载汇总 + 关闭全部
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
              child: Row(
                children: [
                  Text(
                    '下载量：${_bytes(totalDown)}',
                    style: const TextStyle(color: DesktopColors.muted),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    '上传量：${_bytes(totalUp)}',
                    style: const TextStyle(color: DesktopColors.muted),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: items.isEmpty
                        ? null
                        : widget.controller.closeAllConnections,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF168BFA),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('关闭全部'),
                  ),
                ],
              ),
            ),
            // 工具栏：活跃/已关闭 + 过滤 + 语法按钮 + 排序 + 刷新
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 5),
              child: Row(
                children: [
                  _ToggleChip(
                    label: '活跃 ${widget.controller.connections.length}',
                    selected: _showActive,
                    onTap: () => setState(() => _showActive = true),
                  ),
                  const SizedBox(width: 8),
                  _ToggleChip(
                    label: '已关闭 ${_closed.length}',
                    selected: !_showActive,
                    onTap: () => setState(() => _showActive = false),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: filter,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '过滤条件',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: const Color(0xFF252936),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF444756),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF444756),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SyntaxBtn(
                    label: 'Aa',
                    tooltip: '区分大小写',
                    selected: _caseSensitive,
                    onTap: () =>
                        setState(() => _caseSensitive = !_caseSensitive),
                  ),
                  const SizedBox(width: 4),
                  _SyntaxBtn(
                    label: 'ab',
                    tooltip: '正则表达式',
                    selected: _regex,
                    onTap: () => setState(() => _regex = !_regex),
                  ),
                  const SizedBox(width: 4),
                  _SyntaxBtn(
                    label: '*',
                    tooltip: '通配符',
                    selected: _wildcard,
                    onTap: () => setState(() {
                      _wildcard = !_wildcard;
                      if (_wildcard) _regex = false;
                    }),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '按流量排序',
                    onPressed: () => setState(() => descending = !descending),
                    icon: Icon(
                      descending ? Icons.arrow_downward : Icons.arrow_upward,
                    ),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: _poll,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            // 表头
            _TableHeader(
              descending: descending,
              onSort: () {
                setState(() => descending = !descending);
              },
            ),
            const Divider(height: 1, color: Color(0xFF2A2D38)),
            Expanded(
              child: items.isEmpty
                  ? const RsEmpty(icon: Icons.language, title: '当前没有匹配的活动连接')
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final speed =
                            _speeds[item['id']?.toString()] ??
                            (upload: 0.0, download: 0.0);
                        return _ConnectionRow(
                          item: item,
                          uploadSpeed: speed.upload,
                          downloadSpeed: speed.download,
                          onClose: _showActive
                              ? () {
                                  final id = item['id']?.toString() ?? '';
                                  if (id.isNotEmpty) {
                                    widget.controller.closeConnection(id);
                                  }
                                }
                              : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF168BFA) : const Color(0xFF252936),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFCDCED4),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _SyntaxBtn extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  const _SyntaxBtn({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: selected ? const Color(0xFF168BFA) : const Color(0xFF252936),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : DesktopColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

class _TableHeader extends StatelessWidget {
  final bool descending;
  final VoidCallback onSort;
  const _TableHeader({required this.descending, required this.onSort});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
    child: Row(
      children: [
        const Expanded(
          flex: 4,
          child: Text(
            '主机',
            style: TextStyle(color: DesktopColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            '下载量',
            style: TextStyle(color: DesktopColors.muted, fontSize: 12),
          ),
        ),
        SizedBox(
          width: 90,
          child: Text(
            '上传量',
            style: TextStyle(color: DesktopColors.muted, fontSize: 12),
          ),
        ),
        SizedBox(
          width: 80,
          child: Text(
            '下载速度',
            style: TextStyle(color: DesktopColors.muted, fontSize: 12),
          ),
        ),
        SizedBox(
          width: 80,
          child: Text(
            '上传速度',
            style: TextStyle(color: DesktopColors.muted, fontSize: 12),
          ),
        ),
        const Expanded(
          flex: 3,
          child: Text(
            '规则 / 链路',
            style: TextStyle(color: DesktopColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 32,
          child: Text(
            '',
            style: TextStyle(color: DesktopColors.muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _ConnectionRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final double uploadSpeed;
  final double downloadSpeed;
  final VoidCallback? onClose;
  const _ConnectionRow({
    required this.item,
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = item['metadata'] as Map? ?? const {};
    final hostName = (metadata['host']?.toString().isNotEmpty == true)
        ? metadata['host'].toString()
        : (metadata['destinationIP']?.toString() ?? '未知目标');
    final destinationPort = metadata['destinationPort']?.toString() ?? '';
    final host =
        destinationPort.isEmpty || hostName.endsWith(':$destinationPort')
        ? hostName
        : '$hostName:$destinationPort';
    final source =
        '${metadata['sourceIP'] ?? ''}:${metadata['sourcePort'] ?? ''}';
    final target =
        '${metadata['destinationIP'] ?? ''}:${metadata['destinationPort'] ?? ''}';
    final chainItems = (item['chains'] as List?)?.reversed.toList() ?? const [];
    final chains = chainItems.isEmpty ? 'DIRECT' : chainItems.join(' / ');
    final rule = [item['rule'], item['rulePayload']]
        .where((value) => value != null && value.toString().isNotEmpty)
        .join(' / ');
    final up = ((item['upload'] as num?) ?? 0).toInt();
    final down = ((item['download'] as num?) ?? 0).toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF252A35), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  host,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$source → $target',
                  style: const TextStyle(
                    color: DesktopColors.muted,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(_bytes(down), style: const TextStyle(fontSize: 12)),
          ),
          SizedBox(
            width: 90,
            child: Text(_bytes(up), style: const TextStyle(fontSize: 12)),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _speed(downloadSpeed),
              style: const TextStyle(color: DesktopColors.muted, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _speed(uploadSpeed),
              style: const TextStyle(color: DesktopColors.muted, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              rule.isEmpty ? chains : '$rule · $chains',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onClose,
              icon: const Icon(
                Icons.close,
                size: 16,
                color: DesktopColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _bytes(int v) {
  if (v >= 1 << 30) return '${(v / (1 << 30)).toStringAsFixed(2)} GB';
  if (v >= 1 << 20) return '${(v / (1 << 20)).toStringAsFixed(2)} MB';
  if (v >= 1 << 10) return '${(v / (1 << 10)).toStringAsFixed(2)} KB';
  return '$v B';
}

String _speed(double value) {
  if (value >= 1 << 20) return '${(value / (1 << 20)).toStringAsFixed(2)} MB/s';
  if (value >= 1 << 10) return '${(value / (1 << 10)).toStringAsFixed(2)} KB/s';
  return '${value.toStringAsFixed(2)} B/s';
}

bool _globMatches(String value, String pattern, {required bool caseSensitive}) {
  final escaped = RegExp.escape(pattern)
      .replaceAll(r'\*', '.*')
      .replaceAll(r'\?', '.');
  return RegExp('^$escaped\$', caseSensitive: caseSensitive).hasMatch(value);
}
