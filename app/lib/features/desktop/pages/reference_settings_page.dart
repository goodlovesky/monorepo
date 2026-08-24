import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/app_settings.dart';
import '../../../platform/desktop/desktop_network_service.dart';
import '../../../services/proxy_app_controller.dart';
import '../desktop_app.dart' show DesktopColors, DesktopSection;
import '../diagnostics_sheet.dart';

/// Clash RS reference settings surface sized for the fixed 960×720 window.
class ReferenceSettingsPage extends StatefulWidget {
  final ProxyAppController controller;
  final DesktopNetworkService network;
  final ValueChanged<DesktopNetworkMode> onNetworkModeChange;
  final ValueChanged<DesktopSection> onNavigate;
  final Future<void> Function()? onQuit;
  const ReferenceSettingsPage({
    super.key,
    required this.controller,
    required this.network,
    required this.onNetworkModeChange,
    required this.onNavigate,
    this.onQuit,
  });

  @override
  State<ReferenceSettingsPage> createState() => _ReferenceSettingsPageState();
}

class _ReferenceSettingsPageState extends State<ReferenceSettingsPage> {
  late AppSettings value = widget.controller.settings;

  Future<void> _set(AppSettings next, {bool? restartVpn}) async {
    setState(() => value = next);
    if (!widget.controller.ready) return;
    final previousMode = widget.network.mode;
    final needsRestart =
        restartVpn ??
        ProxyAppController.settingsRequireCoreRestart(
          widget.controller.settings,
          next,
        );
    if (needsRestart && previousMode != DesktopNetworkMode.off) {
      _changeNetworkMode(DesktopNetworkMode.off);
      await _waitForNetworkMode(DesktopNetworkMode.off);
      await widget.controller.updateSettings(next, restartVpn: false);
      _changeNetworkMode(previousMode);
      await _waitForNetworkMode(previousMode);
    } else {
      await widget.controller.updateSettings(next, restartVpn: restartVpn);
    }
    if (!mounted) return;
    setState(() => value = widget.controller.settings);
  }

  Future<void> _meta(String key, String next) =>
      _set(value.copyWith(meta: {...value.meta, key: next}));

  void _changeNetworkMode(DesktopNetworkMode mode) {
    widget.onNetworkModeChange(mode);
  }

