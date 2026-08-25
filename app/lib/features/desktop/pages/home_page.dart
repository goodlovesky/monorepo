import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../platform/desktop/desktop_network_service.dart';
import '../../../services/home_layout.dart';
import '../../../services/proxy_app_controller.dart';
import '../../../core/ffi/clash_controller.dart' show TrafficStats;
import '../desktop_app.dart' show DesktopSection;
import 'widgets.dart';
import '../../../l10n/rs_text.dart';

bool _usesLongLocalizedCopy(BuildContext context) {
  final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
  return l10n != null && l10n.localeName != 'zh' && l10n.localeName != 'zh_TW';
}

/// mac-1001 / 1002 / 1003 合一的大屏仪表盘。
class HomePage extends StatelessWidget {
  final ProxyAppController controller;
  final DesktopNetworkService network;
  final ValueChanged<DesktopSection> onNavigate;
  final VoidCallback onSettingsTap;
  final VoidCallback onAdvancedSettingsTap;
  final ValueChanged<DesktopNetworkMode> onNetworkModeChange;

  const HomePage({
    super.key,
    required this.controller,
    required this.network,
    required this.onNavigate,
    required this.onSettingsTap,
    required this.onAdvancedSettingsTap,
    required this.onNetworkModeChange,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, network as Listenable]),
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // 1000px 窗口,侧栏 220,内容 ~780 - 用 600 阈值就触发 2 列
              final cards = _buildCards(
                context,
                wide: width >= 600,
                compact: width < 480,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cards,
              );
            },
          ),
        );
      },
    );
  }

  /// 渲染所有卡片（按用户配置的顺序 + 隐藏项）。wide=true 时大多数卡片 2 列。
  List<Widget> _buildCards(
    BuildContext context, {
    required bool wide,
    required bool compact,
  }) {
    final layout = controller.homeLayout;
    final order = layout.resolvedOrder();
    final visible = order.where((id) => !layout.isHidden(id)).toList();

    // 非中文 locale（en/ja/ko/fr）的文案通常更长（单词 / 假名 / 谚文字符宽度不同），
    // 给每行 +20px buffer，避免 RenderFlex overflow。
    // 中文（zh / zh_TW）保持原高度，不影响 golden image。
    const longCopyBuffer = 20.0;
    final longCopy = _usesLongLocalizedCopy(context);
    double h(double base) => longCopy ? base + longCopyBuffer : base;

    // 顶部 row1：subscription / currentNode / network / proxyMode，2x2
    // 中部：traffic 全宽 + metrics 2x3
    // 底部：siteTest(8) + ipInfo(4)
    // 最底：clashInfo(6) + systemInfo(6)
    final out = <Widget>[];

    Widget build(String id) {
      switch (id) {
        case 'subscription':
          return _SubscriptionCard(
            controller: controller,
            onOpenSubscription: () => onNavigate(DesktopSection.subscription),
          );
        case 'currentNode':
          return _CurrentNodeCard(
            controller: controller,
            onOpen: () => onNavigate(DesktopSection.proxy),
          );
        case 'network':
          return _NetworkCard(
            controller: controller,
            network: network,
            onChangeMode: (m) => onNetworkModeChange(m),
          );
        case 'proxyMode':
          return _ProxyModeCard(controller: controller);
        case 'traffic':
          return _TrafficChartCard(controller: controller);
        case 'siteTest':
          return _SiteTestCard(
            controller: controller,
            onOpen: () => onNavigate(DesktopSection.test),
          );
        case 'ipInfo':
          return _IpInfoCard(controller: controller);
        case 'clashInfo':
          return _ClashInfoCard(
            controller: controller,
            onSettingsTap: onAdvancedSettingsTap,
          );
        case 'systemInfo':
          return _SystemInfoCard(
            controller: controller,
            onSettingsTap: onSettingsTap,
          );
        default:
          return const SizedBox.shrink();
      }
    }

    if (wide) {
      // Row 1: subscription(6) | currentNode(6) — 需要较高容纳 dropdown
      if (visible.contains('subscription') && visible.contains('currentNode')) {
        out.add(
          _row2(build('subscription'), build('currentNode'), height: h(272)),
        );
        out.add(_gap());
      } else if (visible.contains('subscription')) {
        out.add(build('subscription'));
        out.add(_gap());
      } else if (visible.contains('currentNode')) {
        out.add(build('currentNode'));
        out.add(_gap());
      }
      if (visible.contains('network') && visible.contains('proxyMode')) {
        out.add(_row2(build('network'), build('proxyMode'), height: h(233)));
        out.add(_gap());
      } else if (visible.contains('network')) {
        out.add(build('network'));
        out.add(_gap());
      } else if (visible.contains('proxyMode')) {
        out.add(build('proxyMode'));
        out.add(_gap());
      }
      // Row 2: traffic (full width) + metrics
      if (visible.contains('traffic')) {
        out.add(build('traffic'));
        out.add(_gap());
      }
      // Row 3: siteTest (2/3) + ipInfo (1/3) — 站点测试单行 tile 较高
      if (visible.contains('siteTest') && visible.contains('ipInfo')) {
        out.add(_row2(build('siteTest'), build('ipInfo'), height: h(360)));
        out.add(_gap());
      } else if (visible.contains('siteTest')) {
        out.add(build('siteTest'));
        out.add(_gap());
      } else if (visible.contains('ipInfo')) {
        out.add(build('ipInfo'));
        out.add(_gap());
      }
      // Row 4: clashInfo | systemInfo
      if (visible.contains('clashInfo') && visible.contains('systemInfo')) {
        out.add(_row2(build('clashInfo'), build('systemInfo'), height: h(291)));
      } else if (visible.contains('clashInfo')) {
        out.add(build('clashInfo'));
      } else if (visible.contains('systemInfo')) {
        out.add(build('systemInfo'));
      }
    } else {
      // 窄屏：单列堆叠
      for (final id in visible) {
        final c = build(id);
        if (c is SizedBox && c.width == double.infinity) continue;
        out.add(c);
        out.add(_gap());
      }
      if (out.isNotEmpty && out.last is SizedBox) out.removeLast();
    }

    out.add(const SizedBox(height: 8));
    out.add(_LayoutEditorTile(onTap: () => _openLayoutEditor(context)));
    return out;
  }

  void _openLayoutEditor(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _HomeLayoutEditor(controller: controller),
    );
  }

  Widget _row2(Widget left, Widget right, {double height = 220}) => SizedBox(
    height: height,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    ),
  );

  Widget _gap() => const SizedBox(height: 12);
}

// =============================================================================
// 订阅卡
// =============================================================================

class _SubscriptionCard extends StatelessWidget {
  final ProxyAppController controller;
  final VoidCallback onOpenSubscription;
  const _SubscriptionCard({
    required this.controller,
    required this.onOpenSubscription,
  });

