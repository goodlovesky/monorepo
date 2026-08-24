import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/app_settings.dart';
import '../../services/proxy_app_controller.dart';
import '../../widgets/clash_widgets.dart';

class SettingsPage extends StatelessWidget {
  final ProxyAppController controller;
  const SettingsPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ScreenshotAppBar(title: '设置'),
    body: ListView(
      padding: const EdgeInsets.only(top: 11),
      children: [
        _SettingsMenu(
          icon: Icons.settings,
          title: '应用',
          onTap: () =>
              _push(context, ApplicationSettingsPage(controller: controller)),
        ),
        _SettingsMenu(
          icon: Icons.dns,
          title: '网络',
          onTap: () =>
              _push(context, NetworkSettingsPage(controller: controller)),
        ),
        _SettingsMenu(
          icon: Icons.extension,
          title: '覆写',
          onTap: () =>
              _push(context, OverrideSettingsPage(controller: controller)),
        ),
        _SettingsMenu(
          icon: Icons.hub,
          title: 'Meta 特性',
          logo: true,
          onTap: () => _push(context, MetaSettingsPage(controller: controller)),
        ),
      ],
    ),
  );

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class _SettingsMenu extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool logo;
  const _SettingsMenu({
    required this.icon,
    required this.title,
    required this.onTap,
    this.logo = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 75,
      child: Row(
        children: [
          SizedBox(
            width: 65,
            child: logo
                ? const Center(child: ClashLogo(size: 30))
                : Icon(icon, size: 29),
          ),
          Text(title, style: const TextStyle(fontSize: 16, letterSpacing: 1.3)),
        ],
      ),
    ),
  );
}

