import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/proxy_app_controller.dart';
import '../desktop_app.dart' show DesktopColors;
import 'widgets.dart';

/// mac-1008 日志页面。
class LogsPage extends StatefulWidget {
  final ProxyAppController controller;
  const LogsPage({super.key, required this.controller});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final filter = TextEditingController();
  String level = 'ALL';
  bool paused = false;
  bool autoScroll = true;
  bool _caseSensitive = false;
  bool _regex = false;
  bool _wildcard = false;
  List<String>? _frozen;
  ScrollController? _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
  }

  @override
  void dispose() {
    filter.dispose();
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final source = paused ? (_frozen ?? const []) : widget.controller.logs;
        final logs = source
            .where((line) {
              if (level != 'ALL' && !line.contains('[$level]')) return false;
              final q = filter.text.trim();
              if (q.isEmpty) return true;
              if (_regex) {
                try {
                  return RegExp(
                    q,
                    caseSensitive: _caseSensitive,
                  ).hasMatch(line);
                } catch (_) {
                  return false;
                }
              }
              if (_wildcard) {
                return _globMatches(line, q, caseSensitive: _caseSensitive);
              }
              return _caseSensitive
                  ? line.contains(q)
                  : line.toLowerCase().contains(q.toLowerCase());
            })
            .map(widget.controller.redactLog)
            .toList();
        return Column(
          children: [
            // 工具栏：级别 + 过滤 + 暂停 + 自动滚动 + 清空 + 导出
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
              child: Row(
                children: [
                  _LevelDropdown(
                    value: level,
                    onChanged: (v) => setState(() => level = v!),
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
                  _ToggleBtn(
                    icon: Icons.pause_circle_outline,
                    tooltip: '暂停',
                    selected: paused,
                    onTap: () => setState(() {
                      paused = !paused;
                      _frozen = paused ? [...widget.controller.logs] : null;
                    }),
                  ),
                  const SizedBox(width: 4),
                  _ToggleBtn(
                    icon: Icons.vertical_align_bottom,
                    tooltip: '自动滚动',
                    selected: autoScroll,
                    onTap: () => setState(() => autoScroll = !autoScroll),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '复制筛选结果',
                    onPressed: logs.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: logs.join('\n')),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已复制 ${logs.length} 条日志'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.copy_all_outlined),
                  ),
                  IconButton(
                    tooltip: '清空',
                    onPressed: widget.controller.clearLogs,
                    icon: const Icon(Icons.delete_sweep),
                  ),
                  IconButton(
                    tooltip: '导出',
                    onPressed: () async {
                      final file = await widget.controller.exportLogs();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已导出：${file.path}')),
                      );
                    },
                    icon: const Icon(Icons.download),
                  ),
                ],
              ),
            ),
            Expanded(
              child: logs.isEmpty
                  ? const RsEmpty(icon: Icons.segment, title: '暂无匹配日志')
                  : ListView.builder(
                      controller: autoScroll ? _scroll : null,
                      reverse: autoScroll,
                      padding: const EdgeInsets.fromLTRB(10, 3, 10, 10),
                      itemCount: logs.length,
                      itemBuilder: (_, i) => _LogLine(
                        text: autoScroll ? logs[logs.length - i - 1] : logs[i],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

bool _globMatches(String value, String pattern, {required bool caseSensitive}) {
  final escaped = RegExp.escape(pattern)
      .replaceAll(r'\*', '.*')
      .replaceAll(r'\?', '.');
  return RegExp('^$escaped\$', caseSensitive: caseSensitive).hasMatch(value);
}

class _LogLine extends StatelessWidget {
  final String text;
  const _LogLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final level = _detectLevel(text);
    final color = switch (level) {
      'ERROR' => Colors.redAccent,
      'WARN' => const Color(0xFFFFA20F),
      'INFO' => const Color(0xFF168BFA),
      'DEBUG' => const Color(0xFF6E7280),
      _ => const Color(0xFFCDCED4),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText(
        text,
        style: TextStyle(
          color: color,
          fontFamily: 'monospace',
          fontSize: 11,
          height: 1.35,
        ),
      ),
    );
  }

  String _detectLevel(String s) {
    final m = RegExp(r'\[(DEBUG|INFO|WARN|ERROR)\]').firstMatch(s);
    return m?.group(1) ?? '';
  }
}

class _LevelDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _LevelDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF252936),
      border: Border.all(color: const Color(0xFF168BFA)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        dropdownColor: const Color(0xFF292C39),
        items: const [
          'ALL',
          'DEBUG',
          'INFO',
          'WARN',
          'ERROR',
        ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleBtn({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: selected ? const Color(0xFF168BFA) : DesktopColors.muted,
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
