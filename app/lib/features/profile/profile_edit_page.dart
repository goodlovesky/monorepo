import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/proxy_profile.dart';
import '../../services/profile_import_service.dart';
import '../../services/proxy_app_controller.dart';
import '../../widgets/clash_widgets.dart';

class ProfileEditPage extends StatefulWidget {
  final ProxyAppController controller;
  final ProxyProfile? profile;
  final String? initialUrl;
  final String? filePath;
  final String? qrValue;

  const ProfileEditPage({
    super.key,
    required this.controller,
    this.profile,
    this.initialUrl,
    this.filePath,
    this.qrValue,
  });

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  int? _interval;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile?.name ?? '新配置');
    _url = TextEditingController(
      text:
          widget.initialUrl ??
          (widget.profile?.sourceType == 'url' ? widget.profile?.source : '') ??
          '',
    );
    _interval = widget.profile?.autoUpdateIntervalMinutes;
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      ImportedProfile imported;
      if (widget.filePath != null) {
        imported = await widget.controller.importer.fromFile(widget.filePath!);
      } else if (widget.qrValue != null && _url.text.trim().isEmpty) {
        imported = widget.controller.importer.fromQr(widget.qrValue!);
      } else if (_url.text.trim().isNotEmpty) {
        imported = await widget.controller.importer.fromUrl(_url.text.trim());
      } else if (widget.profile != null) {
        imported = ImportedProfile(
          yaml: await File(widget.profile!.localYamlPath).readAsString(),
          sourceType: widget.profile!.sourceType,
          source: widget.profile!.source,
          usedTrafficBytes: widget.profile!.usedTrafficBytes,
          totalTrafficBytes: widget.profile!.totalTrafficBytes,
          expiresAt: widget.profile!.expiresAt,
        );
      } else {
        throw const ProfileImportException('请选择文件或填写订阅 URL');
      }
      await widget.controller.saveImported(
        existing: widget.profile,
        name: _name.text,
        imported: imported,
        autoUpdateIntervalMinutes: _interval,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      setState(() => _error = exception.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseInterval() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const <int, String>{
              0: '已禁用',
              60: '每小时',
              360: '每 6 小时',
              1440: '每天',
            }.entries)
              ListTile(
                title: Text(entry.value),
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => _interval = selected == 0 ? null : selected);
    }
  }

  String get _intervalLabel {
    if (_interval == null) return '已禁用';
    if (_interval == 60) return '每小时';
    if (_interval == 360) return '每 6 小时';
    if (_interval == 1440) return '每天';
    return '$_interval 分钟';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ScreenshotAppBar(
      title: '配置',
      actions: [
        IconButton(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 26),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 18, 40),
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 28),
            SizedBox(width: 18),
            Expanded(
              child: Text(
                '仅接受 Clash 配置文件(包含代理/规则)',
                style: TextStyle(fontSize: 13, letterSpacing: 1.1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 42),
        _EditRow(
          icon: Icons.label_outline,
          label: '名称',
          child: TextField(
            controller: _name,
            style: const TextStyle(fontSize: 15, letterSpacing: 1.1),
            decoration: const InputDecoration(
              border: UnderlineInputBorder(),
              suffixIcon: Icon(Icons.edit, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 34),
        _EditRow(
          icon: Icons.inbox_outlined,
          label: 'URL',
          child: TextField(
            controller: _url,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              hintText: '仅接受 http(s) 和 content 类型',
              hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
              border: UnderlineInputBorder(),
              suffixIcon: Icon(Icons.edit, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 34),
        _EditRow(
          icon: Icons.update,
          label: '自动更新',
          child: InkWell(
            onTap: _chooseInterval,
            child: InputDecorator(
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                suffixIcon: Icon(Icons.edit, color: Colors.white),
              ),
              child: Text(_intervalLabel, style: const TextStyle(fontSize: 15)),
            ),
          ),
        ),
        const SizedBox(height: 40),
        const _EditRow(
          icon: Icons.folder_outlined,
          label: '浏览文件',
          child: Text(
            '浏览配置文件和外部资源',
            style: TextStyle(fontSize: 14, letterSpacing: 1),
          ),
        ),
        if (widget.filePath != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 67),
            child: Text(
              widget.filePath!,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 28),
          Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80))),
        ],
      ],
    ),
  );
}

class _EditRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _EditRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(width: 48, child: Icon(icon, size: 28)),
      const SizedBox(width: 18),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, letterSpacing: 1.1),
            ),
            const SizedBox(height: 3),
            child,
          ],
        ),
      ),
    ],
  );
}