  Future<void> _waitForNetworkMode(DesktopNetworkMode mode) async {
    for (var attempt = 0; attempt < 80; attempt++) {
      if (widget.network.mode == mode) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('网络模式切换超时：${mode.name}');
  }

  Future<void> _info(String title, String body) => showDialog<void>(
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

  Future<void> _openDirectory(String title, String path) async {
    await Directory(path).create(recursive: true);
    final result = Platform.isWindows
        ? await Process.run('explorer.exe', [path])
        : await Process.run('open', [path]);
    if (result.exitCode != 0 && mounted) {
      await _info('$title打开失败', '${result.stderr}');
    }
  }

  Future<void> _backupSettings() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('备份设置'),
        content: const Text('导出当前设置，或从已有的 JSON 备份恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'restore'),
            child: const Text('恢复备份'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'export'),
            child: const Text('导出备份'),
          ),
        ],
      ),
    );
    if (action == 'export') {
      final file = await widget.controller.exportBackup();
      if (mounted) await _info('备份已导出', file.path);
    } else if (action == 'restore') {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      final path = picked?.path;
      if (path == null) return;
      if (!mounted) return;
      final mode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('恢复方式'),
          content: const Text('替换会移除当前配置；合并会按订阅地址或名称更新并去重。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'merge'),
              child: const Text('合并'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'replace'),
              child: const Text('替换'),
            ),
          ],
        ),
      );
      if (mode == null) return;
      await widget.controller.restoreBackup(path, replace: mode == 'replace');
      if (mounted) await _info('恢复完成', path);
    }
  }

  Future<void> _updateGeoData() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['dat', 'db', 'mmdb'],
    );
    final path = picked?.path;
    if (path == null) return;
    final kind = path.toLowerCase().contains('site') ? 'geosite' : 'geoip';
    await widget.controller.importGeoFile(kind, path);
    if (mounted) await _info('GeoData 已更新', path);
  }

  Future<void> _checkUpdate() async {
    final update = await widget.controller.checkForUpdate();
    if (!mounted) return;
    await _info(
      '版本检查',
      update.available
          ? '发现 v${update.version}\n${update.url}'
          : '当前已是最新版本 v${update.version}',
    );
  }

  Future<void> _copyText(String title, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$title已复制')));
  }

  String get _controllerAddress =>
      'http://127.0.0.1:${value.overrides['controller-port'] ?? '9090'}';

  String get _coreVersionLabel {
    final raw = widget.controller.version.trim();
    if (raw.isEmpty) return 'Mihomo';
    final normalized = raw.toLowerCase().startsWith('mihomo ')
        ? raw.substring('mihomo '.length)
        : raw;
    return '$normalized Mihomo';
  }

  Future<void> _openWebUi() async {
    final url = '$_controllerAddress/ui';
    final result = Platform.isWindows
        ? await Process.run('cmd.exe', ['/c', 'start', '', url])
        : await Process.run('open', [url]);
    if (result.exitCode != 0 && mounted) {
      await _info('打开网页界面失败', '${result.stderr}');
    }
  }

  Future<void> _exportDiagnostics() async {
    final support = Directory(
      widget.controller.supportPath ?? Directory.systemTemp.path,
    );
    await support.create(recursive: true);
    final file = File(
      '${support.path}/clash-rs-diagnostics-${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    final report = StringBuffer()
      ..writeln('=== Clash RS 诊断信息 ===')
      ..writeln('生成时间：${DateTime.now().toIso8601String()}')
      ..writeln('平台：${Platform.operatingSystemVersion}')
      ..writeln('核心版本：${widget.controller.version}')
      ..writeln('运行中：${widget.controller.isRunning}')
      ..writeln('网络模式：${widget.network.mode.name}')
      ..writeln('代理模式：${widget.controller.proxyMode}')
      ..writeln('活动连接：${widget.controller.connections.length}')
      ..writeln('规则数量：${widget.controller.rules.length}')
      ..writeln('当前配置：${widget.controller.activeProfile?.name ?? '—'}')
      ..writeln('最近错误：${widget.controller.error ?? '—'}')
      ..writeln('\n--- 最近日志 ---')
      ..write(widget.controller.logs.take(200).join('\n'));
    await file.writeAsString(report.toString(), flush: true);
    if (mounted) await _info('诊断信息已导出', file.path);
  }

  Future<void> _editPorts() async {
    final defaults = {
      'port': '17890',
      'socks-port': '17891',
      'mixed-port': '7897',
      'controller-port': '9090',
    };
    final fields = {
      for (final entry in defaults.entries)
        entry.key: TextEditingController(
          text: value.overrides[entry.key] ?? entry.value,
        ),
    };
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('端口设置'),
        content: SizedBox(
          width: 430,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: fields.entries
                .map(
                  (entry) => SizedBox(
                    width: 190,
                    child: TextField(
                      controller: entry.value,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: entry.key),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存并重载'),
          ),
        ],
      ),
    );
    if (save != true) {
      for (final field in fields.values) {
        field.dispose();
      }
      return;
    }
    final overrides = {...value.overrides};
    final used = <int>{};
    String? error;
    for (final entry in fields.entries) {
      final port = int.tryParse(entry.value.text.trim());
      if (port == null || port < 1 || port > 65535) {
        error = '${entry.key} 端口范围必须是 1–65535';
        break;
      }
      if (!used.add(port)) {
        error = '端口 $port 重复';
        break;
      }
      overrides[entry.key] = '$port';
    }
    for (final field in fields.values) {
      field.dispose();
    }
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    final previousMode = widget.network.mode;
    if (previousMode != DesktopNetworkMode.off) {
      _changeNetworkMode(DesktopNetworkMode.off);
      await _waitForNetworkMode(DesktopNetworkMode.off);
    }
    await _set(value.copyWith(overrides: overrides), restartVpn: false);
    if (previousMode != DesktopNetworkMode.off) {
      _changeNetworkMode(previousMode);
    }
  }

  Future<void> _editStartupScript() async {
    final editor = TextEditingController(text: value.meta['startup.script']);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('启动脚本'),
        content: SizedBox(
          width: 540,
          child: TextField(
            controller: editor,
            minLines: 8,
            maxLines: 14,
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
    final script = editor.text;
    editor.dispose();
    if (save == true) await _meta('startup.script', script);
  }

  Future<void> _showThemeSettings() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('主题设置'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'light'),
            child: const Text('浅色'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'dark'),
            child: const Text('深色'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'system'),
            child: const Text('跟随系统'),
          ),
        ],
      ),
    );
    if (selected != null) await _set(value.copyWith(darkMode: selected));
  }

  Future<void> _showMiscSettings() async {
    var animations = value.animations;
    var notifications = value.notifications;
    var closeToTray = value.closeToTray;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('杂项设置'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('界面动画'),
                  value: animations,
                  onChanged: (next) => setDialogState(() => animations = next),
                ),
                SwitchListTile(
                  title: const Text('桌面通知'),
                  value: notifications,
                  onChanged: (next) =>
                      setDialogState(() => notifications = next),
                ),
                SwitchListTile(
                  title: const Text('关闭时驻留托盘'),
                  value: closeToTray,
                  onChanged: (next) => setDialogState(() => closeToTray = next),
                ),
              ],
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
      ),
    );
    if (save == true) {
      await _set(
        value.copyWith(
          animations: animations,
          notifications: notifications,
          closeToTray: closeToTray,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.network,
    builder: (context, _) => ListView(
      key: const ValueKey('reference-settings-scroll'),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildLeftColumn()),
            const SizedBox(width: 12),
            Expanded(child: _buildRightColumn()),
          ],
        ),
      ],
    ),
  );

  Widget _buildLeftColumn() => Column(
    children: [
      _SettingsPanel(
        title: '系统设置',
        children: [
          _SettingSwitch(
            label: '虚拟网卡模式',
            value: widget.network.mode == DesktopNetworkMode.tun,
            highlighted: widget.network.mode == DesktopNetworkMode.tun,
            leading: Icons.pause_circle_outline,
            actions: const [
              _RowAction(Icons.settings, color: Color(0xFF9A9CA6)),
              _RowAction(Icons.warning_rounded, color: Color(0xFF9A6A32)),
              _RowAction(Icons.build, color: Color(0xFF235D9E)),
            ],
            onChanged: (enabled) => _changeNetworkMode(
              enabled ? DesktopNetworkMode.tun : DesktopNetworkMode.off,
            ),
          ),
          _SettingSwitch(
            label: '系统代理',
            value: widget.network.mode == DesktopNetworkMode.systemProxy,
            highlighted: widget.network.mode == DesktopNetworkMode.systemProxy,
            leading: Icons.play_circle_outline,
            leadingColor: const Color(0xFF28D76E),
            actions: const [
              _RowAction(Icons.settings, color: Color(0xFFBFC1C8)),
            ],
            onChanged: (enabled) async {
              await _set(
                value.copyWith(systemProxy: enabled),
                restartVpn: false,
              );
              _changeNetworkMode(
                enabled
                    ? DesktopNetworkMode.systemProxy
                    : DesktopNetworkMode.off,
              );
            },
          ),
          _SettingSwitch(
            label: '开机自启',
            value: value.launchAtStartup,
            onChanged: (next) => _set(value.copyWith(launchAtStartup: next)),
          ),
          _SettingSwitch(
            label: '静默启动',
            value: value.silentStart,
            info: true,
            onChanged: (next) => _set(value.copyWith(silentStart: next)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _SettingsPanel(
        title: 'Clash 设置',
        children: [
          _SettingSwitch(
            label: '局域网连接',
            value: value.allowLan,
            suffixIcon: Icons.account_tree,
            onChanged: (next) => _set(value.copyWith(allowLan: next)),
          ),
          _SettingSwitch(
            label: 'DNS 覆写',
            value: value.dnsEnabled,
            suffixIcon: Icons.settings,
            onChanged: (next) => _set(value.copyWith(dnsEnabled: next)),
          ),
          _SettingSwitch(
            label: 'IPv6',
            value: value.ipv6,
            onChanged: (next) => _set(value.copyWith(ipv6: next)),
          ),
          _SettingSwitch(
            label: '统一延迟',
            value: value.unifiedDelay,
            info: true,
            onChanged: (next) => _set(value.copyWith(unifiedDelay: next)),
          ),
          _SettingChoice(
            label: '日志等级',
            info: true,
            value: value.logLevel,
            values: const {
              'debug': 'Debug',
              'info': 'Info',
              'warning': 'Warn',
              'error': 'Error',
            },
            onChanged: (next) => _set(value.copyWith(logLevel: next)),
          ),
          _SettingValue(
            label: '端口设置',
            value: value.overrides['mixed-port'] ?? '7897',
            onTap: _editPorts,
          ),
          _SettingLink(
            label: '外部控制',
            suffixIcon: Icons.settings,
            onTap: () => _copyText('外部控制地址', _controllerAddress),
          ),
          _SettingLink(label: '网页界面', onTap: _openWebUi),
          _SettingLink(
            label: 'Clash 内核',
            suffixIcon: Icons.settings,
            trailingText: _coreVersionLabel,
            showChevron: false,
            onTap: () => _info(
              'Clash 内核',
              widget.controller.version.isEmpty
                  ? 'Mihomo 尚未启动'
                  : _coreVersionLabel,
            ),
          ),
          _SettingLink(label: '更新 GeoData', onTap: _updateGeoData),
          _SettingLink(
            label: '流量隧道管理',
            onTap: () => widget.onNavigate(DesktopSection.connections),
          ),
        ],
      ),
    ],
  );

  Widget _buildRightColumn() => Column(
    children: [
      _SettingsPanel(
        title: 'RS 基础设置',
        children: [
          _SettingChoice(
            label: '语言设置',
            value: value.language,
            values: const {'zh-CN': '中文', 'en-US': 'English'},
            onChanged: (next) => _set(value.copyWith(language: next)),
          ),
          _ThemeSetting(
            value: value.darkMode,
            onChanged: (next) => _set(value.copyWith(darkMode: next)),
          ),
          _SettingChoice(
            label: '托盘点击事件',
            value: value.meta['tray.click'] ?? 'show',
            values: const {'show': '显示主窗口', 'quit': '退出应用'},
            onChanged: (next) => _meta('tray.click', next),
          ),
          _SettingChoice(
            label: '复制环境变量类型',
            suffixIcon: Icons.copy_outlined,
            value: value.meta['env.shell'] ?? 'bash',
            values: const {
              'bash': 'Bash',
              'zsh': 'Zsh',
              'powershell': 'PowerShell',
            },
            onChanged: (next) => _meta('env.shell', next),
          ),
          _SettingChoice(
            label: '启动页面',
            value: value.homeSection,
            values: const {'home': '首 页', 'proxy': '代理', 'subscriptions': '订阅'},
            onChanged: (next) => _set(value.copyWith(homeSection: next)),
          ),
          _SettingLink(
            label: '启动脚本',
            blueLabel: '浏览',
            onTap: _editStartupScript,
          ),
          _SettingLink(label: '主题设置', onTap: _showThemeSettings),
          _SettingLink(
            label: '界面设置',
            onTap: () => widget.onNavigate(DesktopSection.home),
          ),
          _SettingLink(label: '杂项设置', onTap: _showMiscSettings),
          _SettingLink(
            label: '热键设置',
            onTap: () => _info('热键设置', '数字 1–8 切换主页面。'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _SettingsPanel(
        title: 'RS 高级设置',
        children: [
          _SettingLink(label: '备份设置', info: true, onTap: _backupSettings),
          _SettingLink(
            label: '当前配置',
            onTap: () => widget.onNavigate(DesktopSection.subscription),
          ),
          _SettingLink(
            label: '配置目录',
            info: true,
            onTap: () => _openDirectory(
              '配置目录',
              widget.controller.configurationDirectory,
            ),
          ),
          _SettingLink(
            label: '内核目录',
            onTap: () =>
                _openDirectory('内核目录', widget.controller.coreDirectory),
          ),
          _SettingLink(
            label: '日志目录',
            onTap: () => _openDirectory('日志目录', widget.controller.logDirectory),
          ),
          _SettingLink(label: '仅检查更新', onTap: _checkUpdate),
          _SettingLink(
            label: '开发者工具',
            onTap: () => DiagnosticsSheet.show(context, widget.controller),
          ),
          _SettingLink(
            label: '轻量模式设置',
            info: true,
            onTap: () async {
              await _set(value.copyWith(animations: !value.animations));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value.animations ? '轻量模式已关闭' : '轻量模式已启用'),
                  ),
                );
              }
            },
          ),
          _SettingLink(
            label: '退出',
            onTap: () async {
              await widget.onQuit?.call();
            },
          ),
          _SettingLink(
            label: '导出诊断信息',
            copyIcon: true,
            showChevron: false,
            onTap: _exportDiagnostics,
          ),
          _SettingLink(
            label: 'RS 版本',
            trailingText: 'v1.0.0',
            copyIcon: true,
            showChevron: false,
            onTap: () => _copyText('RS 版本', 'v1.0.0'),
          ),
        ],
      ),
    ],
  );
}

class _SettingsPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsPanel({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: DesktopColors.card,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      children: [
        SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .1,
                ),
              ),
            ),
          ),
        ),
        ...children,
      ],
    ),
  );
}