  @override
  Widget build(BuildContext context) {
    final profile = controller.activeProfile;
    final used = profile?.usedTrafficBytes ?? 0;
    final total = profile?.totalTrafficBytes ?? 0;
    final ratio = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    return RsCard(
      title: profile?.name ?? '尚未导入订阅',
      translateTitle: profile == null,
      icon: Icons.cloud_upload_outlined,
      accent: const Color(0xFF168BFA),
      titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      titleSuffix: profile == null
          ? null
          : const Icon(Icons.open_in_new, size: 13, color: Color(0xFF9B9DA9)),
      trailing: _SubscriptionBadge(onTap: onOpenSubscription),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SourceInfoLine(
            icon: Icons.dns_outlined,
            source: profile?.source ?? '从订阅页面添加 URL 或配置文件',
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.history,
            text: '更新时间：${_dateTime(profile?.updatedAt)}',
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.speed,
            text:
                '已使用 / 总量：${_subscriptionBytes(used)} / ${total > 0 ? _subscriptionBytes(total) : '未提供'}',
          ),
          if (profile?.expiresAt != null) ...[
            const SizedBox(height: 10),
            _InfoLine(
              icon: Icons.calendar_today_outlined,
              text: '到期时间：${_dateOnly(profile?.expiresAt)}',
            ),
          ],
          const SizedBox(height: 14),
          RsText(
            '${(ratio * 100).round()}%',
            style: const TextStyle(fontSize: 13, color: Color(0xFFCDCED4)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF253A59),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF168BFA),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _SubscriptionBadge({required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF168BFA)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RsText(
              '订阅',
              style: TextStyle(
                color: Color(0xFF168BFA),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.credit_card, color: Color(0xFF168BFA), size: 14),
          ],
        ),
      ),
    ),
  );
}

// =============================================================================
// 当前节点卡
// =============================================================================

class _CurrentNodeCard extends StatefulWidget {
  final ProxyAppController controller;
  final VoidCallback onOpen;
  const _CurrentNodeCard({required this.controller, required this.onOpen});

  @override
  State<_CurrentNodeCard> createState() => _CurrentNodeCardState();
}

class _CurrentNodeCardState extends State<_CurrentNodeCard> {
  String? _requestedDelayNode;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final selectedName = controller.selectedGroup;
    final candidates = controller.groups.entries
        .where((entry) => entry.value.all.isNotEmpty)
        .toList();
    final fallbackEntry = candidates.isEmpty
        ? null
        : candidates.firstWhere(
            (entry) => entry.key.toUpperCase() == 'PROXY',
            orElse: () => candidates.first,
          );
    final group = selectedName == null
        ? fallbackEntry?.value
        : controller.groups[selectedName] ?? fallbackEntry?.value;
    final node = (group?.now.isNotEmpty ?? false) ? group!.now : null;
    final delay = node == null
        ? null
        : controller.delays[node] ?? group?.delays[node];
    final isManual = controller.proxyMode == 'global';
    final type = node == null ? 'Proxy' : group?.nodeTypes[node] ?? 'Proxy';
    final udp = node != null && group?.nodeUdp[node] == true;

