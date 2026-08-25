import 'package:flutter/material.dart';

import '../../../services/proxy_app_controller.dart';
import '../desktop_app.dart' show DesktopColors;
import 'widgets.dart';
import '../../../l10n/rs_text.dart';

/// mac-1007 规则页面：序号 + payload + 类型 + 策略。
class RulesPage extends StatefulWidget {
  final ProxyAppController controller;
  const RulesPage({super.key, required this.controller});

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  final filter = TextEditingController();
  bool _caseSensitive = false;
  bool _regex = false;
  bool _wildcard = false;
  @override
  void initState() {
    super.initState();
    widget.controller.refreshRuntimeDetails();
  }

  @override
  void dispose() {
    filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final query = filter.text;
        final rules = widget.controller.rules.asMap().entries.where((entry) {
          if (query.isEmpty) return true;
          final value = entry.value.toString();
          if (_regex) {
            try {
              return RegExp(
                query,
                caseSensitive: _caseSensitive,
              ).hasMatch(value);
            } catch (_) {
              return false;
            }
          }
          if (_wildcard) {
            return _globMatches(value, query, caseSensitive: _caseSensitive);
          }
          return _caseSensitive
              ? value.contains(query)
              : value.toLowerCase().contains(query.toLowerCase());
        }).toList();
        final activeHits = widget.controller.connections
            .map((item) => '${item['rule'] ?? ''}|${item['rulePayload'] ?? ''}')
            .toSet();

        if (widget.controller.rules.isEmpty) {
          return RsEmpty(
            icon: Icons.call_split,
            title: widget.controller.isRunning ? '当前配置没有可显示规则' : '启动代理后读取规则',
            subtitle: '当前配置：${widget.controller.activeProfile?.name ?? '尚未配置'}',
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: filter,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: context.rsText('过滤条件'),
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
                    tooltip: context.rsText('区分大小写'),
                    selected: _caseSensitive,
                    onTap: () =>
                        setState(() => _caseSensitive = !_caseSensitive),
                  ),
                  const SizedBox(width: 4),
                  _SyntaxBtn(
                    label: 'ab',
                    tooltip: context.rsText('正则表达式'),
                    selected: _regex,
                    onTap: () => setState(() => _regex = !_regex),
                  ),
                  const SizedBox(width: 4),
                  _SyntaxBtn(
                    label: '*',
                    tooltip: context.rsText('通配符'),
                    selected: _wildcard,
                    onTap: () => setState(() {
                      _wildcard = !_wildcard;
                      if (_wildcard) _regex = false;
                    }),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: context.rsText('刷新'),
                    onPressed: widget.controller.refreshRuntimeDetails,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rules.isEmpty
                  ? const RsEmpty(icon: Icons.call_split, title: '没有匹配的规则')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(10, 3, 10, 10),
                      itemCount: rules.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFF252A35)),
                      itemBuilder: (_, i) {
                        final entry = rules[i];
                        final rule = entry.value;
                        final type = rule['type']?.toString() ?? '';
                        final payload = rule['payload']?.toString() ?? '';
                        final strategy =
                            rule['proxy']?.toString() ??
                            rule['adapter']?.toString() ??
                            'DIRECT';
                        final hit = activeHits.contains('$type|$payload');
                        return Container(
                          color: hit
                              ? const Color(0xFF168BFA).withValues(alpha: .08)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 38,
                                child: RsText(
                                  '${entry.key + 1}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: DesktopColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    payload.isEmpty
                                        ? const RsText(
                                            '（无载荷）',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                        : Text(
                                            payload,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                    const SizedBox(height: 4),
                                    Text(
                                      type,
                                      style: const TextStyle(
                                        color: DesktopColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (hit) ...[
                                const Icon(
                                  Icons.gps_fixed,
                                  size: 14,
                                  color: Color(0xFF2AD364),
                                ),
                                const SizedBox(width: 6),
                              ],
                              _StrategyBadge(text: strategy),
                            ],
                          ),
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

bool _globMatches(String value, String pattern, {required bool caseSensitive}) {
  final escaped = RegExp.escape(pattern)
      .replaceAll(r'\*', '.*')
      .replaceAll(r'\?', '.');
  return RegExp('^$escaped\$', caseSensitive: caseSensitive).hasMatch(value);
}

class _StrategyBadge extends StatelessWidget {
  final String text;
  const _StrategyBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final color = switch (text) {
      'DIRECT' => const Color(0xFF2AD364),
      'REJECT' => Colors.redAccent,
      _ => const Color(0xFF168BFA),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
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