class _RowAction {
  final IconData icon;
  final Color color;
  const _RowAction(this.icon, {required this.color});
}

class _SettingSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final bool highlighted;
  final bool info;
  final IconData? leading;
  final Color? leadingColor;
  final IconData? suffixIcon;
  final List<_RowAction> actions;
  final ValueChanged<bool> onChanged;
  const _SettingSwitch({
    required this.label,
    required this.value,
    this.highlighted = false,
    this.info = false,
    this.leading,
    this.leadingColor,
    this.suffixIcon,
    this.actions = const [],
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => _SettingRow(
    highlighted: highlighted,
    leading: leading == null
        ? null
        : Icon(leading, size: 22, color: leadingColor ?? DesktopColors.muted),
    label: label,
    suffix: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (suffixIcon != null) ...[
          Icon(suffixIcon, size: 18, color: const Color(0xFFB5B7C0)),
          const SizedBox(width: 7),
        ],
        if (info) ...[
          const Icon(Icons.info, size: 15, color: Color(0xFF9A9CA6)),
          const SizedBox(width: 7),
        ],
        for (final action in actions) ...[
          Icon(action.icon, size: 18, color: action.color),
          const SizedBox(width: 12),
        ],
      ],
    ),
    trailing: Transform.scale(
      scale: .86,
      child: Switch(value: value, onChanged: onChanged),
    ),
  );
}

