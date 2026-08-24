import 'package:flutter/material.dart';

import '../../../models/app_settings.dart';
import '../../../services/proxy_app_controller.dart';
import '../desktop_app.dart' show DesktopColors;
import '../diagnostics_sheet.dart';

/// mac-1010 设置基础页：系统设置 / Clash 设置 / RS 基础设置。
class SettingsPage extends StatefulWidget {
  final ProxyAppController controller;
  const SettingsPage({super.key, required this.controller});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettings value = widget.controller.settings;
  final ports = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final entry in {
      'port': '17890',
      'socks-port': '17891',
      'mixed-port': '17892',
      'controller-port': '9090',
    }.entries) {
      ports[entry.key] = TextEditingController(
        text: value.overrides[entry.key] ?? entry.value,
      );
    }
  }

  @override
  void dispose() {
    for (final c in ports.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final overrides = {...value.overrides};
    final used = <int>{};
    for (final entry in ports.entries) {
      final port = int.tryParse(entry.value.text);
      if (port == null || port < 1 || port > 65535) {
        _msg('${entry.key} 端口范围必须是 1–65535');
        return;
      }
      if (!used.add(port)) {
        _msg('端口 $port 重复');
        return;
      }
      overrides[entry.key] = '$port';
    }
    value = value.copyWith(overrides: overrides);
    await widget.controller.updateSettings(value);
    if (mounted) _msg('设置已保存');
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  void _setMeta(String key, String next) => setState(() {
    value = value.copyWith(meta: {...value.meta, key: next});
  });

  Future<void> _editStartupScript() async {
    final editor = TextEditingController(text: value.meta['startup.script']);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('启动脚本'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: editor,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(hintText: '代理核心启动后执行的命令（可留空）'),
          ),
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
    if (save == true) _setMeta('startup.script', editor.text);
    editor.dispose();
  }

  Future<void> _showInfo(String title, String body) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('完成'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      _GroupCard(
        title: '系统设置',
        icon: Icons.desktop_windows,
        children: [
          _RowSwitch(
            icon: Icons.laptop_mac,
            label: '虚拟网卡自动路由',
            value: value.autoRoute,
            onChanged: (v) =>
                setState(() => value = value.copyWith(autoRoute: v)),
          ),
          _RowSwitch(
            icon: Icons.play_circle_outline,
            label: '系统代理',
            value: value.systemProxy,
            onChanged: (v) =>
                setState(() => value = value.copyWith(systemProxy: v)),
          ),
          _RowSwitch(
            icon: Icons.power_settings_new,
            label: '开机自启',
            value: value.launchAtStartup,
            onChanged: (v) =>
                setState(() => value = value.copyWith(launchAtStartup: v)),
          ),
          _RowSwitch(
            icon: Icons.flash_on,
            label: '静默启动',
            value: value.silentStart,
            onChanged: (v) =>
                setState(() => value = value.copyWith(silentStart: v)),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _GroupCard(
        title: 'Clash 设置',
        icon: Icons.router,
        children: [
          _RowSwitch(
            icon: Icons.share,
            label: '局域网连接',
            value: value.allowLan,
            onChanged: (v) =>
                setState(() => value = value.copyWith(allowLan: v)),
          ),
          _RowSwitch(
            icon: Icons.dns,
            label: 'DNS 覆写',
            value: value.dnsEnabled,
            onChanged: (v) =>
                setState(() => value = value.copyWith(dnsEnabled: v)),
          ),
          _RowSwitch(
            icon: Icons.public,
            label: 'IPv6',
            value: value.ipv6,
            onChanged: (v) => setState(() => value = value.copyWith(ipv6: v)),
          ),
          _RowSwitch(
            icon: Icons.speed,
            label: '统一延迟',
            value: value.unifiedDelay,
            onChanged: (v) =>
                setState(() => value = value.copyWith(unifiedDelay: v)),
          ),
          _RowChoice(
            icon: Icons.layers_outlined,
            label: 'TUN 网络栈',
            value: value.stackMode,
            values: const {
              'system': 'System',
              'gvisor': 'gVisor',
              'mixed': 'Mixed',
            },
            onChanged: (v) =>
                setState(() => value = value.copyWith(stackMode: v)),
          ),
          _RowSwitch(
            icon: Icons.alt_route,
            label: 'DNS 劫持',
            value: value.dnsHijack,
            onChanged: (v) =>
                setState(() => value = value.copyWith(dnsHijack: v)),
          ),
          _RowChoice(
            icon: Icons.thermostat,
            label: '日志级别',
            value: value.logLevel,
            values: const {
              'debug': 'Debug',
              'info': 'Info',
              'warning': 'Warn',
              'error': 'Error',
            },
            onChanged: (v) =>
                setState(() => value = value.copyWith(logLevel: v)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ports.entries
                  .map(
                    (e) => SizedBox(
                      width: 130,
                      child: TextField(
                        controller: e.value,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: e.key,
                          isDense: true,
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
                  )
                  .toList(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _GroupCard(
        title: 'RS 基础设置',
        icon: Icons.tune,
        children: [
          _RowChoice(
            icon: Icons.translate,
            label: '语言设置',
            value: value.language,
            values: const {'zh-CN': '中文', 'en-US': 'English'},
            onChanged: (v) =>
                setState(() => value = value.copyWith(language: v)),
          ),
          _RowChoice(
            icon: Icons.dark_mode,
            label: '主题模式',
            value: value.darkMode,
            values: const {'system': '跟随系统', 'dark': '深色', 'light': '浅色'},
            onChanged: (v) =>
                setState(() => value = value.copyWith(darkMode: v)),
          ),
          _RowChoice(
            icon: Icons.palette_outlined,
            label: '主题色',
            value: value.accentColor,
            values: const {'blue': '蓝色', 'green': '绿色', 'orange': '橙色'},
            onChanged: (v) =>
                setState(() => value = value.copyWith(accentColor: v)),
          ),
          _RowSwitch(
            icon: Icons.animation,
            label: '界面动画',
            value: value.animations,
            onChanged: (v) =>
                setState(() => value = value.copyWith(animations: v)),
          ),
          _RowSwitch(
            icon: Icons.notifications_outlined,
            label: '桌面通知',
            value: value.notifications,
            onChanged: (v) =>
                setState(() => value = value.copyWith(notifications: v)),
          ),
          _RowSwitch(
            icon: Icons.minimize,
            label: '关闭时驻留托盘',
            value: value.closeToTray,
            onChanged: (v) =>
                setState(() => value = value.copyWith(closeToTray: v)),
          ),
          _RowChoice(
            icon: Icons.touch_app,
            label: '托盘点击事件',
            value: value.meta['tray.click'] ?? 'show',
            values: const {'show': '显示主窗口', 'quit': '退出应用'},
            onChanged: (v) => _setMeta('tray.click', v),
          ),
          _RowChoice(
            icon: Icons.content_copy,
            label: '复制环境变量类型',
            value: value.meta['env.shell'] ?? 'bash',
            values: const {
              'bash': 'Bash',
              'zsh': 'Zsh',
              'powershell': 'PowerShell',
            },
            onChanged: (v) => _setMeta('env.shell', v),
          ),
          _RowChoice(
            icon: Icons.home,
            label: '启动页面',
            value: value.homeSection,
            values: const {'home': '首页', 'proxy': '代理', 'subscriptions': '订阅'},
            onChanged: (v) =>
                setState(() => value = value.copyWith(homeSection: v)),
          ),
          _RowLink(
            icon: Icons.play_arrow,
            label: '启动脚本',
            onTap: _editStartupScript,
          ),
          _RowLink(
            icon: Icons.color_lens,
            label: '主题设置',
            onTap: () => _showInfo('主题设置', '主题模式与主题色会在保存后即时应用。'),
          ),
          _RowLink(
            icon: Icons.tune,
            label: '界面设置',
            onTap: () => _showInfo('界面设置', '首页卡片可在首页右上角的布局按钮中排序和隐藏。'),
          ),
          _RowLink(
            icon: Icons.settings,
            label: '杂项设置',
            onTap: () => _showInfo('杂项设置', '托盘、通知、动画和静默启动设置集中在本页。'),
          ),
          _RowLink(
            icon: Icons.keyboard,
            label: '热键设置',
            onTap: () => _showInfo('热键设置', '数字 1–8 切换页面，/ 聚焦搜索，H 返回首页。'),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _GroupCard(
        title: '更新与诊断',
        icon: Icons.update,
        children: [
          _RowLink(
            icon: Icons.refresh,
            label: widget.controller.updateInfo?.available == true
                ? '有新版本 v${widget.controller.updateInfo!.version}'
                : '仅检查更新',
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final info = await widget.controller.checkForUpdate();
              if (!context.mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    info.available
                        ? '发现新版本 v${info.version}：${info.url}'
                        : '当前已是最新版本 v${info.version}',
                  ),
                ),
              );
            },
          ),
          _RowLink(
            icon: Icons.health_and_safety_outlined,
            label: '诊断与错误详情',
            onTap: () => DiagnosticsSheet.show(context, widget.controller),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => setState(() => value = AppSettings.defaults),
            child: const Text('恢复默认值'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF168BFA),
            ),
            icon: const Icon(Icons.save),
            label: const Text('保存并应用'),
          ),
        ],
      ),
    ],
  );
}

class _GroupCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _GroupCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF292C39),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF168BFA)),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const Divider(height: 24, color: Color(0xFF2A2D38)),
        ...children,
      ],
    ),
  );
}

class _RowSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _RowSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF168BFA)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _RowChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Map<String, String> values;
  final ValueChanged<String> onChanged;
  const _RowChoice({
    required this.icon,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF168BFA)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF252936),
            border: Border.all(color: const Color(0xFF444756)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: values.containsKey(value) ? value : values.keys.first,
              dropdownColor: const Color(0xFF292C39),
              items: values.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class _RowLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RowLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF168BFA)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          const Icon(Icons.chevron_right, color: DesktopColors.muted, size: 18),
        ],
      ),
    ),
  );
}
