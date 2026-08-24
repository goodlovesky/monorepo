import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../services/proxy_app_controller.dart';
import '../../widgets/clash_widgets.dart';

class ProxyPage extends StatefulWidget {
  final ProxyAppController controller;
  const ProxyPage({super.key, required this.controller});

  @override
  State<ProxyPage> createState() => _ProxyPageState();
}

class _ProxyPageState extends State<ProxyPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.refreshGroups();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final groups = widget.controller.groups.entries
          .where((entry) => entry.value.all.isNotEmpty)
          .toList();
      final selected = widget.controller.selectedGroup;
      final group = selected == null
          ? null
          : widget.controller.groups[selected];
      return Scaffold(
        appBar: ScreenshotAppBar(
          title: '代理',
          actions: [
            IconButton(
              onPressed: widget.controller.checkingDelays
                  ? null
                  : widget.controller.checkAllDelays,
              icon: widget.controller.checkingDelays
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt, size: 35),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 34),
              color: AppColors.cardElevated,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'refresh', child: Text('刷新代理组')),
                PopupMenuItem(value: 'delay', child: Text('延迟测试')),
              ],
              onSelected: (value) {
                if (value == 'refresh') widget.controller.refreshGroups();
                if (value == 'delay') widget.controller.checkAllDelays();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 46,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final entry = groups[index];
                  final active = entry.key == selected;
                  return InkWell(
                    onTap: () => widget.controller.chooseGroup(entry.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 2.5,
                            color: active ? AppColors.blue : Colors.transparent,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${_groupIcon(entry.key)} ${entry.key}',
                        style: TextStyle(
                          fontSize: 13.5,
                          letterSpacing: 1.2,
                          color: active ? AppColors.blue : AppColors.muted,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: group == null
                  ? const Center(child: Text('没有可用代理组'))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(3, 5, 3, 90),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            mainAxisExtent: 57,
                          ),
                      itemCount: group.all.length,
                      itemBuilder: (_, index) {
                        final name = group.all[index];
                        return _NodeCard(
                          name: name,
                          protocol: group.nodeTypes[name] ?? 'Proxy',
                          selected: group.now == name,
                          delay: widget.controller.delays[name],
                          onTap: () => widget.controller.chooseNode(name),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          onPressed: widget.controller.checkAllDelays,
          child: const Icon(Icons.bolt, size: 30),
        ),
      );
    },
  );

  String _groupIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('game')) return '🎮';
    if (lower.contains('video')) return '📺';
    if (lower.contains('fallback')) return '♻️';
    return '🐱';
  }
}

class _NodeCard extends StatelessWidget {
  final String name;
  final String protocol;
  final bool selected;
  final int? delay;
  final VoidCallback onTap;

  const _NodeCard({
    required this.name,
    required this.protocol,
    required this.selected,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.blue : AppColors.card,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 7, 11, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, letterSpacing: .5),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _protocolLabel(protocol),
                    style: const TextStyle(fontSize: 11.5, letterSpacing: .4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              delay == null ? '' : (delay == 0 ? '超时' : '$delay'),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );

  String _protocolLabel(String type) {
    final lower = type.toLowerCase();
    if (lower == 'selector') return 'Selector';
    if (lower == 'urltest') return 'URLTest';
    if (lower == 'fallback') return 'Fallback';
    if (lower == 'vless') return 'VLESS';
    if (lower == 'vmess') return 'Vmess';
    if (lower == 'ss') return 'Shadowsocks';
    if (lower == 'direct') return 'Direct';
    return type;
  }
}