    if (node != null &&
        delay == null &&
        controller.engineRunning &&
        _requestedDelayNode != node) {
      _requestedDelayNode = node;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.checkNodeDelay(node);
      });
    }
    return RsCard(
      title: '当前节点',
      icon: Icons.play_arrow_rounded,
      iconSize: 30,
      iconQuarterTurns: 1,
      accent: const Color(0xFF2AD364),
      trailing: _CurrentNodeTrailing(onTap: widget.onOpen),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 节点行
          SizedBox(
            height: 66,
            child: Material(
              color: const Color(0xFF272F40),
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: widget.onOpen,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF2B4D81)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: node == null
                                      ? const RsText(
                                          '尚未选择节点',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : Text(
                                          node,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  type,
                                  style: const TextStyle(
                                    color: Color(0xFFF7F7FA),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _MiniTag(
                                  label: isManual ? '全局模式' : '规则模式',
                                  color: const Color(0xFF168BFA),
                                ),
                                if (udp) ...[
                                  const SizedBox(width: 5),
                                  const _OutlineTag(label: 'UDP'),
                                ],
                                if (type.toLowerCase() == 'vless') ...[
                                  const SizedBox(width: 5),
                                  const _OutlineTag(label: 'XUDP'),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (delay != null && delay > 0) ...[
                        const SizedBox(width: 8),
                        _DelayChip(ms: delay, color: _delayColor(delay)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 代理组 dropdown
          _SelectorField(
            label: '代理组',
            value: null,
            items: controller.groups.keys.toList(),
            onChanged: (v) {
              if (v != null) controller.selectGroup(v);
            },
          ),
          const SizedBox(height: 10),
          // 节点 dropdown
          _NodeSelectorField(
            label: '节点',
            value: node,
            items: (group?.all ?? const []).toList(),
            delays: controller.delays,
            onChanged: (v) {
              if (v != null) controller.chooseNode(v);
            },
          ),
        ],
      ),
    );
  }
}

class _CurrentNodeTrailing extends StatelessWidget {
  final VoidCallback onTap;
  const _CurrentNodeTrailing({required this.onTap});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: context.rsText('打开代理页'),
        onPressed: onTap,
        icon: const Icon(Icons.speed_rounded, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        tooltip: context.rsText('选择节点'),
        onPressed: onTap,
        icon: const Icon(Icons.sort_rounded, size: 18),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        visualDensity: VisualDensity.compact,
      ),
      const SizedBox(width: 4),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF168BFA)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RsText(
                    '代理',
                    style: TextStyle(
                      color: Color(0xFF168BFA),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, color: Color(0xFF168BFA), size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
    ),
    child: RsText(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _OutlineTag extends StatelessWidget {
  final String label;
  const _OutlineTag({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF686B76)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: RsText(
      label,
      style: const TextStyle(color: Color(0xFFCDCED4), fontSize: 10),
    ),
  );
}

class _DelayChip extends StatelessWidget {
  final int ms;
  final Color color;
  const _DelayChip({required this.ms, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: RsText(
      '$ms',
      style: TextStyle(
        color: color.computeLuminance() > .45 ? Colors.black : Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SelectorField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _SelectorField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF272A36),
              border: Border.all(color: const Color(0xFF686B76)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: const Color(0xFF272A36),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF9B9DA9),
                  size: 18,
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: onChanged,
                items: [
                  for (final v in items)
                    DropdownMenuItem(
                      value: v,
                      child: Text(v, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          top: -4,
          child: Container(
            color: const Color(0xFF272A36),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RsText(
              label,
              style: const TextStyle(color: Color(0xFF9B9DA9), fontSize: 11),
            ),
          ),
        ),
      ],
    ),
  );
}

class _NodeSelectorField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final Map<String, int> delays;
  final ValueChanged<String?> onChanged;
  const _NodeSelectorField({
    required this.label,
    required this.value,
    required this.items,
    required this.delays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF272A36),
              border: Border.all(
                color: value == null
                    ? const Color(0xFF686B76)
                    : const Color(0xFF168BFA),
                width: value == null ? 1 : 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: const Color(0xFF272A36),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFFF7F7FA),
                  size: 18,
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: onChanged,
                selectedItemBuilder: (context) => [
                  for (final node in items)
                    _NodeSelectorValue(name: node, delay: delays[node]),
                ],
                items: [
                  for (final node in items)
                    DropdownMenuItem(
                      value: node,
                      child: _NodeSelectorValue(
                        name: node,
                        delay: delays[node],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          top: -4,
          child: Container(
            color: const Color(0xFF272A36),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RsText(
              label,
              style: TextStyle(
                color: value == null
                    ? const Color(0xFF9B9DA9)
                    : const Color(0xFF168BFA),
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _NodeSelectorValue extends StatelessWidget {
  final String name;
  final int? delay;
  const _NodeSelectorValue({required this.name, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (delay != null && delay! > 0) ...[
          const SizedBox(width: 8),
          _DelayChip(ms: delay!, color: _delayColor(delay!)),
        ],
      ],
    );
  }
}

// =============================================================================
// 网络设置卡
// =============================================================================

class _NetworkCard extends StatefulWidget {
  final ProxyAppController controller;
  final DesktopNetworkService network;
  final ValueChanged<DesktopNetworkMode> onChangeMode;
  const _NetworkCard({
    required this.controller,
    required this.network,
    required this.onChangeMode,
  });

  @override
  State<_NetworkCard> createState() => _NetworkCardState();
}

enum _NetworkPanel { systemProxy, tun }

class _NetworkCardState extends State<_NetworkCard> {
  late _NetworkPanel _selectedPanel;

  @override
  void initState() {
    super.initState();
    _selectedPanel = widget.network.mode == DesktopNetworkMode.tun
        ? _NetworkPanel.tun
        : _NetworkPanel.systemProxy;
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.network.mode;
    final sysActive = mode == DesktopNetworkMode.systemProxy;
    final tunActive = mode == DesktopNetworkMode.tun;
    final showingSystem = _selectedPanel == _NetworkPanel.systemProxy;
    // 永久 setuid helper 已移除；只检查签名 App 内固定的 mihomo 运行时。
    // 真正启动时由系统按次显示管理员授权。
    final helperReady = _isTunRuntimeReady();
    return RsCard(
      title: '网络设置',
      icon: Icons.dns_outlined,
      accent: const Color(0xFF168BFA),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 两个页签只切换设置面板；真正启停由面板底部开关负责。
          Row(
            children: [
              Expanded(
                child: _NetworkTab(
                  icon: Icons.laptop_chromebook_outlined,
                  label: '系统代理',
                  selected: showingSystem,
                  running: sysActive,
                  onTap: () => setState(
                    () => _selectedPanel = _NetworkPanel.systemProxy,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _NetworkTab(
                  icon: Icons.troubleshoot_outlined,
                  label: '虚拟网卡模式',
                  selected: !showingSystem,
                  running: tunActive,
                  onTap: () =>
                      setState(() => _selectedPanel = _NetworkPanel.tun),
                ),
              ),
            ],
          ),
          _NetworkSelectionConnector(showingSystem: showingSystem),
          // 状态 banner
          _NetworkStatusBanner(
            panel: _selectedPanel,
            mode: mode,
            lastError: widget.network.lastError,
            helperReady: helperReady,
          ),
          const SizedBox(height: 8),
          if (showingSystem)
            _SystemProxyToggleRow(
              active: sysActive,
              onChanged: (enabled) => widget.onChangeMode(
                enabled
                    ? DesktopNetworkMode.systemProxy
                    : DesktopNetworkMode.off,
              ),
            )
          else
            _TunToggleRow(
              active: tunActive,
              helperReady: helperReady,
              onChanged: (enabled) => widget.onChangeMode(
                enabled ? DesktopNetworkMode.tun : DesktopNetworkMode.off,
              ),
              onInstall: () => widget.onChangeMode(DesktopNetworkMode.tun),
            ),
        ],
      ),
    );
  }

  bool _isTunRuntimeReady() {
    if (!Platform.isMacOS) return true;
    final runtime = File(
      '${File(Platform.resolvedExecutable).parent.parent.path}/Resources/mihomo',
    );
    return runtime.existsSync();
  }
}

class _NetworkSelectionConnector extends StatelessWidget {
  final bool showingSystem;
  const _NetworkSelectionConnector({required this.showingSystem});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 8,
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: showingSystem
                ? Container(width: 2, color: const Color(0xFF168BFA))
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: showingSystem
                ? null
                : Container(width: 2, color: const Color(0xFF168BFA)),
          ),
        ),
      ],
    ),
  );
}

class _SystemProxyToggleRow extends StatelessWidget {
  final bool active;
  final ValueChanged<bool> onChanged;
  const _SystemProxyToggleRow({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF2AD364).withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(
          active ? Icons.play_circle_fill : Icons.play_circle_outline,
          color: const Color(0xFF2AD364),
          size: 22,
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: RsText(
            '系统代理',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        const Icon(Icons.settings, color: Color(0xFFCDCED4), size: 18),
        const SizedBox(width: 10),
        Transform.scale(
          scale: .82,
          child: Switch(value: active, onChanged: onChanged),
        ),
      ],
    ),
  );
}

class _TunToggleRow extends StatelessWidget {
  final bool active;
  final bool helperReady;
  final ValueChanged<bool> onChanged;
  final VoidCallback onInstall;
  const _TunToggleRow({
    required this.active,
    required this.helperReady,
    required this.onChanged,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.only(left: 12, right: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF252936),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(
          active ? Icons.pause_circle_filled : Icons.pause_circle_outline,
          color: active ? const Color(0xFF2AD364) : const Color(0xFF777B88),
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RsText(
            '虚拟网卡模式',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: helperReady
                  ? const Color(0xFFCDCED4)
                  : const Color(0xFF9699A6),
            ),
          ),
        ),
        const Icon(Icons.settings, color: Color(0xFF9699A6), size: 18),
        const SizedBox(width: 10),
        if (!helperReady) ...[
          const Icon(Icons.warning_rounded, color: Color(0xFFB17A38), size: 18),
          const SizedBox(width: 6),
          IconButton(
            tooltip: context.rsText('安装服务'),
            onPressed: onInstall,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.build_rounded,
              color: Color(0xFF2D67AA),
              size: 20,
            ),
          ),
        ],
        Transform.scale(
          scale: .82,
          child: Switch(
            value: active,
            onChanged: helperReady ? onChanged : null,
          ),
        ),
      ],
    ),
  );
}

class _NetworkStatusBanner extends StatelessWidget {
  final _NetworkPanel panel;
  final DesktopNetworkMode mode;
  final String? lastError;
  final bool helperReady;
  const _NetworkStatusBanner({
    required this.panel,
    required this.mode,
    required this.lastError,
    required this.helperReady,
  });

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    final IconData icon;
    if (panel == _NetworkPanel.systemProxy) {
      if (mode == DesktopNetworkMode.systemProxy) {
        text = context.rsText('系统代理已启用，您的应用将通过代理访问网络');
        color = const Color(0xFF168BFA);
        icon = Icons.check_circle_outline;
      } else if (lastError != null) {
        // lastError 已通过 AppLog.pick 本地化（zh-CN 显示中文，其他 locale 英文）。
        text = lastError!;
        color = const Color(0xFFFFA20F);
        icon = Icons.error_outline;
      } else {
        text = context.rsText('系统代理未启用，请通过下方开关启用');
        color = const Color(0xFF168BFA);
        icon = Icons.help_outline;
      }
    } else if (!helperReady) {
      text = context.rsText('TUN 模式需要服务模式，请先安装服务');
      color = const Color(0xFF168BFA);
      icon = Icons.help_outline;
    } else if (mode == DesktopNetworkMode.tun) {
      text = context.rsText('虚拟网卡已启用，所有流量由 TUN 接口接管');
      color = const Color(0xFF168BFA);
      icon = Icons.check_circle_outline;
    } else if (lastError != null) {
      text = lastError!;
      color = const Color(0xFFFFA20F);
      icon = Icons.error_outline;
    } else {
      text = context.rsText('虚拟网卡未启用，开启后将接管所有流量');
      color = const Color(0xFF168BFA);
      icon = Icons.help_outline;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        border: Border.all(color: color.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: RsText(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color == const Color(0xFFFFA20F)
                    ? color
                    : const Color(0xFF9699A6),
                fontSize: 12,
              ),
            ),
          ),
          Icon(icon, size: 14, color: color.withValues(alpha: .6)),
        ],
      ),
    );
  }
}

class _NetworkTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool running;
  final VoidCallback onTap;
  const _NetworkTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.running,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF168BFA) : const Color(0xFF2D2E38),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : const Color(0xFFCDCED4),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: RsText(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFCDCED4),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (running) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : const Color(0xFF2AD364),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// =============================================================================