class _SettingChoice extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> values;
  final bool info;
  final IconData? suffixIcon;
  final ValueChanged<String> onChanged;
  const _SettingChoice({
    required this.label,
    required this.value,
    required this.values,
    this.info = false,
    this.suffixIcon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => _SettingRow(
    label: label,
    suffix: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (suffixIcon != null)
          Icon(suffixIcon, size: 16, color: const Color(0xFFB7B9C2)),
        if (info)
          const Padding(
            padding: EdgeInsets.only(left: 7),
            child: Icon(Icons.info, size: 15, color: Color(0xFF9A9CA6)),
          ),
      ],
    ),
    trailing: _ChoiceBox(value: value, values: values, onChanged: onChanged),
  );
}

class _ThemeSetting extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ThemeSetting({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _SettingRow(
    label: '主题模式',
    trailing: Container(
      height: 30,
      decoration: BoxDecoration(
        border: Border.all(color: DesktopColors.blue),
        borderRadius: BorderRadius.circular(5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeButton(
            label: '浅色',
            selected: value == 'light',
            onTap: () => onChanged('light'),
          ),
          _ThemeButton(
            label: '深色',
            selected: value == 'dark',
            onTap: () => onChanged('dark'),
          ),
          _ThemeButton(
            label: '系统',
            selected: value == 'system',
            onTap: () => onChanged('system'),
          ),
        ],
      ),
    ),
  );
}

class _ThemeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      width: 45,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? DesktopColors.blue : Colors.transparent,
        border: const Border(
          right: BorderSide(color: DesktopColors.blue, width: .6),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : DesktopColors.blue,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _ChoiceBox extends StatelessWidget {
  final String value;
  final Map<String, String> values;
  final ValueChanged<String> onChanged;
  const _ChoiceBox({
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 126,
    height: 38,
    padding: const EdgeInsets.only(left: 13, right: 6),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF565967)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: values.containsKey(value) ? value : values.keys.first,
        isExpanded: true,
        dropdownColor: DesktopColors.card,
        style: const TextStyle(fontSize: 14, color: DesktopColors.text),
        icon: const Icon(
          Icons.arrow_drop_down,
          color: DesktopColors.text,
          size: 20,
        ),
        items: values.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    ),
  );
}

class _SettingValue extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _SettingValue({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: _SettingRow(
      label: label,
      trailing: Container(
        width: 100,
        height: 38,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF565967)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(value, style: const TextStyle(fontSize: 14)),
      ),
    ),
  );
}

