import 'package:flutter/material.dart';

import '../../../core/ffi/clash_controller.dart' show ProxyGroup;
import '../../../services/proxy_app_controller.dart';
import '../desktop_app.dart' show DesktopColors, DesktopSection;
import 'widgets.dart';

/// mac-1004 / mac-1012 代理组页面。
class ProxyPage extends StatelessWidget {
  final ProxyAppController controller;
  final ValueChanged<DesktopSection>? onNavigate;
  const ProxyPage({super.key, required this.controller, this.onNavigate});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final groups = controller.groups.values
          .where((g) => g.all.isNotEmpty)
          .toList();
      if (groups.isEmpty) {
        return _EmptyProxyView(controller: controller, onNavigate: onNavigate);
      }
      final currentGroup = controller.groups[controller.selectedGroup];
      return Column(
        children: [
          _ProxyToolbar(controller: controller),
          Expanded(
            child: currentGroup == null
                ? RsEmpty(
                    icon: Icons.help_outline,
                    title: '未选择分组',
                    subtitle: '点击上方分组标签切换',
                  )
                : _NodeGrid(group: currentGroup, controller: controller),
          ),
        ],
      );
    },
  );
}

class _EmptyProxyView extends StatelessWidget {
  final ProxyAppController controller;
  final ValueChanged<DesktopSection>? onNavigate;
  const _EmptyProxyView({required this.controller, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final profile = controller.activeProfile;
    final canRefresh =
        profile != null &&
        profile.sourceType == 'url' &&
        (profile.source?.isNotEmpty ?? false);
    final subtitle = profile == null
        ? '尚未导入任何配置'
        : canRefresh
        ? '可前往订阅页刷新「${profile.name}」拉取最新节点'
        : '「${profile.name}」中没有可用的代理节点';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 56,
            color: Color(0xFF168BFA),
          ),
          const SizedBox(height: 14),
          const Text('当前没有可用的代理节点', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: DesktopColors.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (onNavigate != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => onNavigate!(DesktopSection.subscription),
              icon: const Icon(Icons.cloud_download_outlined, size: 16),
              label: const Text('前往订阅页'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF168BFA),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProxyToolbar extends StatelessWidget {
  final ProxyAppController controller;
  const _ProxyToolbar({required this.controller});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
    child: Row(
      children: [
        // 左：分组图标
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in controller.groups.values.where(
                  (g) => g.all.isNotEmpty,
                )) ...[
                  _GroupChip(
                    name: item.name,
                    icon: _iconForGroupType(item.type),
                    selected: item.name == controller.selectedGroup,
                    onTap: () => controller.chooseGroup(item.name),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        const VerticalDivider(width: 16, color: Color(0xFF2A2D38)),
        const SizedBox(width: 4),
        // 右：模式选择 + 链式代理
        for (final mode in const ['规则', '全局', '直连']) ...[
          _ModeChip(
            label: mode,
            selected: switch (mode) {
              '规则' => controller.proxyMode == 'rule',
              '全局' => controller.proxyMode == 'global',
              _ => controller.proxyMode == 'direct',
            },
            onTap: () => controller.changeProxyMode(switch (mode) {
              '规则' => 'rule',
              '全局' => 'global',
              _ => 'direct',
            }),
          ),
          const SizedBox(width: 8),
        ],
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('链式代理'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('当前代理链由配置文件中的 relay 分组管理。'),
                    const SizedBox(height: 12),
                    Text(
                      controller.groups.values
                              .where((group) => group.type == 'relay')
                              .map(
                                (group) =>
                                    '${group.name}：${group.all.join(' → ')}',
                              )
                              .join('\n')
                              .trim()
                              .isEmpty
                          ? '当前配置没有 relay 分组。'
                          : controller.groups.values
                                .where((group) => group.type == 'relay')
                                .map(
                                  (group) =>
                                      '${group.name}：${group.all.join(' → ')}',
                                )
                                .join('\n'),
                    ),
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.account_tree_outlined, size: 16),
          label: const Text('链式代理'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF168BFA),
            side: const BorderSide(color: Color(0xFF168BFA)),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: !controller.engineRunning
              ? null
              : controller.checkingDelays
              ? controller.cancelDelayChecks
              : () =>
                    controller.checkGroupDelays(controller.selectedGroup ?? ''),
          icon: Icon(
            controller.checkingDelays ? Icons.stop : Icons.bolt,
            size: 16,
          ),
          label: Text(controller.checkingDelays ? '取消测速' : '全部测速'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF168BFA),
            side: const BorderSide(color: Color(0xFF168BFA)),
          ),
        ),
      ],
    ),
  );

  IconData _iconForGroupType(String type) => switch (type) {
    'select' => Icons.checklist_rounded,
    'url-test' => Icons.speed_rounded,
    'fallback' => Icons.fast_forward_rounded,
    'load-balance' => Icons.balance_rounded,
    'relay' => Icons.timeline_rounded,
    _ => Icons.lan_rounded,
  };
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : DesktopColors.muted,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _GroupChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _GroupChip({
    required this.name,
    required this.icon,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : DesktopColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFFCDCED4),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NodeGrid extends StatelessWidget {
  final ProxyGroup group;
  final ProxyAppController controller;
  const _NodeGrid({required this.group, required this.controller});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 480,
        mainAxisExtent: 60,
        crossAxisSpacing: 12,
        mainAxisSpacing: 8,
      ),
      itemCount: group.all.length,
      itemBuilder: (_, i) {
        final node = group.all[i];
        final selected = node == group.now;
        final delay = controller.delays[node];
        final type = group.nodeTypes[node] ?? 'Proxy';
        final testable = _isTestableProxyNode(node, type);
        return _NodeCard(
          name: node,
          type: type,
          udp: group.nodeUdp[node] == true,
          selected: selected,
          delay: testable ? delay : null,
          checking: testable && controller.isCheckingNodeDelay(node),
          testable: testable,
          onTap: () => controller.chooseNode(node),
          onDelay: testable ? () => controller.selectAndCheckNode(node) : null,
        );
      },
    );
  }
}

class _NodeCard extends StatefulWidget {
  final String name;
  final String type;
  final bool selected;
  final bool udp;
  final int? delay;
  final bool checking;
  final bool testable;
  final VoidCallback onTap;
  final VoidCallback? onDelay;
  const _NodeCard({
    required this.name,
    required this.type,
    required this.selected,
    required this.udp,
    required this.delay,
    required this.checking,
    required this.testable,
    required this.onTap,
    required this.onDelay,
  });

