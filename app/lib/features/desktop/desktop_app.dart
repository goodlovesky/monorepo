import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../platform/desktop/desktop_network_service.dart';
import '../../platform/desktop/window_position_service.dart';
import '../../core/log/app_log.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/proxy_app_controller.dart';
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
import '../../l10n/rs_text.dart';

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

  String localizedLabel(AppLocalizations strings) => switch (this) {
    DesktopSection.home => strings.navHome,
    DesktopSection.proxy => strings.navProxies,
    DesktopSection.subscription => strings.navSubscriptions,
    DesktopSection.connections => strings.navConnections,
    DesktopSection.rules => strings.navRules,
    DesktopSection.logs => strings.navLogs,
    DesktopSection.test => strings.navTests,
    DesktopSection.settings => strings.navSettings,
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
            .showSnackBar(SnackBar(content: RsText('TUN 自动恢复失败：$lastFailure')));
      }
    } finally {
      _recoveringExternalTun = false;
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final result = Platform.isWindows
        ? await Process.run('cmd.exe', ['/c', 'start', '', url])
        : Platform.isLinux
        ? await Process.run('xdg-open', [url])
        : await Process.run('open', [url]);
    if (result.exitCode != 0 && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: RsText('打开链接失败：${result.stderr}')));
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
            content: RsText(
              '网络模式切换失败：$error\n'
              '详细日志：~/Library/Logs/ClashRS/network.log',
            ),
          ),
        );
      }
      // 把堆栈也写一份到 network.log,方便自用排查
      // ignore: avoid_print
      print(
        '${AppLog.pick('ClashRS.Network 切换失败', 'ClashRS.Network switch failed')}: $error\n$stack',
      );
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
            final strings = Localizations.of<AppLocalizations>(
              context,
              AppLocalizations,
            );
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
                    title: context.rsText('运行错误'),
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
                final modeLabel = _localizedProxyMode(context, controller.proxyMode);
                unawaited(
                  showNotificationBanner(
                    context,
                    title: context.rsText('代理已启动'),
                    body: '${context.rsText('运行模式')}：$modeLabel',
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
                                ? strings?.proxyGroups ?? '代理组'
                                : strings == null
                                ? section.label
                                : section.localizedLabel(strings),
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
    final strings = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
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
                  child: RsText(
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
                      strings: strings,
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
  final AppLocalizations? strings;
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
                strings == null ? item.label : item.localizedLabel(strings!),
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
              tooltip: context.rsText('首页'),
              onPressed: onHome,
              icon: Icons.touch_app_outlined,
            ),
            _HeaderIcon(
              tooltip: context.rsText('帮助'),
              onPressed: onDiagnostics,
              icon: Icons.help_outline,
            ),
            _HeaderIcon(
              tooltip: context.rsText('设置'),
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
      _HeaderIcon(
        tooltip: context.rsText('帮助'),
        onPressed: onHelp,
        icon: Icons.help_outline,
      ),
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
            const RsText(
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
            const RsText(
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
            const RsText(
              '内存',
              style: TextStyle(fontSize: 13, color: DesktopColors.text),
            ),
            const Spacer(),
            RsText(
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

/// 把 controller.proxyMode（'rule'/'global'/'direct'）翻译成本地化标签。
String _localizedProxyMode(BuildContext context, String mode) {
  final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
  if (l10n == null) return mode;
  return switch (mode) {
    'rule' => l10n.proxyModeRule,
    'global' => l10n.proxyModeGlobal,
    'direct' => l10n.proxyModeDirect,
    _ => mode,
  };
}