// 代理模式卡
// =============================================================================

class _ProxyModeCard extends StatefulWidget {
  final ProxyAppController controller;
  const _ProxyModeCard({required this.controller});

  @override
  State<_ProxyModeCard> createState() => _ProxyModeCardState();
}

class _ProxyModeCardState extends State<_ProxyModeCard> {
  @override
  Widget build(BuildContext context) {
    final mode = widget.controller.proxyMode;
    return RsCard(
      title: '代理模式',
      icon: Icons.router_outlined,
      accent: const Color(0xFF168BFA),
      contentPadding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _ModeBtn(
                    icon: Icons.multiple_stop_rounded,
                    label: '规则',
                    active: mode == 'rule',
                    onTap: () => widget.controller.changeProxyMode('rule'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeBtn(
                    icon: Icons.language_rounded,
                    label: '全局',
                    active: mode == 'global',
                    onTap: () => widget.controller.changeProxyMode('global'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeBtn(
                    icon: Icons.directions_rounded,
                    label: '直连',
                    active: mode == 'direct',
                    onTap: () => widget.controller.changeProxyMode('direct'),
                  ),
                ),
              ],
            ),
          ),
          _ModeSelectionConnector(mode: mode),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2E38),
              border: Border.all(color: const Color(0xFF168BFA)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: RsText(
              _modeHint(mode),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9699A6), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _modeHint(String mode) => switch (mode) {
    'global' => '所有流量均通过代理服务器，适用于需要全局科学上网的场景',
    'direct' => '所有流量直连，不经过任何代理（仅在能直连时使用）',
    _ => '根据规则自动分流，命中规则的流量走代理，其余直连',
  };
}

class _ModeSelectionConnector extends StatelessWidget {
  final String mode;
  const _ModeSelectionConnector({required this.mode});

  @override
  Widget build(BuildContext context) {
    final selected = switch (mode) {
      'global' => 1,
      'direct' => 2,
      _ => 0,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            for (var index = 0; index < 3; index++) ...[
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: index == selected
                      ? Container(width: 2, color: const Color(0xFF168BFA))
                      : null,
                ),
              ),
              if (index < 2) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: active ? const Color(0xFF168BFA) : const Color(0xFF2D2E38),
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            RsText(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// =============================================================================
// 流量统计卡（10 分钟双线图）
// =============================================================================

class _TrafficChartCard extends StatelessWidget {
  final ProxyAppController controller;
  const _TrafficChartCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final all = controller.trafficHistory;
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    final samples = all.where((s) => s.time.isAfter(cutoff)).toList();
    return RsCard(
      title: '流量统计',
      icon: Icons.speed,
      accent: const Color(0xFFFFA20F),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 折线图区：略深底色圆角包裹（10分钟chip + chart + Points行）
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3D404C),
              border: Border.all(color: const Color(0xFF171820)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RangeChip(
                      label: '10 分钟',
                      active: true,
                      onTap: controller.refreshRuntimeDetails,
                    ),
                    const Spacer(),
                    const RsText(
                      '上传',
                      style: TextStyle(color: Color(0xFFFFA20F), fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    const RsText(
                      '下载',
                      style: TextStyle(color: Color(0xFF168BFA), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 80,
                  child: CustomPaint(
                    painter: _TrafficChartPainter(samples: samples),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RsText(
                      'Points: ${samples.length}  |  Compressed: ${(samples.length / 4).round()}  |  FPS: 15',
                      style: const TextStyle(
                        color: Color(0xFF6F7280),
                        fontSize: 10,
                      ),
                    ),
                    RsText(
                      'Smooth',
                      style: const TextStyle(
                        color: Color(0xFF6F7280),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _MetricsGridInline(controller: controller),
        ],
      ),
    );
  }
}

class _MetricsGridInline extends StatelessWidget {
  final ProxyAppController controller;
  const _MetricsGridInline({required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _MetricCard(
        icon: Icons.arrow_upward,
        iconColor: const Color(0xFFFFA20F),
        label: '上传速度',
        value: _formatSpeed(controller.uploadSpeed),
        unit: 'B/s',
      ),
      _MetricCard(
        icon: Icons.arrow_downward,
        iconColor: const Color(0xFF168BFA),
        label: '下载速度',
        value: _formatSpeed(controller.downloadSpeed),
        unit: 'B/s',
      ),
      _MetricCard(
        icon: Icons.link,
        iconColor: const Color(0xFF2AD364),
        label: '活跃连接',
        value: '${controller.connections.length}',
        unit: '',
      ),
      _MetricCard(
        icon: Icons.cloud_upload,
        iconColor: const Color(0xFFFFA20F),
        label: '上传量',
        value: _formatBytesShort(controller.totalUp),
        unit: 'MB',
      ),
      _MetricCard(
        icon: Icons.cloud_download,
        iconColor: const Color(0xFF168BFA),
        label: '下载量',
        value: _formatBytesShort(controller.totalDown),
        unit: 'MB',
      ),
      _MetricCard(
        icon: Icons.memory,
        iconColor: const Color(0xFFFF3B5B),
        label: '内核占用',
        value: controller.memoryMb > 0
            ? controller.memoryMb.toStringAsFixed(1)
            : '—',
        unit: 'MB',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const cols = 3;
        const gap = 8.0;
        final rows = <Widget>[];
        for (var i = 0; i < items.length; i += cols) {
          final row = <Widget>[];
          for (var j = 0; j < cols; j++) {
            if (i + j < items.length) {
              row.add(Expanded(child: items[i + j]));
              if (j < cols - 1) row.add(const SizedBox(width: gap));
            } else {
              row.add(const Spacer());
            }
          }
          rows.add(Row(children: row));
          if (i + cols < items.length) rows.add(const SizedBox(height: gap));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RangeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: active ? const Color(0xFF414451) : Colors.transparent,
    borderRadius: BorderRadius.circular(4),
    child: InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: RsText(
          label,
          style: TextStyle(
            color: const Color(0xFFCDCED4),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _TrafficChartPainter extends CustomPainter {
  final List<TrafficStats> samples;
  _TrafficChartPainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    // 网格 + 左侧刻度
    final gridPaint = Paint()
      ..color = const Color(0xFF2A2D38)
      ..strokeWidth = 1;
    final axisTextStyle = const TextStyle(
      color: Color(0xFF6F7280),
      fontSize: 10,
    );

    int maxVal = 0;
    for (final s in samples) {
      if (s.up > maxVal) maxVal = s.up;
      if (s.down > maxVal) maxVal = s.down;
    }
    if (maxVal == 0) {
      // 0 也要画出 0 刻度
      maxVal = 1;
    }
    // 圆整到 2 的幂，方便刻度对齐
    int pow = 1;
    while (pow < maxVal) {
      pow <<= 1;
    }
    final niceMax = pow.clamp(16 * 1024, 1 << 30);

    // 横向 3 条网格
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      final v = niceMax * (1 - i / 3);
      _drawText(
        canvas,
        _bytesShort(v.toInt()),
        Offset(2, y - 4),
        axisTextStyle,
      );
    }

    if (samples.length < 2) {
      _drawText(
        canvas,
        samples.isEmpty ? '等待数据…' : '数据采集中…',
        Offset(size.width / 2 - 30, size.height / 2),
        const TextStyle(color: Color(0xFF6F7280), fontSize: 12),
      );
      return;
    }

    // 时间 X 轴：从最早到最晚，10 分钟窗口
    final earliest = samples.first.time;
    final latest = samples.last.time;

    Offset pos(TrafficStats s, double v) {
      final dt = s.time.difference(earliest).inMilliseconds.toDouble();
      final x = (dt / 1000.0) / 600.0 * size.width; // 10 分钟 = 600s 满宽
      final y = size.height * (1 - v / niceMax);
      return Offset(x, y);
    }

    // 上传（橙）+ 下载（蓝）
    final upPath = Path()..moveTo(0, size.height.toDouble());
    final downPath = Path()..moveTo(0, size.height.toDouble());
    final upFillPath = Path();
    final downFillPath = Path();
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      final upOffset = pos(s, s.up.toDouble());
      final downOffset = pos(s, s.down.toDouble());
      if (i == 0) {
        upPath.moveTo(upOffset.dx, upOffset.dy);
        downPath.moveTo(downOffset.dx, downOffset.dy);
        upFillPath.moveTo(upOffset.dx, size.height);
        upFillPath.lineTo(upOffset.dx, upOffset.dy);
        downFillPath.moveTo(downOffset.dx, size.height);
        downFillPath.lineTo(downOffset.dx, downOffset.dy);
      } else {
        upPath.lineTo(upOffset.dx, upOffset.dy);
        downPath.lineTo(downOffset.dx, downOffset.dy);
        upFillPath.lineTo(upOffset.dx, upOffset.dy);
        downFillPath.lineTo(downOffset.dx, downOffset.dy);
      }
    }
    final lastUp = pos(samples.last, samples.last.up.toDouble());
    final lastDown = pos(samples.last, samples.last.down.toDouble());
    upFillPath.lineTo(lastUp.dx, size.height);
    upFillPath.close();
    downFillPath.lineTo(lastDown.dx, size.height);
    downFillPath.close();

    final downFill = Paint()
      ..color = const Color(0xFF168BFA).withValues(alpha: .18)
      ..style = PaintingStyle.fill;
    final upFill = Paint()
      ..color = const Color(0xFFFFA20F).withValues(alpha: .14)
      ..style = PaintingStyle.fill;
    canvas.drawPath(downFillPath, downFill);
    canvas.drawPath(upFillPath, upFill);

    final downStroke = Paint()
      ..color = const Color(0xFF168BFA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final upStroke = Paint()
      ..color = const Color(0xFFFFA20F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(downPath, downStroke);
    canvas.drawPath(upPath, upStroke);

    // 底部时间刻度（每 1 分钟一个）
    final startTime = DateTime.now().subtract(const Duration(minutes: 10));
    for (var i = 0; i <= 10; i += 1) {
      final t = startTime.add(Duration(minutes: i));
      final x = size.width * i / 10;
      if (i % 1 == 0) {
        _drawText(
          canvas,
          '${_two(t.hour)}:${_two(t.minute)}',
          Offset(x - 14, size.height - 12),
          axisTextStyle,
        );
      }
    }
    // 标注最后时间
    _drawText(
      canvas,
      '${_two(latest.hour)}:${_two(latest.minute)}',
      Offset(size.width - 22, size.height - 12),
      axisTextStyle,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _bytesShort(int v) {
    if (v >= 1 << 30) return '${(v / (1 << 30)).toStringAsFixed(0)}GB';
    if (v >= 1 << 20) return '${(v / (1 << 20)).toStringAsFixed(0)}MB';
    if (v >= 1 << 10) return '${(v / (1 << 10)).toStringAsFixed(0)}KB';
    return '$v';
  }

  @override
  bool shouldRepaint(covariant _TrafficChartPainter old) =>
      old.samples != samples;
}

// =============================================================================

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    // 嵌在外层大卡内：略浅底色圆角，与折线图区(略深)形成层次
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _metricBackground(iconColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RsText(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9B9DA9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9B9DA9),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _metricBackground(Color color) {
    if (color == const Color(0xFFFFA20F)) return const Color(0xFF323035);
    if (color == const Color(0xFF2AD364)) return const Color(0xFF293637);
    if (color == const Color(0xFFFF3B5B)) return const Color(0xFF352C35);
    return const Color(0xFF2B3140);
  }
}

// =============================================================================
// 站点测试卡
// =============================================================================

class _SiteTestCard extends StatefulWidget {
  final ProxyAppController controller;
  final VoidCallback onOpen;
  const _SiteTestCard({required this.controller, required this.onOpen});

  @override
  State<_SiteTestCard> createState() => _SiteTestCardState();
}

class _SiteTestCardState extends State<_SiteTestCard> {
  final Map<String, _SiteState> _states = {};
  bool _testing = false;

  static const _items = [
    ('Apple', 'apple', 'www.apple.com'),
    ('GitHub', 'github', 'github.com'),
    ('Google', 'google', 'www.google.com'),
    ('YouTube', 'youtube', 'www.youtube.com'),
  ];

  Future<void> _runAll() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      for (final s in _states.values) {
        s.status = _SiteStatus.running;
      }
    });
    for (final entry in _items) {
      final name = entry.$1;
      _states[name] = _SiteState(status: _SiteStatus.running);
      try {
        // 通过 controller 测速 (内部走代理出口)
        final ms = await widget.controller.probeSingleUrl(
          'https://${entry.$3}',
          timeoutMs: 4000,
        );
        if (!mounted) return;
        setState(() {
          _states[name] = _SiteState(
            status: ms > 0 ? _SiteStatus.success : _SiteStatus.failed,
            ms: ms,
          );
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _states[name] = _SiteState(status: _SiteStatus.failed));
      }
    }
    if (mounted) setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    return RsCard(
      title: '站点测试',
      icon: Icons.wifi_tethering,
      accent: const Color(0xFF168BFA),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.rsText('测速'),
            onPressed: _runAll,
            icon: const Icon(Icons.wifi_find, size: 18),
          ),
          IconButton(
            tooltip: context.rsText('添加'),
            onPressed: widget.onOpen,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: LayoutBuilder(
        builder: (context, c) {
          const cols = 4;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in _items)
                SizedBox(
                  width: (c.maxWidth - 12 * (cols - 1)) / cols,
                  child: _SiteTile(
                    name: entry.$1,
                    brand: entry.$2,
                    host: entry.$3,
                    state: _states[entry.$1] ?? _SiteState(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _SiteStatus { idle, running, success, failed }

class _SiteState {
  _SiteStatus status;
  int? ms;
  _SiteState({this.status = _SiteStatus.idle, this.ms});
}

class _SiteTile extends StatelessWidget {
  final String name;
  final String brand;
  final String host;
  final _SiteState state;
  const _SiteTile({
    required this.name,
    required this.brand,
    required this.host,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final running = state.status == _SiteStatus.running;
    final success = state.status == _SiteStatus.success;
    final failed = state.status == _SiteStatus.failed;
    final color = success
        ? const Color(0xFF2AD364)
        : (failed ? const Color(0xFFFF3B5B) : const Color(0xFF168BFA));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF252A35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 32, child: _BrandLogo(brand: brand)),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Container(
            height: 1,
            color: const Color(0xFF444756).withValues(alpha: .4),
          ),
          const SizedBox(height: 6),
          RsText(
            running
                ? '检测中…'
                : success
                ? '${state.ms}ms'
                : failed
                ? '代理异常'
                : '测试',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 各品牌 logo：用纯绘制/Unicode 字符近似还原，不依赖外部资源。
class _BrandLogo extends StatelessWidget {
  final String brand;
  const _BrandLogo({required this.brand});
  @override
  Widget build(BuildContext context) {
    switch (brand) {
      case 'apple':
        // 黑色圆角方块 + 白色 Apple 形状
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: CustomPaint(
            size: const Size(18, 22),
            painter: _ApplePainter(),
          ),
        );
      case 'github':
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.code, color: Colors.white, size: 20),
        );
      case 'google':
        // 4 色 G
        return Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: CustomPaint(size: const Size(28, 28), painter: _GoogleG()),
        );
      case 'youtube':
        return Container(
          width: 36,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFFF0000),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
        );
      default:
        return const SizedBox(width: 32, height: 32);
    }
  }
}

class _ApplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    // 简化：上下两个圆 + 中间凹槽
    final r = size.width * 0.42;
    final top = Offset(size.width / 2, size.height * 0.45);
    canvas.drawOval(
      Rect.fromCenter(center: top, width: r * 2, height: r * 1.9),
      paint,
    );
    // 叶子
    final leaf = Path()
      ..moveTo(size.width / 2 + r * 0.2, size.height * 0.18)
      ..quadraticBezierTo(
        size.width / 2 + r * 0.5,
        size.height * 0.05,
        size.width / 2 + r * 0.0,
        size.height * 0.10,
      )
      ..quadraticBezierTo(
        size.width / 2 + r * 0.2,
        size.height * 0.20,
        size.width / 2 + r * 0.2,
        size.height * 0.18,
      )
      ..close();
    canvas.drawPath(leaf, paint);
  }

  @override
  bool shouldRepaint(covariant _ApplePainter old) => false;
}

class _GoogleG extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // 蓝/红/黄/绿 四色 G
    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = s * 0.18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final red = Paint()
      ..color = const Color(0xFFEA4335)
      ..strokeWidth = s * 0.18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final yellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..strokeWidth = s * 0.18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final green = Paint()
      ..color = const Color(0xFF34A853)
      ..strokeWidth = s * 0.18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final r = s * 0.36;
    final c = Offset(s / 2, s / 2);
    // 蓝 (左上 1/4)
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      3.93,
      1.57,
      false,
      blue,
    );
    // 红 (右上 1/4)
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      1.57,
      1.57,
      false,
      red,
    );
    // 黄 (右下 1/4)
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      5.50,
      1.57,
      false,
      yellow,
    );
    // 绿 (左下 1/4)
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      0,
      1.57,
      false,
      green,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleG old) => false;
}

// =============================================================================
// IP 信息卡
// =============================================================================

class _IpInfoCard extends StatefulWidget {
  final ProxyAppController controller;
  const _IpInfoCard({required this.controller});

  @override
  State<_IpInfoCard> createState() => _IpInfoCardState();
}

class _IpInfoCardState extends State<_IpInfoCard> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final info = controller.ipInfo;
    final nextRefreshAt = controller.nextIpRefreshAt;
    final refreshSeconds = nextRefreshAt == null
        ? 242
        : math.max(0, nextRefreshAt.difference(DateTime.now()).inSeconds);
    return RsCard(
      title: 'IP 信息',
      icon: Icons.location_on_outlined,
      accent: const Color(0xFF168BFA),
      trailing: IconButton(
        tooltip: context.rsText('刷新'),
        onPressed: () => controller.refreshIpInfo(),
        icon: const Icon(Icons.refresh, size: 18),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SizedBox(
        height: 268,
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _CountryFlag(code: info.countryCode),
                            const SizedBox(width: 8),
                            Text(
                              info.countryCode.isEmpty ? '—' : info.countryCode,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const RsText('IP：', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: RsText(
                                info.ip.isEmpty
                                    ? (info.loading ? '查询中…' : '—')
                                    : _maskIp(info.ip),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const Icon(
                              Icons.remove_red_eye,
                              size: 18,
                              color: Color(0xFFCDCED4),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        RsText(
                          '自治域：${info.asn.isEmpty ? '—' : info.asn}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ipDetailRow('服务商', info.isp, maxLines: 3),
                        const SizedBox(height: 10),
                        _ipDetailRow('组织', info.org, maxLines: 3),
                        const SizedBox(height: 10),
                        _ipDetailRow('位置', info.countryName),
                        const SizedBox(height: 10),
                        _ipDetailRow('时区', info.timezone),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF3D404C)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RsText(
                  '自动刷新：${refreshSeconds}s',
                  style: const TextStyle(
                    color: Color(0xFF9B9DA9),
                    fontSize: 12,
                  ),
                ),
                Text(
                  info.countryCode.isEmpty
                      ? ''
                      : '${info.countryCode}, ${info.fetchedAt?.hour ?? 0}.${info.fetchedAt?.minute ?? 0}, ${info.fetchedAt?.second ?? 0}',
                  style: const TextStyle(
                    color: Color(0xFF9B9DA9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ipDetailRow(String label, String value, {int maxLines = 1}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RsText('$label：', style: const TextStyle(fontSize: 14)),
      Expanded(
        child: Text(
          value.isEmpty ? '—' : value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    ],
  );
}

class _CountryFlag extends StatelessWidget {
  /// 是否要展示“香港特别行政区”区旗（红底+紫荆花）。
  /// 其他地区用一个简化的占位：左侧色块 + 大写国家代码。
  final String code;
  const _CountryFlag({this.code = ''});

  @override
  Widget build(BuildContext context) {
    final c = code.toUpperCase();
    if (c == 'HK') {
      return Container(
        width: 36,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFDE2910),
          borderRadius: BorderRadius.circular(4),
        ),
        child: CustomPaint(painter: _HkFlagPainter()),
      );
    }
    return Container(
      width: 36,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF252A35),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF444756)),
      ),
      child: Text(
        c.isEmpty ? '—' : c,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 简易香港区旗：红底 + 白色五瓣紫荆花（CustomPainter 绘）。
class _HkFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.height * 0.30;
    final paint = Paint()..color = Colors.white;
    final core = Paint()..color = const Color(0xFFDE2910);
    // 5 瓣花：5 个小圆 + 中心圆
    for (var i = 0; i < 5; i++) {
      final angle = -1.5708 + i * 1.2566; // -90° 起，每 72°
      final px = cx + r * 0.95 * 0.6 * _cos(angle);
      final py = cy + r * 0.95 * 0.6 * _sin(angle);
      canvas.drawCircle(Offset(px, py), r * 0.42, paint);
    }
    canvas.drawCircle(Offset(cx, cy), r * 0.32, core);
    // 小红点星
    final star = Paint()..color = const Color(0xFFDE2910);
    for (var i = 0; i < 5; i++) {
      final angle = -1.5708 + i * 1.2566;
      final px = cx + r * 0.95 * 0.6 * _cos(angle);
      final py = cy + r * 0.95 * 0.6 * _sin(angle);
      canvas.drawCircle(Offset(px, py), r * 0.12, star);
    }
  }

  // 包装一下避免引入 dart:math 顶层依赖
  static double _cos(double r) => _cosTable(r);
  static double _sin(double r) => _sinTable(r);
  static double _cosTable(double r) => _trig(r, true);
  static double _sinTable(double r) => _trig(r, false);
  static double _trig(double r, bool isCos) {
    // 借用 math.sin / cos 但放在静态缓存避免全局污染
    return isCos ? _MathCache.cos(r) : _MathCache.sin(r);
  }

  @override
  bool shouldRepaint(covariant _HkFlagPainter old) => false;
}

class _MathCache {
  static double cos(double r) => _c(r);
  static double sin(double r) => _s(r);
  static double _c(double r) => _dartCos(r);
  static double _s(double r) => _dartSin(r);
}

// 真委托给 dart:math
double _dartCos(double r) => _MathBridge.cos(r);
double _dartSin(double r) => _MathBridge.sin(r);

class _MathBridge {
  static double cos(double r) => _importCos(r);
  static double sin(double r) => _importSin(r);
}

double _importCos(double r) => math.cos(r);
double _importSin(double r) => math.sin(r);

// =============================================================================
// Clash 信息卡
// =============================================================================

class _ClashInfoCard extends StatelessWidget {
  final ProxyAppController controller;
  final VoidCallback onSettingsTap;
  const _ClashInfoCard({required this.controller, required this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return RsCard(
      title: 'Clash 信息',
      icon: Icons.memory,
      accent: const Color(0xFFFFA20F),
      trailing: IconButton(
        tooltip: context.rsText('设置'),
        onPressed: onSettingsTap,
        icon: const Icon(Icons.settings_outlined, size: 18),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv(context, '内核版本', controller.engineVersion),
          const _Divider(),
          _kv(
            context,
            '系统代理地址',
            '127.0.0.1:${controller.settings.overrides['port'] ?? '7897'}',
          ),
          const _Divider(),
          _kv(
            context,
            '混合代理端口',
            controller.settings.overrides['mixed-port'] ??
                controller.settings.overrides['port'] ??
                '7897',
          ),
          const _Divider(),
          _kv(context, '运行时间', _formatUptime(controller.startedAt)),
          const _Divider(),
          _kv(context, '规则数量', '${controller.ruleCount}'),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10.5),
    child: Row(
      children: [
        if (_usesLongLocalizedCopy(context))
          Flexible(
            child: RsText(
              k,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFCDCED4), fontSize: 14),
            ),
          )
        else
          RsText(
            k,
            style: const TextStyle(color: Color(0xFFCDCED4), fontSize: 14),
          ),
        const Spacer(),
        if (_usesLongLocalizedCopy(context))
          Flexible(
            child: RsText(
              v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          )
        else
          RsText(
            v,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: const Color(0xFF2A2D38));
}

// =============================================================================
// 系统信息卡
// =============================================================================

class _SystemInfoCard extends StatelessWidget {
  final ProxyAppController controller;
  final VoidCallback onSettingsTap;
  const _SystemInfoCard({
    required this.controller,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    return RsCard(
      title: '系统信息',
      icon: Icons.info_outline,
      accent: const Color(0xFFFF3B5B),
      trailing: IconButton(
        tooltip: context.rsText('设置'),
        onPressed: onSettingsTap,
        icon: const Icon(Icons.settings_outlined, size: 18),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv(context, '操作系统信息', _osLabel()),
          const _Divider(),
          _kv(
            context,
            '开机自启',
            settings.launchAtStartup ? '已启用' : '未启用',
            chipColor: settings.launchAtStartup
                ? const Color(0xFF168BFA)
                : null,
          ),
          const _Divider(),
          _kv(
            context,
            '运行模式',
            '用户模式',
            trailingIcon: Icons.star,
            chipColor: const Color(0xFF168BFA),
          ),
          const _Divider(),
          _kv(context, '最后检查更新', _lastCheckLabel(), link: true),
          const _Divider(),
          _kv(context, 'RS 版本', 'v1.0.0'),
        ],
      ),
    );
  }

  String _osLabel() {
    if (Platform.isMacOS) {
      try {
        final result = Process.runSync('/usr/bin/sw_vers', ['-productVersion']);
        final version = result.stdout.toString().trim();
        if (result.exitCode == 0 && version.isNotEmpty) {
          return 'macOS $version';
        }
      } catch (_) {}
      return 'macOS';
    }
    if (Platform.isWindows) return 'Windows ${Platform.operatingSystemVersion}';
    return Platform.operatingSystem;
  }

  String _lastCheckLabel() {
    final info = controller.updateChecker.lastResult;
    final t = info?.checkedAt;
    if (t == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}/${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  Widget _kv(
    BuildContext context,
    String k,
    String v, {
    Color? chipColor,
    IconData? trailingIcon,
    bool link = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10.5),
    child: Row(
      children: [
        if (_usesLongLocalizedCopy(context))
          Flexible(
            child: RsText(
              k,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFCDCED4), fontSize: 14),
            ),
          )
        else
          RsText(
            k,
            style: const TextStyle(color: Color(0xFFCDCED4), fontSize: 14),
          ),
        const Spacer(),
        if (chipColor != null)
          if (_usesLongLocalizedCopy(context))
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: RsText(
                    v,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: chipColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(4),
              ),
              child: RsText(
                v,
                style: TextStyle(
                  color: chipColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
        else if (_usesLongLocalizedCopy(context))
          Flexible(
            child: RsText(
              v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: link ? TextDecoration.underline : null,
                decorationColor: const Color(0xFF168BFA),
                color: link ? const Color(0xFF168BFA) : null,
              ),
            ),
          )
        else
          RsText(
            v,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: link ? TextDecoration.underline : null,
              decorationColor: const Color(0xFF168BFA),
              color: link ? const Color(0xFF168BFA) : null,
            ),
          ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 4),
          Icon(trailingIcon, size: 14, color: const Color(0xFF168BFA)),
        ],
      ],
    ),
  );
}

// =============================================================================
// 通用
// =============================================================================

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xFFCDCED4)),
      const SizedBox(width: 9),
      Expanded(
        child: RsText(
          text,
          style: const TextStyle(fontSize: 14, color: Color(0xFFF7F7FA)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _SourceInfoLine extends StatelessWidget {
  final IconData icon;
  final String source;
  const _SourceInfoLine({required this.icon, required this.source});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xFFCDCED4)),
      const SizedBox(width: 9),
      const RsText(
        '来自：',
        style: TextStyle(fontSize: 14, color: Color(0xFFF7F7FA)),
      ),
      Expanded(
        child: Text(
          source,
          style: const TextStyle(fontSize: 14, color: Color(0xFF168BFA)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 5),
      const Icon(Icons.open_in_new, size: 12, color: Color(0xFF168BFA)),
    ],
  );
}

String _bytes(int v) {
  if (v >= 1 << 30) return '${(v / (1 << 30)).toStringAsFixed(2)}GB';
  if (v >= 1 << 20) return '${(v / (1 << 20)).toStringAsFixed(2)}MB';
  if (v >= 1 << 10) return '${(v / (1 << 10)).toStringAsFixed(2)}KB';
  return '${v}B';
}

String _subscriptionBytes(int v) {
  const gb = 1 << 30;
  if (v >= gb && v % gb == 0) return '${v ~/ gb}GB';
  return _bytes(v);
}

String _formatBytesShort(int v) {
  if (v >= 1 << 30) return (v / (1 << 30)).toStringAsFixed(2);
  if (v >= 1 << 20) return (v / (1 << 20)).toStringAsFixed(1);
  if (v >= 1 << 10) return (v / (1 << 10)).toStringAsFixed(0);
  return '$v';
}

String _formatSpeed(int bytesPerSec) {
  if (bytesPerSec < 1024) return bytesPerSec.toStringAsFixed(2);
  if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toStringAsFixed(2);
  return (bytesPerSec / 1024 / 1024).toStringAsFixed(2);
}

String _formatUptime(DateTime? startedAt) {
  if (startedAt == null) return '0:00:00';
  final d = DateTime.now().difference(startedAt);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  String two(int n) => n.toString().padLeft(2, '0');
  return '$h:${two(m)}:${two(s)}';
}

String _dateTime(DateTime? v) {
  if (v == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${v.year}-${two(v.month)}-${two(v.day)} ${two(v.hour)}:${two(v.minute)}';
}

String _dateOnly(DateTime? v) {
  if (v == null) return '未提供';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${v.year}-${two(v.month)}-${two(v.day)}';
}

Color _delayColor(int delay) {
  if (delay < 0) return const Color(0xFFFF4D5A);
  if (delay < 200) return const Color(0xFF2AD364);
  if (delay < 500) return const Color(0xFFFFA20F);
  return const Color(0xFFFF4D5A);
}

String _maskIp(String ip) {
  final parts = ip.split('.');
  if (parts.length == 4) {
    return '${parts[0]}.${parts[1]}.${'*' * 3}.${'*' * 3}';
  }
  return ip;
}

// =============================================================================
// 首页布局编辑
// =============================================================================

class _LayoutEditorTile extends StatelessWidget {
  final VoidCallback onTap;
  const _LayoutEditorTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF292C39),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dashboard_customize_outlined,
                size: 16,
                color: Color(0xFF168BFA),
              ),
              SizedBox(width: 8),
              RsText(
                '编辑首页布局',
                style: TextStyle(
                  color: Color(0xFF168BFA),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeLayoutEditor extends StatelessWidget {
  final ProxyAppController controller;
  const _HomeLayoutEditor({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1F222D),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 580),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final layout = controller.homeLayout;
            final order = layout.resolvedOrder();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.dashboard_customize_outlined,
                        color: Color(0xFF168BFA),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const RsText(
                        '首页布局',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: context.rsText('关闭'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const RsText(
                    '上下移动调整顺序，勾选切换显示',
                    style: TextStyle(color: Color(0xFF9B9DA9), fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: order.length,
                      itemBuilder: (context, i) {
                        final id = order[i];
                        final meta = homeCardMetas[id];
                        final title = meta?.title ?? id;
                        final hidden = layout.isHidden(id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF292C39),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: !hidden,
                                onChanged: (_) =>
                                    controller.toggleHomeCardVisibility(id),
                                visualDensity: VisualDensity.compact,
                              ),
                              Expanded(
                                child: RsText(
                                  title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: hidden
                                        ? const Color(0xFF9B9DA9)
                                        : Colors.white,
                                    decoration: hidden
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: context.rsText('上移'),
                                onPressed: i == 0
                                    ? null
                                    : () => controller.reorderHomeCard(
                                        id,
                                        up: true,
                                      ),
                                icon: const Icon(Icons.arrow_upward, size: 16),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                tooltip: context.rsText('下移'),
                                onPressed: i == order.length - 1
                                    ? null
                                    : () => controller.reorderHomeCard(
                                        id,
                                        up: false,
                                      ),
                                icon: const Icon(
                                  Icons.arrow_downward,
                                  size: 16,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await controller.updateHomeLayout(const HomeLayout());
                        },
                        child: const RsText('重置默认'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF168BFA),
                        ),
                        child: const RsText('完成'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
