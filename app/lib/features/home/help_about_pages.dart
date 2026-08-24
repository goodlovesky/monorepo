import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../services/proxy_app_controller.dart';
import '../../widgets/clash_widgets.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _steps = [
    (
      Icons.file_download_outlined,
      '导入配置',
      '进入“配置”，点击右上角“＋”，可通过订阅 URL、配置文件或二维码导入。',
    ),
    (Icons.check_circle_outline, '确认激活', '配置卡片显示“已激活”后返回首页。有多个配置时，先点击准备使用的配置。'),
    (
      Icons.power_settings_new,
      '启动 VPN',
      '点击首页状态卡片，首次启动按系统提示允许 VPN 连接。首页显示“运行中”且状态栏出现 VPN 标识即启动成功。',
    ),
    (Icons.alt_route, '选择节点', '运行后进入“代理”，先点击闪电图标测试延迟，再在需要的分组中选择可用节点。'),
    (Icons.public, '确认可用', '打开常用网页或应用确认网络正常。日常使用时只需在首页启动或停止 VPN。'),
  ];

  static const _troubleshooting = [
    (
      'VPN 启动失败',
      ['确认“配置”页已有一个激活配置。', '返回首页重新启动，并接受系统 VPN 连接提示。', '仍未启动时，打开“日志”查看最新一条错误。'],
    ),
    (
      '启动后无法上网',
      [
        '进入“代理”测试延迟，排除显示“—”或延迟过高的节点。',
        '切换到另一个可用节点，再重新打开网页。',
        '所有节点都不可用时，刷新订阅并重新启动 VPN。',
      ],
    ),
    (
      '连接频繁中断',
      [
        '保留 Clash RS 的运行通知，不要从最近任务中强制结束。',
        '在系统电池设置中允许 Clash RS 后台运行。',
        '使用稳定节点，并确认 Wi-Fi 或移动网络本身正常。',
      ],
    ),
  ];

  static const _faqs = [
    ('为什么首页看不到“代理”卡片？', '“代理”卡片只在 VPN 正常运行时显示。请先点击首页状态卡片启动。'),
    ('如何确保所有应用都经过 VPN？', '进入“设置 → 网络”，打开“自动路由系统流量”，并将访问控制模式设置为“允许所有应用”。'),
    ('订阅或节点信息没有更新？', '进入“配置”点击刷新按钮。若订阅地址发生变化，可编辑配置 URL 后保存并重新激活。'),
    ('延迟数值怎么选？', '延迟数值越低通常响应越快，但稳定性也很重要。可先选延迟较低的节点，使用中出现中断再切换。'),
    ('如何更换当前配置？', '进入“配置”，点击要使用的配置并确认已激活。VPN 正在运行时，先停止再切换配置更稳妥。'),
    ('什么时候需要查看日志？', '在启动失败、配置更新失败或节点无法连接时查看。重点关注最新出现的错误信息。'),
    ('怎样恢复被隐藏的应用图标？', '打开系统拨号盘输入 *#*#252746382#*#*。恢复后可在“设置 → 应用”关闭隐藏应用图标。'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ScreenshotAppBar(title: '帮助'),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
      children: [
        const _IntroCard(),
        const _SectionTitle('快速开始'),
        for (var i = 0; i < _steps.length; i++)
          _StepTile(
            number: i + 1,
            icon: _steps[i].$1,
            title: _steps[i].$2,
            description: _steps[i].$3,
          ),
        const _SectionTitle('使用提示'),
        const _TipTile(
          icon: Icons.shield_outlined,
          title: '全局接管',
          description: '运行期间应用会接管系统网络流量，状态栏同时显示 VPN 标识。',
        ),
        const _TipTile(
          icon: Icons.speed,
          title: '节点测速',
          description: '延迟数值越低通常响应越快。超时节点会显示“—”，可切换其他节点。',
        ),
        const _TipTile(
          icon: Icons.sync,
          title: '更新配置',
          description: '订阅节点变更或大量节点失效时，进入“配置”点击刷新，再确认配置仍处于激活状态。',
        ),
        const _TipTile(
          icon: Icons.notifications_outlined,
          title: '后台运行',
          description: '保留前台服务通知可提高稳定性；系统省电设置可能影响长期后台运行。',
        ),
        const _SectionTitle('故障排查'),
        for (final item in _troubleshooting)
          _TroubleshootingTile(title: item.$1, steps: item.$2),
        const _SectionTitle('常见问题'),
        Card(
          color: AppColors.card,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _faqs.length; i++) ...[
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: AppColors.blue.withValues(alpha: .12),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    iconColor: AppColors.blue,
                    collapsedIconColor: AppColors.muted,
                    title: Text(
                      _faqs[i].$1,
                      style: const TextStyle(fontSize: 14.5, letterSpacing: .6),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _faqs[i].$2,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            height: 1.7,
                            letterSpacing: .4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != _faqs.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class AboutPage extends StatelessWidget {
  final ProxyAppController controller;

  const AboutPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ScreenshotAppBar(title: '关于'),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
        children: [
          const SizedBox(height: 8),
          const Center(child: AppIcon(size: 82)),
          const SizedBox(height: 15),
          const Center(
            child: Text(
              'Clash RS',
              style: TextStyle(fontSize: 27, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 7),
          const Center(
            child: Text(
              '简洁、可靠的 Android 全局代理客户端',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                letterSpacing: .5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: controller.isRunning
                    ? AppColors.blue.withValues(alpha: .18)
                    : AppColors.cardElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: controller.isRunning
                      ? AppColors.blue
                      : AppColors.divider,
                ),
              ),
              child: Text(
                controller.isRunning ? 'VPN 正在运行' : 'VPN 已停止',
                style: TextStyle(
                  color: controller.isRunning
                      ? AppColors.blue
                      : AppColors.muted,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
          const _SectionTitle('版本信息'),
          _InfoCard(
            children: [
              const _InfoRow(label: '应用版本', value: '1.0.0 (1)'),
              _InfoRow(label: '代理核心', value: controller.version),
              const _InfoRow(label: '运行平台', value: 'Android'),
              _InfoRow(
                label: '当前配置',
                value: controller.activeProfile?.name ?? '尚未配置',
              ),
              const _InfoRow(label: '接管范围', value: '全局 VPN'),
            ],
          ),
          const _SectionTitle('工作方式'),
          const _InfoCard(
            children: [
              _DescriptionRow(
                icon: Icons.vpn_key_outlined,
                title: '全局流量接管',
                description: 'VPN 运行后接管设备网络流量，并按照当前配置决定连接方式。',
              ),
              _DescriptionRow(
                icon: Icons.alt_route,
                title: '规则与节点',
                description: '根据配置中的规则自动分流，也可以在代理页面手动选择所需节点。',
              ),
              _DescriptionRow(
                icon: Icons.storage_outlined,
                title: '本地配置',
                description: '配置、设置和运行日志保存在应用私有目录，由用户自行管理订阅来源。',
              ),
            ],
          ),
          const _SectionTitle('开源与隐私'),
          const _InfoCard(
            children: [
              _InfoRow(label: '软件协议', value: 'GPL-3.0-or-later'),
              _InfoRow(label: '数据原则', value: '不内置账号与云端同步'),
              _InfoRow(label: '网络说明', value: '流量取决于所选订阅节点'),
            ],
          ),
        ],
      ),
    ),
  );
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.blue.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.blue.withValues(alpha: .55)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_outline, color: AppColors.blue, size: 25),
        SizedBox(width: 13),
        Expanded(
          child: Text(
            '按顺序完成下方步骤即可使用。遇到问题时，先按“故障排查”逐项检查。',
            style: TextStyle(fontSize: 14, height: 1.65, letterSpacing: .6),
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.blue,
        fontSize: 15,
        letterSpacing: 1.5,
      ),
    ),
  );
}

class _StepTile extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String description;

  const _StepTile({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: ClashCard(
      color: AppColors.card,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.blue, size: 22),
              ),
              Positioned(
                right: -5,
                top: -6,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: AppColors.blue,
                  child: Text('$number', style: const TextStyle(fontSize: 10)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    height: 1.55,
                    letterSpacing: .35,
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

class _TipTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _TipTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 42, child: Icon(icon, color: AppColors.blue, size: 23)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14.5)),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TroubleshootingTile extends StatelessWidget {
  final String title;
  final List<String> steps;

  const _TroubleshootingTile({required this.title, required this.steps});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: ClashCard(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.build_circle_outlined,
                color: AppColors.blue,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 14.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 19,
                    height: 19,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.cardElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.3,
                        height: 1.55,
                      ),
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

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: children),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13.5)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}

class _DescriptionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _DescriptionRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.blue, size: 23),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.3,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
