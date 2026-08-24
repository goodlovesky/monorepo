import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../platform/desktop/desktop_network_service.dart';
import '../../platform/desktop/window_position_service.dart';
import '../../services/proxy_app_controller.dart';
import '../../services/theme_controller.dart';
import 'pages/connections_page.dart';
import 'pages/home_page.dart';
import 'pages/logs_page.dart';
import 'pages/proxy_page.dart';
import 'pages/reference_settings_page.dart';
import 'pages/rules_page.dart';
import 'pages/subscription_page.dart';
import 'pages/test_page.dart';
import 'diagnostics_sheet.dart';
import 'notification_overlay.dart';

abstract final class DesktopColors {
  static const window = Color(0xFF1E1F26);
  static const sidebar = Color(0xFF2E303D);
  static const header = Color(0xFF2E303D);
  static const card = Color(0xFF272A36);
  static const cardSoft = Color(0xFF252936);
  static const selected = Color(0xFF2B4D81);
  static const blue = Color(0xFF0B84FF);
  static const green = Color(0xFF2AD364);
  static const orange = Color(0xFFFFA20F);
  static const text = Color(0xFFF7F7FA);
  static const muted = Color(0xFF9699A6);
  static const border = Color(0xFF3D404C);
}

/// Clash RS desktop uses a dense, system-sans desktop scale.
ThemeData buildDesktopTheme({
  Brightness brightness = Brightness.dark,
  Color primary = DesktopColors.blue,
}) {
  final dark = brightness == Brightness.dark;
  if (dark && primary == DesktopColors.blue) {
    return _buildReferenceDesktopTheme();
  }
  final background = dark ? DesktopColors.window : const Color(0xFFF4F6FA);
  final surface = dark ? DesktopColors.card : Colors.white;
  final text = dark ? DesktopColors.text : const Color(0xFF20232D);
  final muted = dark ? DesktopColors.muted : const Color(0xFF687080);
  final border = dark ? DesktopColors.border : const Color(0xFFD9DEE8);
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
    primary: primary,
    surface: surface,
  );
  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    dividerColor: border,
    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      bodyLarge: TextStyle(fontSize: 13, color: text),
      bodyMedium: TextStyle(fontSize: 12, color: text),
      bodySmall: TextStyle(fontSize: 11, color: muted),
      labelLarge: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: dark ? DesktopColors.cardSoft : const Color(0xFFF8F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: BorderSide(color: border),
      ),
    ),
    switchTheme: SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : const Color(0xFFB6B8C0),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? primary
            : const Color(0xFF474A56),
      ),
    ),
  );
}

ThemeData _buildReferenceDesktopTheme() {
  const scheme = ColorScheme.dark(
    primary: DesktopColors.blue,
    surface: DesktopColors.card,
    onSurface: DesktopColors.text,
  );
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: DesktopColors.window,
    canvasColor: DesktopColors.window,
    dividerColor: DesktopColors.border,
    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 13),
      bodyMedium: TextStyle(fontSize: 12),
      bodySmall: TextStyle(fontSize: 11, color: DesktopColors.muted),
      labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: DesktopColors.cardSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: DesktopColors.border),
      ),
    ),
    switchTheme: SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : const Color(0xFFB6B8C0),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? DesktopColors.blue
            : const Color(0xFF474A56),
      ),
    ),
  );
}

enum DesktopSection {
  home('首页', Icons.home_rounded),
  proxy('代理', Icons.wifi_rounded),
  subscription('订阅', Icons.dns_rounded),
  connections('连接', Icons.language_rounded),
  rules('规则', Icons.call_split_rounded),
  logs('日志', Icons.segment_rounded),
  test('测试', Icons.lock_outline_rounded),
  settings('设置', Icons.settings_outlined);

  final String label;
  final IconData icon;
  const DesktopSection(this.label, this.icon);

  String localizedLabel(ThemeController strings) => switch (this) {
    DesktopSection.home => strings.tr('首页', 'Home'),
    DesktopSection.proxy => strings.tr('代理', 'Proxies'),
    DesktopSection.subscription => strings.tr('订阅', 'Subscriptions'),
    DesktopSection.connections => strings.tr('连接', 'Connections'),
    DesktopSection.rules => strings.tr('规则', 'Rules'),
    DesktopSection.logs => strings.tr('日志', 'Logs'),
    DesktopSection.test => strings.tr('测试', 'Tests'),
    DesktopSection.settings => strings.tr('设置', 'Settings'),
  };
}

class DesktopApp extends StatefulWidget {
  const DesktopApp({super.key});

  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends State<DesktopApp> with WidgetsBindingObserver {
  static const _lifecycle = MethodChannel('com.proxyapp.app/desktop_lifecycle');
  final controller = ProxyAppController();
  final network = createDesktopNetworkService();
  final window = WindowPositionService.instance;
  DesktopSection section = DesktopSection.home;
  bool changingNetwork = false;
  String _lastBannerError = '';
  DateTime? _lastStartedAt;
  bool _recoveringExternalTun = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.onExternalEngineLost = _recoverExternalTun;
    _lifecycle.setMethodCallHandler((call) async {
      if (call.method == 'prepareForQuit') {
        await network.restore();
        await controller.stop();
        return true;
      }
      if (call.method == 'systemDidWake' || call.method == 'networkAvailable') {
        await _handleNetworkResumed();
        return true;
      }
      if (call.method == 'systemWillSleep' ||
          call.method == 'networkUnavailable') {
        return true;
      }
      return false;
    });
    unawaited(_initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(network.restore());
      unawaited(controller.stop());
    }
  }