class ApplicationSettingsPage extends StatelessWidget {
  final ProxyAppController controller;
  const ApplicationSettingsPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final settings = controller.settings;
      return Scaffold(
        appBar: const ScreenshotAppBar(title: '应用'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 13, 18, 40),
          children: [
            const _SectionTitle('行为'),
            _SwitchSetting(
              icon: Icons.settings_backup_restore,
              title: '自动重启',
              subtitle: '允许 Clash 自动重启',
              value: settings.autoRestart,
              onChanged: (value) => controller.updateSettings(
                settings.copyWith(autoRestart: value),
                restartVpn: false,
              ),
            ),
            const _SectionTitle('界面'),
            _ChoiceSetting(
              icon: Icons.dark_mode,
              title: '暗黑模式',
              value: settings.darkMode == 'system'
                  ? '跟随系统 (Android 10+)'
                  : '始终暗黑',
              choices: const {'system': '跟随系统 (Android 10+)', 'dark': '始终暗黑'},
              onChanged: (value) => controller.updateSettings(
                settings.copyWith(darkMode: value),
                restartVpn: false,
              ),
            ),
            _SwitchSetting(
              icon: Icons.visibility_off,
              title: '隐藏应用图标',
              subtitle: '可以在拨号盘输入\n*#*#252746382#*#* 打开应用',
              value: settings.hideLauncher,
              onChanged: (value) => controller.updateSettings(
                settings.copyWith(hideLauncher: value),
                restartVpn: false,
              ),
            ),
            _SwitchSetting(
              icon: Icons.layers,
              title: '从最近任务隐藏',
              subtitle: '在最近任务中隐藏应用',
              value: settings.hideRecents,
              onChanged: (value) => controller.updateSettings(
                settings.copyWith(hideRecents: value),
                restartVpn: false,
              ),
            ),
            const _SectionTitle('服务'),
            _SwitchSetting(
              icon: Icons.domain,
              title: '显示流量',
              subtitle: '在通知中自动刷新流量',
              value: settings.showTraffic,
              onChanged: (value) => controller.updateSettings(
                settings.copyWith(showTraffic: value),
                restartVpn: false,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class NetworkSettingsPage extends StatelessWidget {
  final ProxyAppController controller;
  const NetworkSettingsPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final s = controller.settings;
      Future<void> update(AppSettings next) => controller.updateSettings(next);
      return Scaffold(
        appBar: const ScreenshotAppBar(title: '网络'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 50),
          children: [
            _SwitchSetting(
              icon: Icons.public,
              title: '自动路由系统流量',
              subtitle: '通过 VpnService 自动路由所有系统\n流量',
              value: s.autoRoute,
              onChanged: (v) => update(s.copyWith(autoRoute: v)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 48, top: 4, bottom: 13),
              child: Text(
                'VpnService 选项',
                style: TextStyle(color: AppColors.blue, fontSize: 13.5),
              ),
            ),
            _SwitchSetting.compact(
              title: '绕过私有网络',
              subtitle: '绕过私有网络地址',
              value: s.bypassPrivate,
              onChanged: (v) => update(s.copyWith(bypassPrivate: v)),
            ),
            _SwitchSetting.compact(
              title: 'DNS 劫持',
              subtitle: '处理所有 DNS 数据包',
              value: s.dnsHijack,
              onChanged: (v) => update(s.copyWith(dnsHijack: v)),
            ),
            _SwitchSetting.compact(
              title: '允许应用绕过',
              subtitle: '允许其他应用绕过 VPN',
              value: s.allowBypass,
              onChanged: (v) => update(s.copyWith(allowBypass: v)),
            ),
            _SwitchSetting.compact(
              title: '允许 Ipv6',
              subtitle: '通过 VpnService 代理 Ipv6 流量',
              value: s.ipv6,
              onChanged: (v) => update(s.copyWith(ipv6: v)),
            ),
            _SwitchSetting.compact(
              title: '系统代理',
              subtitle: '为 VpnService 附加 HTTP 代理',
              value: s.systemProxy,
              onChanged: (v) => update(s.copyWith(systemProxy: v)),
            ),
            _ChoiceSetting.compact(
              title: 'Stack Mode',
              value: _stackLabel(s.stackMode),
              choices: const {
                'system': 'System Stack',
                'gvisor': 'GVisor Stack',
                'mixed': 'Mixed Stack',
              },
              onChanged: (v) => update(s.copyWith(stackMode: v)),
            ),
            _ChoiceSetting.compact(
              title: '访问控制模式',
              value: {
                'all': '允许所有应用',
                'allow': '仅允许列表应用',
                'deny': '排除列表应用',
              }[s.accessMode]!,
              choices: const {
                'all': '允许所有应用',
                'allow': '仅允许列表应用',
                'deny': '排除列表应用',
              },
              onChanged: (v) => update(s.copyWith(accessMode: v)),
            ),
            _EditableSetting(
              compact: true,
              title: '访问控制应用包列表',
              value: s.accessPackages.isEmpty
                  ? '为应用配置访问权限'
                  : s.accessPackages.join(', '),
              onEdit: () async {
                final value = await _editText(
                  context,
                  '访问控制应用包列表',
                  s.accessPackages.join('\n'),
                  hint: '每行一个包名',
                );
                if (value != null) {
                  final packages = value
                      .split(RegExp(r'[\n,]+'))
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  await update(s.copyWith(accessPackages: packages));
                }
              },
            ),
          ],
        ),
      );
    },
  );

  static String _stackLabel(String value) =>
      {
        'system': 'System Stack',
        'gvisor': 'GVisor Stack',
        'mixed': 'Mixed Stack',
      }[value] ??
      value;
}

class OverrideSettingsPage extends StatelessWidget {
  final ProxyAppController controller;
  const OverrideSettingsPage({super.key, required this.controller});

  static const groups = <String, List<(String, String)>>{
    '常规': [
      ('port', 'HTTP 端口'),
      ('socks-port', 'Socks 端口'),
      ('redir-port', 'Redirect 端口'),
      ('tproxy-port', 'TProxy 端口'),
      ('mixed-port', '复合端口'),
      ('authentication', '认证'),
      ('allow-lan', '允许来自局域网的连接'),
      ('ipv6', 'IPv6'),
      ('bind-address', '监听地址'),
      ('external-controller', 'External Controller'),
      ('external-controller-tls', 'External Controller TLS'),
      ('external-controller-cors', 'External Controller Allow Origins'),
      (
        'external-controller-private',
        'External Controller Allow Private Network',
      ),
      ('secret', 'Secret'),
      ('mode', '模式'),
      ('log-level', '日志级别'),
      ('hosts', 'Hosts'),
    ],
    'DNS': [
      ('dns.policy', '策略'),
      ('dns.prefer-h3', 'H3 优先'),
      ('dns.listen', '监听'),
      ('dns.append-system', '追加系统 DNS'),
      ('dns.ipv6', 'IPv6'),
      ('dns.use-hosts', '使用 Hosts'),
      ('dns.enhanced-mode', '增强模式'),
      ('dns.nameserver', 'Name Server'),
      ('dns.fallback', 'Fallback Name Server'),
      ('dns.default-nameserver', 'Default Name Server'),
      ('dns.fake-ip-filter', 'FakeIP 过滤器'),
      ('dns.fake-ip-filter-mode', 'FakeIP 过滤器模式'),
      ('dns.fallback-geoip', 'GeoIP Fallback'),
      ('dns.fallback-region', 'GeoIP Fallback 区域代码'),
      ('dns.fallback-ipcidr', 'IPCIDR Fallback'),
      ('dns.fallback-domain', '域名 Fallback'),
    ],
  };

  @override
  Widget build(BuildContext context) => _MapSettingsPage(
    title: '覆写',
    values: controller.settings.overrides,
    groups: groups,
    onReset: () => controller.updateSettings(
      controller.settings.copyWith(overrides: const {}),
    ),
    onChanged: (values) => controller.updateSettings(
      controller.settings.copyWith(overrides: values),
    ),
  );
}

class MetaSettingsPage extends StatelessWidget {
  final ProxyAppController controller;
  const MetaSettingsPage({super.key, required this.controller});

  static const groups = <String, List<(String, String)>>{
    '': [
      ('force-domain', '强制解析域名'),
      ('skip-domain', '跳过域名'),
      ('skip-source-ip', '跳过源 IP'),
      ('skip-destination-ip', '跳过目标 IP'),
    ],
    '设置': [
      ('unified-delay', '统一延迟'),
      ('geodata-mode', 'Geodata 模式'),
      ('tcp-concurrent', 'TCP 并发'),
      ('process-mode', '查找进程模式'),
    ],
    '嗅探设置': [
      ('sniffing', '策略'),
      ('sniff-http-ports', 'Sniff HTTP Ports'),
      ('sniff-http-override', 'Sniff HTTP Override Destination'),
      ('sniff-tls-ports', 'Sniff TLS Ports'),
    ],
  };

  @override
  Widget build(BuildContext context) => _MapSettingsPage(
    title: 'Meta 特性',
    values: controller.settings.meta,
    groups: groups,
    onReset: () =>
        controller.updateSettings(controller.settings.copyWith(meta: const {})),
    onChanged: (values) =>
        controller.updateSettings(controller.settings.copyWith(meta: values)),
    extra: [
      const _SectionTitle('Geo 文件', left: 0),
      for (final item in const [
        ('geoip', '导入 GeoIP 数据库'),
        ('geosite', '导入 GeoSite 数据库'),
        ('country', '导入 Country 数据库'),
        ('asn', '导入 ASN 数据库'),
      ])
        _EditableSetting(
          compact: true,
          title: item.$2,
          value: controller.settings.meta['file.${item.$1}'] ?? '点击导入...',
          onEdit: () => _importGeo(context, item.$1),
        ),
    ],
  );

  Future<void> _importGeo(BuildContext context, String kind) async {
    final result = await FilePicker.pickFiles();
    final path = result.isEmpty ? null : result.single.path;
    if (path == null) return;
    try {
      await controller.importGeoFile(kind, path);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Geo 文件已导入')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _MapSettingsPage extends StatefulWidget {
  final String title;
  final Map<String, String> values;
  final Map<String, List<(String, String)>> groups;
  final Future<void> Function() onReset;
  final Future<void> Function(Map<String, String>) onChanged;
  final List<Widget> extra;
  const _MapSettingsPage({
    required this.title,
    required this.values,
    required this.groups,
    required this.onReset,
    required this.onChanged,
    this.extra = const [],
  });

  @override
  State<_MapSettingsPage> createState() => _MapSettingsPageState();
}

class _MapSettingsPageState extends State<_MapSettingsPage> {
  late Map<String, String> values;
  @override
  void initState() {
    super.initState();
    values = {...widget.values};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ScreenshotAppBar(
      title: widget.title,
      actions: [
        IconButton(onPressed: _reset, icon: const Icon(Icons.replay, size: 27)),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(66, 10, 18, 45),
      children: [
        for (final group in widget.groups.entries) ...[
          if (group.key.isNotEmpty) _SectionTitle(group.key, left: 0),
          for (final field in group.value)
            _EditableSetting(
              compact: true,
              title: field.$2,
              value: values[field.$1]?.isNotEmpty == true
                  ? values[field.$1]!
                  : '不修改',
              onEdit: () => _edit(field.$1, field.$2),
            ),
        ],
        ...widget.extra,
      ],
    ),
  );

  Future<void> _edit(String key, String title) async {
    final value = await _editText(
      context,
      title,
      values[key] ?? '',
      hint: '留空表示不修改',
    );
    if (value == null) return;
    setState(() {
      if (value.trim().isEmpty) {
        values.remove(key);
      } else {
        values[key] = value.trim();
      }
    });
    await widget.onChanged(values);
  }

  Future<void> _reset() async {
    setState(values.clear);
    await widget.onReset();
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final double left;
  const _SectionTitle(this.text, {this.left = 48});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(left, 10, 0, 11),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.blue,
        fontSize: 13.5,
        letterSpacing: 1,
      ),
    ),
  );
}

class _SwitchSetting extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;
  const _SwitchSetting({
    this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  }) : compact = false;
  const _SwitchSetting.compact({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  }) : icon = null,
       compact = true;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: compact ? 75 : 68,
    child: Row(
      children: [
        if (icon != null)
          SizedBox(width: 48, child: Icon(icon, size: 29))
        else
          const SizedBox(width: 48),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 15, letterSpacing: .8),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 44,
          child: Align(
            alignment: Alignment.centerRight,
            child: Transform.scale(
              scale: .65,
              alignment: Alignment.centerRight,
              child: Switch(value: value, onChanged: onChanged),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChoiceSetting extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String value;
  final Map<String, String> choices;
  final ValueChanged<String> onChanged;
  final bool compact;
  const _ChoiceSetting({
    this.icon,
    required this.title,
    required this.value,
    required this.choices,
    required this.onChanged,
  }) : compact = false;
  const _ChoiceSetting.compact({
    required this.title,
    required this.value,
    required this.choices,
    required this.onChanged,
  }) : icon = null,
       compact = true;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final selected = await _choose(context, title, choices);
      if (selected != null) onChanged(selected);
    },
    child: SizedBox(
      height: compact ? 75 : 68,
      child: Row(
        children: [
          if (icon != null)
            SizedBox(width: 48, child: Icon(icon, size: 29))
          else
            const SizedBox(width: 48),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EditableSetting extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onEdit;
  final bool compact;
  const _EditableSetting({
    required this.title,
    required this.value,
    required this.onEdit,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onEdit,
    child: SizedBox(
      height: compact ? 76 : 68,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, letterSpacing: .7)),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _editText(
  BuildContext context,
  String title,
  String initial, {
  String? hint,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 5,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  // The dialog route still paints for its reverse animation after pop. Delay
  // disposal so the TextField cannot observe an already-disposed controller.
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  return result;
}

Future<String?> _choose(
  BuildContext context,
  String title,
  Map<String, String> values,
) => showModalBottomSheet<String>(
  context: context,
  backgroundColor: AppColors.card,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Text(title, style: const TextStyle(fontSize: 17)),
        ),
        for (final entry in values.entries)
          ListTile(
            title: Text(entry.value),
            onTap: () => Navigator.pop(context, entry.key),
          ),
      ],
    ),
  ),
);
