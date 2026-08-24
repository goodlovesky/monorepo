import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/proxy_profile.dart';
import '../../services/proxy_app_controller.dart';
import '../../widgets/clash_widgets.dart';
import 'profile_create_page.dart';
import 'profile_edit_page.dart';

class ProfileListPage extends StatefulWidget {
  final ProxyAppController controller;
  const ProfileListPage({super.key, required this.controller});

  @override
  State<ProfileListPage> createState() => _ProfileListPageState();
}

class _ProfileListPageState extends State<ProfileListPage> {
  bool _refreshing = false;

  Future<void> _refreshAll() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      for (final profile in widget.controller.profiles) {
        if (profile.sourceType == 'url') {
          await widget.controller.refreshProfile(profile);
        }
      }
      if (mounted) _message('配置已更新');
    } catch (error) {
      if (mounted) _message('$error');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _create() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileCreatePage(controller: widget.controller),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _edit(ProxyProfile profile) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProfileEditPage(controller: widget.controller, profile: profile),
      ),
    );
    if (mounted) setState(() {});
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: ScreenshotAppBar(
        title: '配置',
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refreshAll,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 27),
          ),
          IconButton(onPressed: _create, icon: const Icon(Icons.add, size: 29)),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 3, 18, 32),
        itemCount: widget.controller.profiles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final profile = widget.controller.profiles[index];
          return _ProfileCard(
            profile: profile,
            onActivate: () => widget.controller.activateProfile(profile.id),
            onEdit: () => _edit(profile),
            onUpdate: () async {
              try {
                await widget.controller.refreshProfile(profile);
                if (mounted) _message('配置已更新');
              } catch (error) {
                if (mounted) _message('$error');
              }
            },
            onDelete: () async {
              try {
                await widget.controller.deleteProfile(profile.id);
              } catch (error) {
                if (mounted) _message('$error');
              }
            },
          );
        },
      ),
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  final ProxyProfile profile;
  final VoidCallback onActivate;
  final VoidCallback onEdit;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const _ProfileCard({
    required this.profile,
    required this.onActivate,
    required this.onEdit,
    required this.onUpdate,
    required this.onDelete,
  });

  String _relativeTime(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return '刚刚';
    if (difference.inHours < 1) return '${difference.inMinutes} 分钟前';
    if (difference.inDays < 1) return '${difference.inHours} 小时前';
    return '${difference.inDays} 天前';
  }

  @override
  Widget build(BuildContext context) {
    final used = profile.usedTrafficBytes;
    final total = profile.totalTrafficBytes;
    final progress = used != null && total != null && total > 0
        ? (used / total).clamp(0.0, 1.0)
        : null;
    return ClashCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      child: SizedBox(
        height: 85,
        child: Row(
          children: [
            InkWell(
              onTap: onActivate,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  profile.active
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 28,
                  color: profile.active ? AppColors.blue : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: const TextStyle(fontSize: 13, letterSpacing: 1),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        profile.sourceType == 'url'
                            ? 'URL'
                            : profile.sourceType.toUpperCase(),
                        style: const TextStyle(fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        _relativeTime(
                          profile.lastCheckedAt ?? profile.updatedAt,
                        ),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  if (used != null || total != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${used == null ? "—" : formatBytes(used)}/${total == null ? "—" : formatBytes(total)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ],
                  if (profile.expiresAt != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      '${profile.expiresAt!.year}-${profile.expiresAt!.month.toString().padLeft(2, '0')}-${profile.expiresAt!.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ],
                  if (progress != null) ...[
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      color: AppColors.blue,
                      backgroundColor: AppColors.divider,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 28),
              color: AppColors.cardElevated,
              onSelected: (value) {
                if (value == 'activate') onActivate();
                if (value == 'update') onUpdate();
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                if (!profile.active)
                  const PopupMenuItem(value: 'activate', child: Text('启用')),
                if (profile.sourceType == 'url')
                  const PopupMenuItem(value: 'update', child: Text('更新')),
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