  Future<void> _initialize() async {
    await network.recover();
    await controller.initialize();
    if (!mounted) return;
    final initial = switch (controller.settings.homeSection) {
      'proxy' => DesktopSection.proxy,
      'subscriptions' => DesktopSection.subscription,
      'connections' => DesktopSection.connections,
      'rules' => DesktopSection.rules,
      'logs' => DesktopSection.logs,
      'test' => DesktopSection.test,
      'settings' => DesktopSection.settings,
      _ => DesktopSection.home,
    };
    setState(() => section = initial);
  }

  Future<void> _handleNetworkResumed() async {
    if (!mounted) return;
    if (network.mode == DesktopNetworkMode.tun) {
      if (await network.isHealthy(controllerPort: controller.controllerPort)) {
        if (!controller.isRunning) await controller.attachExternalEngine();
        await controller.refreshGroups();
        await controller.refreshIpInfo();
      } else {
        await _recoverExternalTun();
      }
      return;
    }
    if (controller.isRunning) {
      await controller.refreshGroups();
      await controller.refreshIpInfo();
    }
  }

  Future<void> _recoverExternalTun() async {
    if (_recoveringExternalTun || network.mode != DesktopNetworkMode.tun) {
      return;
    }
    _recoveringExternalTun = true;
    Object? lastFailure;
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
        try {
          final profile = controller.activeProfile;
          final supportPath = controller.supportPath;
          if (profile == null || supportPath == null) {
            throw StateError('没有可恢复的活动配置');
          }
          await network.restore();
          controller.detachExternalEngine();
          await network.enableTun(
            baseConfigPath: profile.localYamlPath,
            supportPath: supportPath,
            ipv6: controller.settings.ipv6,
            stackMode: controller.settings.stackMode,
            dnsHijack: controller.settings.dnsHijack,
            autoRoute: controller.settings.autoRoute,
            controllerPort: controller.controllerPort,
            merge: controller.settings.meta['extension.merge'] ?? '',
            script: controller.settings.meta['extension.script'] ?? '',
          );
          await controller.attachExternalEngine();
          controller.setIpInfoProxyPort(null);
          return;
        } catch (exception) {
          lastFailure = exception;
        }
      }
      controller.reportExternalRecoveryFailure(lastFailure ?? '未知错误');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('TUN 自动恢复失败：$lastFailure')));
      }
    } finally {
      _recoveringExternalTun = false;
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final result = Platform.isWindows
        ? await Process.run('cmd.exe', ['/c', 'start', '', url])
        : await Process.run('open', [url]);
    if (result.exitCode != 0 && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('打开链接失败：${result.stderr}')));
    }
  }

  /// 统一入口：原子地切换网络模式，三态互斥；失败回滚到调用前模式。
  Future<void> _switchNetworkMode(DesktopNetworkMode target) async {
    if (changingNetwork) return;
    changingNetwork = true;
    final previous = network.mode;
    try {
      if (target == previous) return;
      if (target == DesktopNetworkMode.off) {
        if (previous == DesktopNetworkMode.tun) {
          await network.disableTun();
          controller.detachExternalEngine();
        }
        await network.restore();
        if (controller.isRunning) await controller.stop();
        controller.setIpInfoProxyPort(null);
        return;
      }
      if (target == DesktopNetworkMode.systemProxy) {
        if (previous == DesktopNetworkMode.tun) {
          await network.disableTun();
          controller.detachExternalEngine();
        }
        if (!controller.isRunning) await controller.start();
        if (!controller.isRunning) {
          // controller.start() 内部把异常 catch 后只设了 error 字段,
          // 这里把它带出来,避免上层看到空 Bad state。
          final detail = controller.error ?? '未知原因';
          throw StateError('核心启动失败：$detail');
        }
        final httpPort =
            int.tryParse(controller.settings.overrides['port'] ?? '') ?? 17890;
        await network.enableSystemProxy(
          httpPort: httpPort,
          socksPort:
              int.tryParse(controller.settings.overrides['socks-port'] ?? '') ??
              17891,
        );
        controller.setIpInfoProxyPort(httpPort);
        return;
      }
      if (target == DesktopNetworkMode.tun) {
        if (previous == DesktopNetworkMode.systemProxy) {
          await network.restore();
        }
        if (controller.isRunning) await controller.stop();
        final profile = controller.activeProfile;
        final supportPath = controller.supportPath;
        if (profile == null || supportPath == null) {
          throw StateError('请先导入并激活配置');
        }
        await network.enableTun(
          baseConfigPath: profile.localYamlPath,
          supportPath: supportPath,
          ipv6: controller.settings.ipv6,
          stackMode: controller.settings.stackMode,
          dnsHijack: controller.settings.dnsHijack,
          autoRoute: controller.settings.autoRoute,
          controllerPort: controller.controllerPort,
          merge: controller.settings.meta['extension.merge'] ?? '',
          script: controller.settings.meta['extension.script'] ?? '',
        );
        await controller.attachExternalEngine();
        controller.setIpInfoProxyPort(null);
        return;
      }
    } catch (error, stack) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '网络模式切换失败：$error\n'
              '详细日志：~/Library/Logs/ClashRS/network.log',
            ),
          ),
        );
      }
      // 把堆栈也写一份到 network.log,方便自用排查
      // ignore: avoid_print
      print('ClashRS.Network 切换失败: $error\n$stack');
      try {
        if (previous == DesktopNetworkMode.tun) {
          final profile = controller.activeProfile;
          final supportPath = controller.supportPath;
          if (profile != null && supportPath != null) {
            await network.restore();
            if (controller.isRunning) await controller.stop();
            await network.enableTun(
              baseConfigPath: profile.localYamlPath,
              supportPath: supportPath,
              ipv6: controller.settings.ipv6,
              stackMode: controller.settings.stackMode,
              dnsHijack: controller.settings.dnsHijack,
              autoRoute: controller.settings.autoRoute,
              controllerPort: controller.controllerPort,
              merge: controller.settings.meta['extension.merge'] ?? '',
              script: controller.settings.meta['extension.script'] ?? '',
            );
            await controller.attachExternalEngine();
            controller.setIpInfoProxyPort(null);
          }
        } else if (previous == DesktopNetworkMode.systemProxy) {
          await network.restore();
          if (!controller.isRunning) await controller.start();
          if (controller.isRunning) {
            await network.enableSystemProxy(
              httpPort:
                  int.tryParse(controller.settings.overrides['port'] ?? '') ??
                  17890,
              socksPort:
                  int.tryParse(
                    controller.settings.overrides['socks-port'] ?? '',
                  ) ??
                  17891,
            );
            controller.setIpInfoProxyPort(
              int.tryParse(controller.settings.overrides['port'] ?? '') ??
                  17890,
            );
          }
        } else {
          await network.restore();
          if (controller.isRunning) await controller.stop();
          controller.setIpInfoProxyPort(null);
        }
      } catch (rollbackError) {
        controller.logs.insert(
          0,
          '${DateTime.now().toIso8601String()} [INFO] 网络模式回滚失败：$rollbackError',
        );
        if (controller.logs.length > 1000) controller.logs.removeLast();
      }
    } finally {
      changingNetwork = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle.setMethodCallHandler(null);
    unawaited(network.restore());
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = switch (controller.settings.accentColor) {
      'green' => DesktopColors.green,
      'orange' => DesktopColors.orange,
      'purple' => const Color(0xFF8B5CF6),
      _ => DesktopColors.blue,
    };
    return Theme(
      data: buildDesktopTheme(
        brightness: Theme.of(context).brightness,
        primary: accent,
      ),
      child: CallbackShortcuts(
        bindings: {
          for (var i = 0; i < DesktopSection.values.length; i++)
            CharacterActivator('${i + 1}'): () {
              final values = DesktopSection.values;
              if (i < values.length) setState(() => section = values[i]);
            },
          CharacterActivator(','): () =>
              setState(() => section = DesktopSection.settings),
          CharacterActivator('h'): () =>
              setState(() => section = DesktopSection.home),
        },
        child: ListenableBuilder(
          listenable: Listenable.merge([controller, network as Listenable]),
          builder: (context, _) {
            // 状态变化时弹 banner：错误变化 / 启动成功
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final err = controller.error;
              if (controller.settings.notifications &&
                  err != null &&
                  err != _lastBannerError) {
                _lastBannerError = err;
                unawaited(
                  showNotificationBanner(
                    context,
                    title: '运行错误',
                    body: err,
                    accent: Colors.redAccent,
                  ),
                );
              } else if (err == null) {
                _lastBannerError = '';
              }
              if (controller.settings.notifications &&
                  controller.startedAt != null &&
                  _lastStartedAt != controller.startedAt) {
                _lastStartedAt = controller.startedAt;
                unawaited(
                  showNotificationBanner(
                    context,
                    title: '代理已启动',
                    body: '运行模式：${controller.proxyMode}',
                    accent: const Color(0xFF2AD364),
                  ),
                );
              }
            });
            return TickerMode(
              enabled: controller.settings.animations,
              child: Scaffold(
                body: Row(
                  children: [
                    DesktopSidebar(
                      selected: section,
                      controller: controller,
                      onSelected: (value) => setState(() => section = value),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          DesktopHeader(
                            title: section == DesktopSection.proxy
                                ? controller.themeController.tr(
                                    '代理组',
                                    'Proxy Groups',
                                  )
                                : section.localizedLabel(
                                    controller.themeController,
                                  ),
                            trailing: section == DesktopSection.subscription
                                ? SubscriptionHeaderActions(
                                    controller: controller,
                                  )
                                : section == DesktopSection.settings
                                ? SettingsHeaderActions(
                                    onHelp: () => DiagnosticsSheet.show(
                                      context,
                                      controller,
                                    ),
                                    onTelegram: () => unawaited(
                                      _openExternalUrl('https://t.me/clashrs'),
                                    ),
                                    onGitHub: () => unawaited(
                                      _openExternalUrl(
                                        'https://github.com/goodlovesky/monorepo',
                                      ),
                                    ),
                                  )
                                : null,
                            onHome: () =>
                                setState(() => section = DesktopSection.home),
                            onSettings: () => setState(
                              () => section = DesktopSection.settings,
                            ),
                            onDiagnostics: () =>
                                DiagnosticsSheet.show(context, controller),
                          ),
                          Expanded(
                            child: DesktopPageHost(
                              section: section,
                              controller: controller,
                              network: network,
                              onNavigate: (value) =>
                                  setState(() => section = value),
                              onNetworkModeChange: _switchNetworkMode,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class DesktopSidebar extends StatelessWidget {
  final DesktopSection selected;
  final ProxyAppController controller;
  final ValueChanged<DesktopSection> onSelected;

  const DesktopSidebar({
    super.key,
    required this.selected,
    required this.controller,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final foreground = light
        ? const Color(0xFF353A46)
        : const Color(0xFFCDCED4);
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: light ? const Color(0xFFF0F2F7) : DesktopColors.sidebar,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _CatMark(size: 30),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Clash RS',
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: light ? const Color(0xFF20232D) : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  for (final item in DesktopSection.values)
                    _SidebarItem(
                      item: item,
                      strings: controller.themeController,
                      selected: item == selected,
                      foreground: foreground,
                      onTap: () => onSelected(item),
                    ),
                ],
              ),
            ),
          ),
          _TrafficSparkline(
            up: controller.uploadSpeed,
            down: controller.downloadSpeed,
            memoryMb: controller.memoryMb,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final DesktopSection item;
  final ThemeController strings;
  final Color foreground;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.item,
    required this.strings,
    required this.foreground,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Material(
      color: selected
          ? (Theme.of(context).brightness == Brightness.dark
                ? DesktopColors.selected
                : Theme.of(context).colorScheme.primary)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 18),
              Icon(
                item.icon,
                size: 22,
                color: selected ? Colors.white : foreground,
              ),
              const SizedBox(width: 28),
              Text(
                item.localizedLabel(strings),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DesktopHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final VoidCallback onHome;
  final VoidCallback onSettings;
  final VoidCallback onDiagnostics;
  const DesktopHeader({
    super.key,
    required this.title,
    this.trailing,
    required this.onHome,
    required this.onSettings,
    required this.onDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final foreground = light ? const Color(0xFF20232D) : DesktopColors.text;
    return Container(
      height: 63,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: light ? const Color(0xFFF0F2F7) : DesktopColors.header,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            trailing!
          else ...[
            _HeaderIcon(
              tooltip: '首页',
              onPressed: onHome,
              icon: Icons.touch_app_outlined,
            ),
            _HeaderIcon(
              tooltip: '帮助',
              onPressed: onDiagnostics,
              icon: Icons.help_outline,
            ),
            _HeaderIcon(
              tooltip: '设置',
              onPressed: onSettings,
              icon: Icons.settings_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  const _HeaderIcon({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurface),
    visualDensity: VisualDensity.compact,
    splashRadius: 16,
  );
}

class SettingsHeaderActions extends StatelessWidget {
  final VoidCallback onHelp;
  final VoidCallback onTelegram;
  final VoidCallback onGitHub;
  const SettingsHeaderActions({
    super.key,
    required this.onHelp,
    required this.onTelegram,
    required this.onGitHub,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _HeaderIcon(tooltip: '帮助', onPressed: onHelp, icon: Icons.help_outline),
      _HeaderIcon(
        tooltip: 'Telegram',
        onPressed: onTelegram,
        icon: Icons.send_rounded,
      ),
      _HeaderIcon(
        tooltip: 'GitHub',
        onPressed: onGitHub,
        icon: Icons.code_rounded,
      ),
    ],
  );
}

/// 公共卡组件（保留向后兼容，新代码请用 RsCard）。
class DesktopCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;
  final Widget? trailing;
  const DesktopCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.accent = const Color(0xFF168BFA),
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: DesktopColors.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF303341)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 84,
          child: Row(
            children: [
              const SizedBox(width: 28),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              trailing ?? const SizedBox.shrink(),
              const SizedBox(width: 22),
            ],
          ),
        ),
        const Divider(height: 1),
        child,
      ],
    ),
  );
}

class DesktopPageHost extends StatelessWidget {
  final DesktopSection section;
  final ProxyAppController controller;
  final DesktopNetworkService network;
  final ValueChanged<DesktopSection> onNavigate;
  final ValueChanged<DesktopNetworkMode> onNetworkModeChange;
  const DesktopPageHost({
    super.key,
    required this.section,
    required this.controller,
    required this.network,
    required this.onNavigate,
    required this.onNetworkModeChange,
  });

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      DesktopSection.home => HomePage(
        controller: controller,
        network: network,
        onNavigate: onNavigate,
        onSettingsTap: () => onNavigate(DesktopSection.settings),
        onAdvancedSettingsTap: () => onNavigate(DesktopSection.settings),
        onNetworkModeChange: onNetworkModeChange,
      ),
      DesktopSection.proxy => ProxyPage(
        controller: controller,
        onNavigate: onNavigate,
      ),
      DesktopSection.subscription => SubscriptionPage(controller: controller),
      DesktopSection.connections => ConnectionsPage(controller: controller),
      DesktopSection.rules => RulesPage(controller: controller),
      DesktopSection.logs => LogsPage(controller: controller),
      DesktopSection.test => TestPage(controller: controller),
      DesktopSection.settings => _SettingsHostPage(
        controller: controller,
        network: network,
        onNavigate: onNavigate,
        onNetworkModeChange: onNetworkModeChange,
      ),
    };
  }
}

class _SettingsHostPage extends StatefulWidget {
  final ProxyAppController controller;
  final DesktopNetworkService network;
  final ValueChanged<DesktopSection> onNavigate;
  final ValueChanged<DesktopNetworkMode> onNetworkModeChange;
  const _SettingsHostPage({
    required this.controller,
    required this.network,
    required this.onNavigate,
    required this.onNetworkModeChange,
  });

  @override
  State<_SettingsHostPage> createState() => _SettingsHostPageState();
}

class _SettingsHostPageState extends State<_SettingsHostPage> {
  Future<void> _quit() async {
    await widget.network.restore();
    await widget.controller.stop();
    try {
      await const MethodChannel('com.proxyapp.app/desktop_lifecycle')
          .invokeMethod<void>('quit');
    } on MissingPluginException {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) => ReferenceSettingsPage(
    controller: widget.controller,
    network: widget.network,
    onNavigate: widget.onNavigate,
    onNetworkModeChange: widget.onNetworkModeChange,
    onQuit: _quit,
  );
}

class SubscriptionCard extends StatelessWidget {
  final ProxyAppController controller;
  const SubscriptionCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final profile = controller.activeProfile;
    final used = profile?.usedTrafficBytes ?? 0;
    final total = profile?.totalTrafficBytes ?? 0;
    final ratio = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    return DesktopCard(
      title: profile?.name ?? '尚未导入订阅',
      icon: Icons.cloud_upload_outlined,
      trailing: OutlinedButton.icon(
        onPressed: profile == null
            ? null
            : () => controller.refreshProfile(profile),
        icon: const Icon(Icons.sync, size: 18),
        label: const Text('更新'),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoLine(
              icon: Icons.dns_outlined,
              text: profile?.source ?? '从订阅页面添加 URL 或配置文件',
              color: DesktopColors.blue,
            ),
            const SizedBox(height: 22),
            _InfoLine(
              icon: Icons.history,
              text: '更新时间：${_dateTime(profile?.updatedAt)}',
            ),
            const SizedBox(height: 22),
            _InfoLine(
              icon: Icons.speed,
              text:
                  '已使用 / 总量：${_bytes(used)} / ${total > 0 ? _bytes(total) : '未提供'}',
            ),
            const SizedBox(height: 20),
            Text('${(ratio * 100).round()}%'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 12,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: const Color(0xFF253A59),
              color: DesktopColors.blue,
            ),
          ],
        ),
      ),
    );
  }
}

class CurrentNodeCard extends StatelessWidget {
  final ProxyAppController controller;
  final VoidCallback onOpen;
  const CurrentNodeCard({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final group = controller.groups[controller.selectedGroup];
    final node = group?.now.isNotEmpty == true ? group!.now : '尚未选择节点';
    final delay = controller.delays[node];
    final type = group?.nodeTypes[node] ?? 'Proxy';
    return DesktopCard(
      title: '当前节点',
      icon: Icons.signal_cellular_alt_rounded,
      accent: DesktopColors.green,
      trailing: OutlinedButton.icon(
        onPressed: onOpen,
        icon: const Text('代理'),
        label: const Icon(Icons.chevron_right),
      ),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF243044),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DesktopColors.selected),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(node, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 8,
                          children: [
                            Text(type),
                            const _Pill(
                              text: '全局模式',
                              color: DesktopColors.blue,
                            ),
                            const _Pill(text: 'UDP'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _DelayBadge(delay: delay),
                ],
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: controller.selectedGroup,
              decoration: const InputDecoration(labelText: '代理组'),
              items: controller.groups.values
                  .where((item) => item.all.isNotEmpty)
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.name,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) controller.chooseGroup(value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: group?.all.contains(node) == true ? node : null,
              decoration: const InputDecoration(labelText: '节点'),
              items: (group?.all ?? const [])
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) controller.chooseNode(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class NetworkCard extends StatelessWidget {
  final ProxyAppController controller;
  final DesktopNetworkService network;
  final bool busy;
  final ValueChanged<bool> onSystemProxy;
  final VoidCallback onTun;
  const NetworkCard({
    super.key,
    required this.controller,
    required this.network,
    required this.busy,
    required this.onSystemProxy,
    required this.onTun,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = network.mode == DesktopNetworkMode.systemProxy;
    final tunEnabled = network.mode == DesktopNetworkMode.tun;
    return DesktopCard(
      title: '网络设置',
      icon: Icons.dns_outlined,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    icon: Icons.laptop_mac,
                    text: '系统代理',
                    selected: enabled,
                    onTap: busy ? null : () => onSystemProxy(true),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ModeButton(
                    icon: Icons.manage_search,
                    text: '虚拟网卡模式',
                    selected: tunEnabled,
                    onTap: busy ? null : onTun,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: DesktopColors.blue),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    controller.isRunning
                        ? Icons.play_circle_outline
                        : Icons.stop_circle_outlined,
                    color: controller.isRunning
                        ? DesktopColors.green
                        : DesktopColors.muted,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      enabled
                          ? '系统代理已启用，应用将通过当前节点访问网络'
                          : tunEnabled
                          ? '虚拟网卡已启用，系统流量正在全局接管'
                          : '开启后自动配置当前网络服务',
                      style: const TextStyle(color: DesktopColors.muted),
                    ),
                  ),
                  if (busy)
                    const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch(
                      value: enabled || tunEnabled,
                      onChanged: (value) =>
                          tunEnabled ? onTun() : onSystemProxy(value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProxyModeCard extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const ProxyModeCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DesktopCard(
    title: '代理模式',
    icon: Icons.router_outlined,
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Row(
            children: [
              for (final item in const ['规则', '全局', '直连']) ...[
                Expanded(
                  child: _ModeButton(
                    icon: item == '规则'
                        ? Icons.multiple_stop
                        : item == '全局'
                        ? Icons.language
                        : Icons.directions,
                    text: item,
                    selected: item == value,
                    onTap: () => onChanged(item),
                  ),
                ),
                if (item != '直连') const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              border: Border.all(color: DesktopColors.blue),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value == '全局'
                  ? '所有流量均通过代理服务器，适用于需要全局访问的场景'
                  : value == '规则'
                  ? '按照当前配置中的规则自动选择代理或直连'
                  : '所有流量直接连接，不经过代理服务器',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DesktopColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class TrafficCard extends StatelessWidget {
  final ProxyAppController controller;
  const TrafficCard({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => DesktopCard(
    title: '流量统计',
    icon: Icons.speed,
    accent: DesktopColors.orange,
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              label: '实时上传',
              value: '${_bytes(controller.uploadSpeed)}/s',
              color: DesktopColors.orange,
            ),
          ),
          Expanded(
            child: _Metric(
              label: '实时下载',
              value: '${_bytes(controller.downloadSpeed)}/s',
              color: DesktopColors.blue,
            ),
          ),
          Expanded(
            child: _Metric(
              label: '活动连接',
              value: '${controller.connections.length}',
              color: controller.isRunning
                  ? DesktopColors.green
                  : DesktopColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class DesktopProxyPage extends StatelessWidget {
  final ProxyAppController controller;
  const DesktopProxyPage({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final groups = controller.groups.values
        .where((item) => item.all.isNotEmpty)
        .toList();
    final group = controller.groups[controller.selectedGroup];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  children: groups
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.name),
                          selected: item.name == controller.selectedGroup,
                          onSelected: (_) => controller.chooseGroup(item.name),
                        ),
                      )
                      .toList(),
                ),
              ),
              FilledButton.icon(
                onPressed: controller.checkingDelays
                    ? controller.cancelDelayChecks
                    : controller.checkAllDelays,
                icon: Icon(controller.checkingDelays ? Icons.stop : Icons.bolt),
                label: Text(controller.checkingDelays ? '取消测速' : '全部测速'),
              ),
            ],
          ),
        ),
        Expanded(
          child: group == null
              ? const _DesktopEmpty(icon: Icons.wifi_off, title: '启动代理后显示节点')
              : GridView.builder(
                  padding: const EdgeInsets.all(22),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 430,
                    mainAxisExtent: 112,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: group.all.length,
                  itemBuilder: (context, index) {
                    final node = group.all[index];
                    final selected = node == group.now;
                    return Material(
                      color: selected
                          ? DesktopColors.selected
                          : DesktopColors.card,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => controller.chooseNode(node),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Icon(
                                selected ? Icons.check_circle : Icons.public,
                                color: selected
                                    ? Colors.white
                                    : DesktopColors.blue,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      node,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      group.nodeTypes[node] ?? 'Proxy',
                                      style: const TextStyle(
                                        color: DesktopColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => controller.checkNodeDelay(node),
                                child: _DelayBadge(
                                  delay: controller.delays[node],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class DesktopSubscriptionPage extends StatelessWidget {
  final ProxyAppController controller;
  const DesktopSubscriptionPage({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(22),
    itemCount: controller.profiles.length,
    itemBuilder: (context, index) {
      final profile = controller.profiles[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DesktopCard(
          title: profile.name,
          icon: profile.active ? Icons.check_circle : Icons.cloud_outlined,
          accent: profile.active ? DesktopColors.green : DesktopColors.blue,
          trailing: Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => controller.refreshProfile(profile),
                child: const Text('更新'),
              ),
              FilledButton(
                onPressed: profile.active
                    ? null
                    : () => controller.activateProfile(profile.id),
                child: Text(profile.active ? '已激活' : '激活'),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    profile.source ?? profile.localYamlPath,
                    style: const TextStyle(color: DesktopColors.muted),
                  ),
                ),
                Text(_dateTime(profile.updatedAt)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class DesktopConnectionsPage extends StatefulWidget {
  final ProxyAppController controller;
  const DesktopConnectionsPage({super.key, required this.controller});
  @override
  State<DesktopConnectionsPage> createState() => _DesktopConnectionsPageState();
}

class _DesktopConnectionsPageState extends State<DesktopConnectionsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refreshRuntimeDetails());
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.controller.connections;
    if (items.isEmpty) {
      return const _DesktopEmpty(
        icon: Icons.language,
        title: '当前没有活动连接',
        subtitle: '代理运行后将显示来源、目标、命中规则与流量',
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text('${items.length} 个活动连接'),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: widget.controller.refreshRuntimeDetails,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: widget.controller.closeAllConnections,
                icon: const Icon(Icons.close),
                label: const Text('关闭全部'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final metadata = item['metadata'] as Map? ?? const {};
              final id = item['id']?.toString() ?? '';
              final host =
                  metadata['host']?.toString() ??
                  metadata['destinationIP']?.toString() ??
                  '未知目标';
              final chains = (item['chains'] as List?)?.join(' → ') ?? 'DIRECT';
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DesktopColors.card,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.language, color: DesktopColors.blue),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            host,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            chains,
                            style: const TextStyle(color: DesktopColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: id.isEmpty
                          ? null
                          : () => widget.controller.closeConnection(id),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DesktopRulesPage extends StatefulWidget {
  final ProxyAppController controller;
  const DesktopRulesPage({super.key, required this.controller});
  @override
  State<DesktopRulesPage> createState() => _DesktopRulesPageState();
}

class _DesktopRulesPageState extends State<DesktopRulesPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refreshRuntimeDetails());
  }

  @override
  Widget build(BuildContext context) {
    final rules = widget.controller.rules;
    if (rules.isEmpty) {
      return _DesktopEmpty(
        icon: Icons.call_split,
        title: widget.controller.isRunning ? '当前配置没有可显示规则' : '启动代理后读取规则',
        subtitle: '当前配置：${widget.controller.activeProfile?.name ?? '尚未配置'}',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(22),
      itemCount: rules.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (_, index) {
        final rule = rules[index];
        return ListTile(
          leading: const Icon(Icons.call_split, color: DesktopColors.blue),
          title: Text(
            rule['payload']?.toString() ?? rule['type']?.toString() ?? '规则',
          ),
          subtitle: Text(rule['type']?.toString() ?? ''),
          trailing: Text(
            rule['proxy']?.toString() ?? rule['adapter']?.toString() ?? '',
          ),
        );
      },
    );
  }
}

class DesktopLogsPage extends StatelessWidget {
  final ProxyAppController controller;
  const DesktopLogsPage({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => controller.logs.isEmpty
      ? const _DesktopEmpty(icon: Icons.segment, title: '暂无日志')
      : ListView.separated(
          padding: const EdgeInsets.all(22),
          itemCount: controller.logs.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (_, index) => SelectableText(
            controller.logs[index],
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.6,
            ),
          ),
        );
}

class DesktopTestPage extends StatefulWidget {
  final ProxyAppController controller;
  const DesktopTestPage({super.key, required this.controller});
  @override
  State<DesktopTestPage> createState() => _DesktopTestPageState();
}

class _DesktopTestPageState extends State<DesktopTestPage> {
  String result = '点击开始检查当前节点延迟与代理状态';
  bool busy = false;
  Future<void> run() async {
    setState(() {
      busy = true;
      result = '正在执行网络检查…';
    });
    await widget.controller.checkAllDelays();
    if (!mounted) return;
    setState(() {
      busy = false;
      result = widget.controller.delays.isEmpty
          ? '未获得延迟结果，请确认代理已经启动'
          : '完成：${widget.controller.delays.length} 个节点返回延迟';
    });
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 620,
      child: DesktopCard(
        title: '网络诊断',
        icon: Icons.health_and_safety_outlined,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy ? null : run,
                icon: const Icon(Icons.play_arrow),
                label: Text(busy ? '检查中' : '开始检查'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DesktopSettingsPage extends StatelessWidget {
  final ProxyAppController controller;
  const DesktopSettingsPage({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      DesktopCard(
        title: '网络',
        icon: Icons.dns_outlined,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              const _SettingLine(title: 'HTTP 端口', value: '17890'),
              const _SettingLine(title: 'SOCKS 端口', value: '17891'),
              const _SettingLine(title: '混合端口', value: '17892'),
              _SettingLine(
                title: '控制端口',
                value: '${controller.controllerPort}',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      DesktopCard(
        title: '应用',
        icon: Icons.tune,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              _SettingLine(
                title: '自动重启',
                value: controller.settings.autoRestart ? '已开启' : '已关闭',
              ),
              _SettingLine(
                title: '显示流量',
                value: controller.settings.showTraffic ? '已开启' : '已关闭',
              ),
              const _SettingLine(title: '关闭窗口', value: '驻留菜单栏'),
            ],
          ),
        ),
      ),
    ],
  );
}

class _SettingLine extends StatelessWidget {
  final String title;
  final String value;
  const _SettingLine({required this.title, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
        Text(value, style: const TextStyle(color: DesktopColors.muted)),
      ],
    ),
  );
}

class _DesktopEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _DesktopEmpty({required this.icon, required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: DesktopColors.blue),
        const SizedBox(height: 18),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: const TextStyle(color: DesktopColors.muted)),
        ],
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoLine({
    required this.icon,
    required this.text,
    this.color = DesktopColors.text,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 24),
      const SizedBox(width: 14),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 16, color: color),
        ),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color? color;
  const _Pill({required this.text, this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: color ?? DesktopColors.border),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );
}

class _DelayBadge extends StatelessWidget {
  final int? delay;
  const _DelayBadge({this.delay});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: delay == null ? DesktopColors.border : DesktopColors.green,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      delay == null
          ? '—'
          : delay! < 0
          ? '失败'
          : '$delay ms',
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
    ),
  );
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  const _ModeButton({
    required this.icon,
    required this.text,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? DesktopColors.blue : DesktopColors.cardSoft,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 62,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: DesktopColors.muted)),
      const SizedBox(height: 8),
      Text(
        value,
        style: TextStyle(
          fontSize: 24,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _TrafficSparkline extends StatelessWidget {
  final int up;
  final int down;
  final int memoryMb;
  const _TrafficSparkline({
    required this.up,
    required this.down,
    required this.memoryMb,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(
              Icons.arrow_upward,
              size: 14,
              color: DesktopColors.muted,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                _formatSpeed(up),
                style: const TextStyle(
                  color: DesktopColors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text(
              'B/s',
              style: TextStyle(fontSize: 13, color: DesktopColors.text),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(
              Icons.arrow_downward,
              size: 14,
              color: DesktopColors.muted,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                _formatSpeed(down),
                style: const TextStyle(
                  color: DesktopColors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text(
              'B/s',
              style: TextStyle(fontSize: 13, color: DesktopColors.text),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.memory, size: 14, color: DesktopColors.muted),
            const SizedBox(width: 3),
            const Text(
              '内存',
              style: TextStyle(fontSize: 13, color: DesktopColors.text),
            ),
            const Spacer(),
            Text(
              '$memoryMb MB',
              style: const TextStyle(fontSize: 13, color: DesktopColors.text),
            ),
          ],
        ),
      ],
    ),
  );
}

String _formatSpeed(int bytes) {
  if (bytes <= 0) return '0.00';
  if (bytes < 1024) return bytes.toStringAsFixed(2);
  if (bytes < 1024 * 1024) return (bytes / 1024).toStringAsFixed(2);
  return (bytes / 1024 / 1024).toStringAsFixed(2);
}

class _CatMark extends StatelessWidget {
  final double size;
  const _CatMark({required this.size});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _CatMarkPainter());
}

class _CatMarkPainter extends CustomPainter {
  const _CatMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = DesktopColors.text;
    final cutout = Paint()..color = DesktopColors.sidebar;
    final path = Path()
      ..moveTo(size.width * .10, size.height * .15)
      ..lineTo(size.width * .34, size.height * .28)
      ..quadraticBezierTo(
        size.width * .50,
        size.height * .22,
        size.width * .66,
        size.height * .28,
      )
      ..lineTo(size.width * .90, size.height * .15)
      ..lineTo(size.width * .86, size.height * .62)
      ..quadraticBezierTo(
        size.width * .77,
        size.height * .88,
        size.width * .50,
        size.height * .92,
      )
      ..quadraticBezierTo(
        size.width * .23,
        size.height * .88,
        size.width * .14,
        size.height * .62,
      )
      ..close();
    canvas.drawPath(path, white);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .35, size.height * .56),
        width: size.width * .15,
        height: size.height * .10,
      ),
      cutout,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .65, size.height * .56),
        width: size.width * .15,
        height: size.height * .10,
      ),
      cutout,
    );
    final nose = Path()
      ..moveTo(size.width * .43, size.height * .72)
      ..lineTo(size.width * .57, size.height * .72)
      ..lineTo(size.width * .50, size.height * .80)
      ..close();
    canvas.drawPath(nose, cutout);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _dateTime(DateTime? value) {
  if (value == null) return '尚未更新';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}

String _bytes(int value) {
  if (value >= 1 << 30) return '${(value / (1 << 30)).toStringAsFixed(2)} GB';
  if (value >= 1 << 20) return '${(value / (1 << 20)).toStringAsFixed(2)} MB';
  if (value >= 1 << 10) return '${(value / (1 << 10)).toStringAsFixed(2)} KB';
  return '$value B';
}
