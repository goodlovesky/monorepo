import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/proxy_profile.dart';
import '../../../services/proxy_app_controller.dart';
import '../../../services/refresh_diff.dart';
import '../desktop_app.dart' show DesktopColors;
import 'widgets.dart';
import '../../../l10n/rs_text.dart';

/// mac-1005 订阅页面。
class SubscriptionPage extends StatefulWidget {
  final ProxyAppController controller;
  const SubscriptionPage({super.key, required this.controller});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

/// 订阅页专用顶部工具组，与参考图的四个图标保持一致。
class SubscriptionHeaderActions extends StatelessWidget {
  final ProxyAppController controller;
  const SubscriptionHeaderActions({super.key, required this.controller});

  Future<void> _pasteImport(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim() ?? '';
    if (value.isEmpty) return;
    try {
      final imported = await controller.importer.fromUrl(value);
      await controller.saveImported(
        name: Uri.parse(value).host,
        imported: imported,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: RsText('$error')));
      }
    }
  }

  Future<void> _refreshAll(BuildContext context) async {
    try {
      for (final profile in controller.profiles) {
        if (profile.sourceType == 'url') {
          await controller.refreshProfile(profile);
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: RsText('$error')));
      }
    }
  }

  Future<void> _importFile(BuildContext context) async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['yaml', 'yml', 'txt'],
    );
    final path = result?.path;
    if (path == null) return;
    try {
      final imported = await controller.importer.fromFile(path);
      await controller.saveImported(
        name: path.split(Platform.pathSeparator).last,
        imported: imported,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: RsText('$error')));
      }
    }
  }

  Future<void> _refreshActive(BuildContext context) async {
    final profile = controller.activeProfile;
    if (profile == null || profile.sourceType != 'url') return;
    try {
      await controller.refreshProfile(profile);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: RsText('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _TopAction(
        tooltip: context.rsText('粘贴并导入'),
        icon: Icons.crop_square_rounded,
        onPressed: () => _pasteImport(context),
      ),
      _TopAction(
        tooltip: context.rsText('刷新全部订阅'),
        icon: Icons.refresh_rounded,
        onPressed: () => _refreshAll(context),
      ),
      _TopAction(
        tooltip: context.rsText('导入配置文件'),
        icon: Icons.description_outlined,
        onPressed: () => _importFile(context),
      ),
      _TopAction(
        tooltip: context.rsText('刷新当前订阅'),
        icon: Icons.local_fire_department,
        color: const Color(0xFF168BFA),
        onPressed: () => _refreshActive(context),
      ),
    ],
  );
}

