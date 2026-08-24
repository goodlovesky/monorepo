import 'package:app/features/desktop/desktop_app.dart';
import 'package:app/features/desktop/pages/reference_settings_page.dart';
import 'package:app/platform/desktop/desktop_network_service.dart';
import 'package:app/services/proxy_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SettingsNetwork extends ChangeNotifier implements DesktopNetworkService {
  @override
  Future<bool> isHealthy({int controllerPort = 9090}) async => true;
  @override
  String? lastError;
  @override
  DesktopNetworkMode mode = DesktopNetworkMode.off;
  @override
  Future<void> disableTun() async => _set(DesktopNetworkMode.off);
  @override
  Future<void> enableSystemProxy({
    int httpPort = 17890,
    int socksPort = 17891,
  }) async => _set(DesktopNetworkMode.systemProxy);
  @override
  Future<void> enableTun({
    required String baseConfigPath,
    required String supportPath,
    bool ipv6 = false,
    String stackMode = 'system',
    bool dnsHijack = true,
    bool autoRoute = true,
    int controllerPort = 9090,
    String merge = '',
    String script = '',
  }) async => _set(DesktopNetworkMode.tun);
  @override
  Future<void> recover() async {}
  @override
  Future<void> restore() async => _set(DesktopNetworkMode.off);

  void _set(DesktopNetworkMode next) {
    mode = next;
    notifyListeners();
  }
}

void main() {
  testWidgets('settings page matches reference two-column geometry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(760, 692));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ProxyAppController();
    final network = _SettingsNetwork();
    DesktopSection? navigated;
    addTearDown(controller.dispose);
    addTearDown(network.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildDesktopTheme(),
        home: RepaintBoundary(
          key: const Key('settings-reference-frame'),
          child: Scaffold(
            body: Column(
              children: [
                DesktopHeader(
                  title: '设置',
                  trailing: SettingsHeaderActions(
                    onHelp: () {},
                    onTelegram: () {},
                    onGitHub: () {},
                  ),
                  onHome: () {},
                  onSettings: () {},
                  onDiagnostics: () {},
                ),
                Expanded(
                  child: ReferenceSettingsPage(
                    controller: controller,
                    network: network,
                    onNavigate: (section) => navigated = section,
                    onNetworkModeChange: network._set,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final system = tester.getRect(find.text('系统设置'));
    final rs = tester.getRect(find.text('RS 基础设置'));
    expect(system.left, 39);
    expect(rs.left, 403);
    expect(system.top, 90.5);
    expect(rs.top, 90.5);
    expect(find.text('基础设置'), findsNothing);
    expect(find.text('高级设置'), findsNothing);
    expect(find.text('浏览'), findsOneWidget);
    expect(find.text('RS 高级设置'), findsOneWidget);
    expect(find.text('备份设置'), findsOneWidget);
    expect(find.text('当前配置'), findsOneWidget);
    expect(find.text('开发者工具'), findsOneWidget);
    expect(find.text('轻量模式设置'), findsOneWidget);
    expect(find.text('导出诊断信息'), findsOneWidget);
    expect(find.text('RS 版本'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text('外部控制'), findsOneWidget);
    expect(find.text('更新 GeoData'), findsOneWidget);
    expect(find.text('流量隧道管理'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byKey(const Key('settings-reference-frame')),
      matchesGoldenFile('goldens/settings-reference.png'),
    );

    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();
    expect(network.mode, DesktopNetworkMode.systemProxy);
    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();
    expect(network.mode, DesktopNetworkMode.off);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(network.mode, DesktopNetworkMode.tun);
    network._set(DesktopNetworkMode.off);
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey('reference-settings-scroll')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    expect(find.text('外部控制'), findsOneWidget);
    expect(find.text('备份设置'), findsOneWidget);
    expect(find.text('RS 版本'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('settings-reference-frame')),
      matchesGoldenFile('goldens/settings-reference-advanced.png'),
    );
    await tester.tap(find.text('流量隧道管理'));
    expect(navigated, DesktopSection.connections);
    await tester.tap(find.text('当前配置'));
    expect(navigated, DesktopSection.subscription);
  });
}
