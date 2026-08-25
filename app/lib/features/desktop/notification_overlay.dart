import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/proxy_app_controller.dart';
import 'desktop_app.dart' show DesktopColors;
import '../../l10n/rs_text.dart';

/// 桌面端通知 banner。
///
/// 监听 Listenable，错误/重要状态变化时从屏幕顶部滑入。
/// 用法：NotificationBannerOverlay(notifyListenable: controller)
class NotificationBannerOverlay extends StatefulWidget {
  final Listenable notifyListenable;
  final void Function(BuildContext context, String title, String body) onShow;
  final Duration duration;
  const NotificationBannerOverlay({
    super.key,
    required this.notifyListenable,
    required this.onShow,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<NotificationBannerOverlay> createState() =>
      _NotificationBannerOverlayState();
}

class _NotificationBannerOverlayState extends State<NotificationBannerOverlay> {
  String? _lastError;
  DateTime? _lastStartedAt;

  void _onNotify() {
    if (!mounted) return;
    final listenable = widget.notifyListenable;
    if (listenable is ProxyAppController) {
      // 错误变化：弹红色 banner
      if (listenable.error != null && listenable.error != _lastError) {
        _lastError = listenable.error;
        widget.onShow(context, context.rsText('运行异常'), listenable.error!);
        return;
      }
      // 启动成功
      final startedAt = listenable.startedAt;
      if (_lastStartedAt != null &&
          startedAt != null &&
          startedAt != _lastStartedAt) {
        widget.onShow(context, context.rsText('代理已启动'), context.rsText('Tun 模式运行中'));
      }
      _lastStartedAt = startedAt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.notifyListenable,
      builder: (context, _) {
        // 通过 post-frame 避免在 build 中触发 overlay
        WidgetsBinding.instance.addPostFrameCallback((_) => _onNotify());
        return const SizedBox.shrink();
      },
    );
  }
}

/// 显示一个临时 banner。
Future<void> showNotificationBanner(
  BuildContext context, {
  required String title,
  required String body,
  Color? accent,
  Duration duration = const Duration(seconds: 4),
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _BannerWidget(
      title: title,
      body: body,
      accent: accent ?? const Color(0xFFFFA20F),
      onDismiss: () => entry.remove(),
      duration: duration,
    ),
  );
  overlay.insert(entry);
}

/// 顶部 banner widget。
class _BannerWidget extends StatefulWidget {
  final String title;
  final String body;
  final Color accent;
  final VoidCallback onDismiss;
  final Duration duration;
  const _BannerWidget({
    required this.title,
    required this.body,
    required this.accent,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismiss();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 110;
    return Positioned(
      top: topPadding,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF292C39),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: widget.accent),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xCC000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: widget.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RsText(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        RsText(
                          widget.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: DesktopColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.rsText('关闭'),
                    onPressed: _dismiss,
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