class _TopAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _TopAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xFFF7F7FA),
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    icon: Icon(icon, size: 21, color: color),
    splashRadius: 16,
  );
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final url = TextEditingController();
  bool importing = false;

  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  Future<void> _importUrl() async {
    final value = url.text.trim();
    if (value.isEmpty) return;
    await _run(() async {
      final imported = await widget.controller.importer.fromUrl(value);
      await widget.controller.saveImported(
        name: Uri.parse(value).host,
        imported: imported,
      );
      url.clear();
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    url.text = data?.text?.trim() ?? '';
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => importing = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: RsText('$error')));
      }
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  Future<void> _rename(ProxyProfile profile) async {
    final field = TextEditingController(text: profile.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const RsText('重命名配置'),
        content: TextField(controller: field, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const RsText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const RsText('保存'),
          ),
        ],
      ),
    );
    field.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await widget.controller.renameProfile(profile.id, name);
    }
  }

  Future<void> _refreshProfile(ProxyProfile profile) async {
    await _run(() => widget.controller.refreshProfile(profile));
    if (!mounted) return;
    final diff = widget.controller.lastRefreshDiff(profile.id);
    if (diff != null) await _showRefreshDiff(profile.name, diff);
  }

  Future<void> _showRefreshDiff(String profileName, RefreshDiff diff) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: RsText('$profileName · 刷新差异'),
        content: SizedBox(
          width: 560,
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RsText(
                  diff.hasChanges ? diff.summary : '配置无变化',
                  style: TextStyle(
                    color: diff.hasChanges
                        ? const Color(0xFF168BFA)
                        : DesktopColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final line in diff.detailLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: RsText(line),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const RsText('完成'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditor(String title, String key, String hint) async {
    final editor = TextEditingController(
      text: widget.controller.settings.meta[key] ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: RsText(title),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: editor,
            minLines: 12,
            maxLines: 18,
            decoration: InputDecoration(hintText: context.rsText(hint)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const RsText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const RsText('保存'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final meta = {...widget.controller.settings.meta, key: editor.text};
      await widget.controller.updateSettings(
        widget.controller.settings.copyWith(meta: meta),
      );
    }
    editor.dispose();
  }

  Future<void> _createNew() async {
    final name = TextEditingController();
    final address = TextEditingController(text: url.text.trim());
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const RsText('新建订阅'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: InputDecoration(labelText: context.rsText('名称')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                decoration: InputDecoration(
                  labelText: context.rsText('订阅文件链接'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const RsText('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = address.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, (name.text.trim(), value));
              }
            },
            child: const RsText('新建'),
          ),
        ],
      ),
    );
    name.dispose();
    address.dispose();
    if (result == null) return;
    await _run(() async {
      final imported = await widget.controller.importer.fromUrl(result.$2);
      await widget.controller.saveImported(
        name: result.$1.isEmpty ? Uri.parse(result.$2).host : result.$1,
        imported: imported,
      );
      url.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: SizedBox(
              height: 34,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('subscription-url-field'),
                      controller: url,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _importUrl(),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: context.rsText('订阅文件链接'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        suffixIcon: IconButton(
                          tooltip: context.rsText('粘贴'),
                          onPressed: importing ? null : _paste,
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.content_paste_outlined,
                            size: 18,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1D1F27),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Color(0xFF555864),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Color(0xFF555864),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 66,
                    child: FilledButton(
                      onPressed: importing || url.text.trim().isEmpty
                          ? null
                          : _importUrl,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const RsText('导入', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 66,
                    child: FilledButton(
                      onPressed: importing ? null : _createNew,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: const Color(0xFF168BFA),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const RsText('新建', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 102,
            child: widget.controller.profiles.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: RsEmpty(icon: Icons.cloud_off, title: '暂无订阅'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.controller.profiles.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => SizedBox(
                      width: 242,
                      child: _ProfileCard(
                        profile: widget.controller.profiles[i],
                        onRename: () => _rename(widget.controller.profiles[i]),
                        onRefresh: () =>
                            _refreshProfile(widget.controller.profiles[i]),
                        onActivate: () => widget.controller.activateProfile(
                          widget.controller.profiles[i].id,
                        ),
                        onDelete: () => widget.controller.deleteProfile(
                          widget.controller.profiles[i].id,
                        ),
                      ),
                    ),
                  ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 12, 28, 12),
            child: Divider(height: 1, color: Color(0xFF30323C)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 80,
              child: Row(
                children: [
                  Expanded(
                    child: _ExtensionCard(
                      key: const Key('subscription-extension-merge'),
                      title: '全局扩展覆写配置',
                      badge: 'Merge',
                      onTap: () => _showEditor(
                        'Merge 扩展',
                        'extension.merge',
                        'prepend-rules:\n  - DOMAIN-SUFFIX,example.com,DIRECT',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ExtensionCard(
                      key: const Key('subscription-extension-script'),
                      title: '全局扩展脚本',
                      badge: 'Script',
                      icon: Icons.description,
                      onTap: () => _showEditor(
                        'Script 扩展',
                        'extension.script',
                        '// request/response transform',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final ProxyProfile profile;
  final VoidCallback onRename;
  final Future<void> Function() onRefresh;
  final VoidCallback onActivate;
  final VoidCallback onDelete;
  const _ProfileCard({
    required this.profile,
    required this.onRename,
    required this.onRefresh,
    required this.onActivate,
    required this.onDelete,
  });

  Future<void> _showContextMenu(
    BuildContext context,
    TapDownDetails details,
  ) async {
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        if (!profile.active)
          const PopupMenuItem(value: 'activate', child: RsText('激活')),
        const PopupMenuItem(value: 'rename', child: RsText('重命名')),
        const PopupMenuItem(value: 'delete', child: RsText('删除')),
      ],
    );
    switch (value) {
      case 'activate':
        onActivate();
      case 'rename':
        onRename();
      case 'delete':
        onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final used = profile.usedTrafficBytes ?? 0;
    final total = profile.totalTrafficBytes ?? 0;
    final ratio = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: profile.active ? null : onActivate,
      onDoubleTap: onRename,
      onSecondaryTapDown: (details) => _showContextMenu(context, details),
      child: Container(
        key: ValueKey('subscription-profile-${profile.id}'),
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 7),
        decoration: BoxDecoration(
          color: const Color(0xFF292C39),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: profile.active
                ? const Color(0xFF168BFA)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (profile.active)
              Positioned(
                left: -9,
                top: -8,
                bottom: -7,
                child: Container(
                  width: 3,
                  decoration: const BoxDecoration(
                    color: Color(0xFF168BFA),
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(8),
                    ),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 24,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.drag_indicator,
                        size: 20,
                        color: Color(0xFFF7F7FA),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: profile.active
                                ? const Color(0xFF168BFA)
                                : const Color(0xFFF7F7FA),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.rsText('刷新'),
                        onPressed: profile.sourceType == 'url'
                            ? onRefresh
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 26,
                          height: 26,
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sourceLabel(profile),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DesktopColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    RsText(
                      _relativeTime(profile.updatedAt),
                      style: const TextStyle(
                        color: DesktopColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: RsText(
                        '${_compactBytes(used)} / ${total > 0 ? _compactBytes(total) : '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DesktopColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    if (profile.expiresAt != null)
                      Text(
                        _date(profile.expiresAt!),
                        style: const TextStyle(
                          color: DesktopColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    backgroundColor: const Color(0xFF253A59),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF168BFA)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionCard extends StatelessWidget {
  final String title;
  final String badge;
  final IconData? icon;
  final VoidCallback onTap;
  const _ExtensionCard({
    super.key,
    required this.title,
    required this.badge,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF292C39),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: RsText(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF168BFA)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: RsText(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFF168BFA),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (icon != null)
              Icon(icon, size: 18, color: const Color(0xFF9B9DA9)),
          ],
        ),
      ),
    ),
  );
}

String _sourceLabel(ProxyProfile profile) {
  final source = profile.source ?? profile.localYamlPath;
  final uri = Uri.tryParse(source);
  if (uri != null && uri.host.isNotEmpty) return uri.host;
  return source.split(Platform.pathSeparator).last;
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.isNegative || difference.inMinutes < 1) return '刚刚';
  if (difference.inHours < 1) return '${difference.inMinutes} 分钟前';
  if (difference.inDays < 1) return '${difference.inHours} 小时前';
  return '${difference.inDays} 天前';
}

String _compactBytes(int value) {
  const kb = 1 << 10;
  const mb = 1 << 20;
  const gb = 1 << 30;
  if (value >= gb) {
    final amount = value / gb;
    return '${amount == amount.roundToDouble() ? amount.toInt() : amount.toStringAsFixed(2)}GB';
  }
  if (value >= mb) return '${(value / mb).toStringAsFixed(2)}MB';
  if (value >= kb) return '${(value / kb).toStringAsFixed(2)}KB';
  return '${value.toStringAsFixed(2)}B';
}

String _date(DateTime v) =>
    '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