  @override
  State<_NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<_NodeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final flag = _flagFromName(widget.name);
    return MouseRegion(
      onEnter: widget.testable ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.testable ? (_) => setState(() => _hovered = false) : null,
      child: Material(
        color: widget.selected
            ? const Color(0xFF294F83)
            : const Color(0xFF232530),
        borderRadius: BorderRadius.circular(3),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: widget.selected
                  ? const Border(
                      left: BorderSide(color: Color(0xFF168BFA), width: 3),
                    )
                  : null,
            ),
            child: Row(
              children: [
                if (flag.isNotEmpty)
                  Text(flag, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          RsChip(
                            text: widget.type,
                            color: const Color(0xFF6E7280),
                          ),
                          RsChip(
                            text: widget.udp ? 'UDP' : 'TCP',
                            color: widget.udp
                                ? const Color(0xFF2AD364)
                                : const Color(0xFF6E7280),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onDelay,
                  behavior: HitTestBehavior.opaque,
                  child: _DelayTag(
                    delay: widget.delay,
                    checking: widget.checking,
                    showCheck:
                        widget.testable && _hovered && widget.delay == null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DelayTag extends StatelessWidget {
  final int? delay;
  final bool checking;
  final bool showCheck;
  const _DelayTag({
    this.delay,
    required this.checking,
    required this.showCheck,
  });
  @override
  Widget build(BuildContext context) {
    final color = checking || delay == null
        ? const Color(0xFF168BFA)
        : delay! < 0
        ? Colors.redAccent
        : delay! < 200
        ? const Color(0xFF2AD364)
        : delay! < 500
        ? const Color(0xFFFFA20F)
        : Colors.redAccent;
    final text = checking
        ? '···'
        : delay == null
        ? (showCheck ? 'Check' : '')
        : delay! < 0
        ? '失败'
        : '$delay';
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 52, minHeight: 34),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

bool _isTestableProxyNode(String name, String type) {
  final normalizedName = name.trim().toLowerCase();
  final normalizedType = type.trim().toLowerCase();
  if (normalizedName == 'direct' || normalizedName == 'reject') return false;
  if (normalizedType == 'direct' || normalizedType == 'reject') return false;
  const metadataMarkers = <String>[
    '剩余流量',
    '距离下次重置',
    '套餐到期',
    '流量重置',
    '订阅到期',
    '到期时间',
  ];
  return !metadataMarkers.any(normalizedName.contains);
}

/// 简易国旗 emoji 识别：根据节点名前几个字符。
String _flagFromName(String name) {
  if (name.startsWith('香港') || name.contains('HK')) return '🇭🇰';
  if (name.startsWith('澳门') || name.contains('MO')) return '🇲🇴';
  if (name.startsWith('台湾') || name.contains('TW')) return '🇹🇼';
  if (name.startsWith('日本') || name.contains('JP')) return '🇯🇵';
  if (name.startsWith('美国') || name.contains('US')) return '🇺🇸';
  if (name.startsWith('新加坡') || name.contains('SG')) return '🇸🇬';
  if (name.startsWith('英国') || name.contains('UK')) return '🇬🇧';
  if (name.startsWith('德国') || name.contains('DE')) return '🇩🇪';
  if (name.startsWith('法国') || name.contains('FR')) return '🇫🇷';
  if (name.startsWith('韩国') || name.contains('KR')) return '🇰🇷';
  if (name.startsWith('中国') || name.contains('CN')) return '🇨🇳';
  if (name.startsWith('🇨🇳') ||
      name.contains('🇭🇰') ||
      name.contains('🇯🇵')) {
    return name.substring(0, 2);
  }
  return '';
}
