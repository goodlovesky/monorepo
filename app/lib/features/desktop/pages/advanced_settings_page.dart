import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../platform/desktop/window_position_service.dart';
import '../../../services/proxy_app_controller.dart';
import '../desktop_app.dart' show DesktopColors;
import '../diagnostics_sheet.dart';
import 'widgets.dart';

/// 高级设置页：备份、目录、更新、诊断与内核维护。
class AdvancedAdvancedSettingsPage extends StatelessWidget {
  final ProxyAppController controller;
  final Future<void> Function()? onQuit;
  const AdvancedAdvancedSettingsPage({
    super.key,
    required this.controller,
    this.onQuit,
  });

  Future<void> _message(BuildContext context, String title, String body) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SelectableText(body),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
      );

  Future<void> _openDirectory(BuildContext context, String path) async {
    await Directory(path).create(recursive: true);
    final result = Platform.isWindows
        ? await Process.run('explorer.exe', [path])
        : await Process.run('open', [path]);
    if (result.exitCode != 0 && context.mounted) {
      await _message(context, '打开目录失败', '${result.stderr}');
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    final file = await controller.exportBackup();
    if (context.mounted) await _message(context, '备份已导出', file.path);
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = selected?.path;
    if (path == null) return;
    if (!context.mounted) return;
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
    await controller.restoreBackup(path, replace: mode == 'replace');
    if (context.mounted) await _message(context, '恢复完成', path);
  }

  Future<void> _importGeo(BuildContext context) async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['dat', 'db', 'mmdb'],
    );
    final path = selected?.path;
    if (path == null) return;
    final kind = path.toLowerCase().contains('site') ? 'geosite' : 'geoip';
    await controller.importGeoFile(kind, path);
    if (context.mounted) await _message(context, 'GeoData 已更新', path);
  }

  @override
  Widget build(BuildContext context) {
    final config = controller.activeProfile?.localYamlPath ?? '尚未激活配置';
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        RsCard(
          title: 'RS 高级设置',
          icon: Icons.build_outlined,
          accent: const Color(0xFF168BFA),
          child: Column(
            children: [
              _Row(label: '导出备份', onTap: () => _exportBackup(context)),
              const RsDivider(),
              _Row(label: '恢复备份', onTap: () => _restoreBackup(context)),
              const RsDivider(),
              _Row(
                label: '当前配置',
                onTap: () => _message(context, '当前配置', config),
              ),
              const RsDivider(),
              for (final entry in {
                '配置目录': controller.configurationDirectory,
                '内核目录': controller.coreDirectory,
                '日志目录': controller.logDirectory,
              }.entries) ...[
                _Row(
                  label: entry.key,
                  onTap: () => _openDirectory(context, entry.value),
                ),
                const RsDivider(),
              ],
              _Row(
                label: '仅检查更新',
                onTap: () async {
                  final info = await controller.checkForUpdate();
                  if (context.mounted) {
                    await _message(
                      context,
                      '版本检查',
                      info.available
                          ? '发现 v${info.version}\n${info.url}'
                          : '当前已是最新版本 v${info.version}',
                    );
                  }
                },
              ),
              const RsDivider(),
              _Row(
                label: '开发者工具',
                onTap: () => DiagnosticsSheet.show(context, controller),
              ),
              const RsDivider(),
              _Row(
                label: '轻量模式设置',
                onTap: () => _message(context, '轻量模式', '关闭动画后可降低界面绘制开销。'),
              ),
              const RsDivider(),
              _Row(
                label: '重置窗口位置',
                onTap: () async {
                  final ok = await WindowPositionService.instance.recenter();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? '窗口已居中' : '当前平台未执行居中操作')),
                    );
                  }
                },
              ),
              const RsDivider(),
              _Row(
                label: '退出',
                onTap: () async {
                  if (onQuit != null) {
                    await onQuit!();
                    return;
                  }
                  try {
                    await const MethodChannel(
                      'com.proxyapp.app/desktop_lifecycle',
                    ).invokeMethod<void>('quit');
                  } on MissingPluginException {
                    await controller.stop();
                    await SystemNavigator.pop();
                  }
                },
              ),
              const RsDivider(),
              _Row(
                label: '导出诊断信息',
                onTap: () => DiagnosticsSheet.show(context, controller),
              ),
              const RsDivider(),
              const _Row(label: 'RS 版本', trailing: 'v1.0.0'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        RsCard(
          title: '外部控制 / 内核',
          icon: Icons.settings_input_component,
          accent: const Color(0xFFFFA20F),
          child: Column(
            children: [
              _Row(
                label: '外部控制',
                onTap: () => _message(
                  context,
                  '外部控制',
                  'http://127.0.0.1:${controller.controllerPort}',
                ),
              ),
              const RsDivider(),
              _Row(
                label: '网页界面',
                onTap: () => _message(
                  context,
                  '网页界面',
                  '控制端口：127.0.0.1:${controller.controllerPort}',
                ),
              ),
              const RsDivider(),
              const _Row(label: 'Clash 内核', trailing: 'mihomo'),
              const RsDivider(),
              _Row(label: '更新 GeoData', onTap: () => _importGeo(context)),
              const RsDivider(),
              _Row(
                label: '流量隧道管理',
                onTap: () => _message(
                  context,
                  '流量隧道管理',
                  '当前模式：${controller.proxyMode}\n活动连接：${controller.connections.length}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  const _Row({required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(color: DesktopColors.muted, fontSize: 11),
            )
          else if (onTap != null)
            const Icon(
              Icons.chevron_right,
              color: DesktopColors.muted,
              size: 18,
            ),
        ],
      ),
    ),
  );
}