class _SettingLink extends StatelessWidget {
  final String label;
  final String? blueLabel;
  final String? trailingText;
  final IconData? suffixIcon;
  final bool info;
  final bool copyIcon;
  final bool showChevron;
  final VoidCallback onTap;
  const _SettingLink({
    required this.label,
    this.blueLabel,
    this.trailingText,
    this.suffixIcon,
    this.info = false,
    this.copyIcon = false,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: _SettingRow(
      label: label,
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (suffixIcon != null)
            Icon(suffixIcon, size: 17, color: const Color(0xFFB7B9C2)),
          if (info) const Icon(Icons.info, size: 15, color: Color(0xFF9A9CA6)),
          if (copyIcon)
            const Icon(Icons.copy_outlined, size: 16, color: Color(0xFFB7B9C2)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (blueLabel != null)
            Text(
              blueLabel!,
              style: const TextStyle(fontSize: 14, color: DesktopColors.blue),
            ),
          if (trailingText != null)
            Text(trailingText!, style: const TextStyle(fontSize: 14)),
          if (showChevron)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.chevron_right,
                color: DesktopColors.text,
                size: 20,
              ),
            ),
        ],
      ),
    ),
  );
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  final Widget? leading;
  final Widget? suffix;
  final bool highlighted;
  const _SettingRow({
    required this.label,
    required this.trailing,
    this.leading,
    this.suffix,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.only(left: 17, right: 12),
    color: highlighted ? const Color(0xFF293C3D) : Colors.transparent,
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
                    color: DesktopColors.text,
                  ),
                ),
              ),
              if (suffix != null) ...[const SizedBox(width: 7), suffix!],
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    ),
  );
}
