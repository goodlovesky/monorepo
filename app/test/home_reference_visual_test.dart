import 'package:app/features/desktop/desktop_app.dart';
import 'package:app/core/ffi/clash_controller.dart';
import 'package:app/models/proxy_profile.dart';
import 'package:app/platform/desktop/desktop_network_service.dart';
import 'package:app/services/proxy_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _VisualNetwork extends ChangeNotifier implements DesktopNetworkService {
  @override
  Future<bool> isHealthy({int controllerPort = 9090}) async => true;
  @override
  String? lastError;

  @override
  DesktopNetworkMode mode = DesktopNetworkMode.off;

  @override
  Future<void> disableTun() async => _setMode(DesktopNetworkMode.off);

  @override
  Future<void> enableSystemProxy({
    int httpPort = 17890,
    int socksPort = 17891,
  }) async => _setMode(DesktopNetworkMode.systemProxy);

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
  }) async => _setMode(DesktopNetworkMode.tun);

  @override
  Future<void> recover() async {}

  @override
  Future<void> restore() async => _setMode(DesktopNetworkMode.off);

  void _setMode(DesktopNetworkMode next) {
    mode = next;
    notifyListeners();
  }
}

void main() {
  testWidgets('home reference layout has stable top middle and bottom frames', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 692));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ProxyAppController();
    final network = _VisualNetwork();
    const referenceNode = '美国2-780.36GB📊';
    controller.profiles = [
      ProxyProfile(
        id: 'reference',
        name: 'ilbutr5tmio9snkk',
        sourceType: 'url',
        source: '203.0.113.10:20000/subscription',
        localYamlPath: '/tmp/reference.yaml',
        createdAt: DateTime(2026, 8, 19, 3, 57),
        updatedAt: DateTime(2026, 8, 19, 3, 57),
        usedTrafficBytes: 220 * 1024 * 1024 * 1024,
        totalTrafficBytes: 1000 * 1024 * 1024 * 1024,
        active: true,
      ),
    ];
    controller.groups = {
      'PROXY': ProxyGroup(
        name: 'PROXY',
        type: 'select',
        all: const [referenceNode],
        now: referenceNode,
        nodeTypes: const {referenceNode: 'Vless'},
        nodeUdp: const {referenceNode: true},
      ),
    };
    controller.selectedGroup = null;
    controller.delays = const {referenceNode: 181};
    controller.proxyMode = 'global';
    addTearDown(controller.dispose);
    addTearDown(network.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildDesktopTheme(),
        home: RepaintBoundary(
          key: const Key('home-reference-frame'),
          child: Scaffold(
            body: Row(
              children: [
                DesktopSidebar(
                  selected: DesktopSection.home,
                  controller: controller,
                  onSelected: (_) {},
                ),
                Expanded(
                  child: Column(
                    children: [
                      DesktopHeader(
                        title: '首页',
                        onHome: () {},
                        onSettings: () {},
                        onDiagnostics: () {},
                      ),
                      Expanded(
                        child: DesktopPageHost(
                          section: DesktopSection.home,
                          controller: controller,
                          network: network,
                          onNavigate: (_) {},
                          onNetworkModeChange: network._setMode,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final frame = find.byKey(const Key('home-reference-frame'));
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(network.mode, DesktopNetworkMode.systemProxy);
    expect(find.text('系统代理已启用，您的应用将通过代理访问网络'), findsOneWidget);
    expect(find.text('181'), findsNWidgets(2));
    expect(find.text('XUDP'), findsOneWidget);
    expect(find.text('已使用 / 总量：220GB / 1000GB'), findsOneWidget);
    expect(find.textContaining('到期时间：'), findsNothing);
    await expectLater(
      frame,
      matchesGoldenFile('goldens/home-reference-top.png'),
    );

    // 页签仅切换选中面板，不直接启停系统代理/TUN。
    await tester.tap(find.text('虚拟网卡模式').first);
    await tester.pumpAndSettle();
    expect(network.mode, DesktopNetworkMode.systemProxy);
    expect(find.text('TUN 模式需要服务模式，请先安装服务'), findsOneWidget);
    await expectLater(
      frame,
      matchesGoldenFile('goldens/home-reference-tun.png'),
    );
    await tester.tap(find.text('系统代理').first);
    await tester.pumpAndSettle();

    final scroll = find.byType(Scrollable).first;
    await tester.drag(scroll, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('流量统计'), findsOneWidget);
    await expectLater(
      frame,
      matchesGoldenFile('goldens/home-reference-middle.png'),
    );

    await tester.drag(scroll, const Offset(0, -780));
    await tester.pumpAndSettle();
    expect(find.text('Clash 信息'), findsOneWidget);
    expect(find.text('系统信息'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      frame,
      matchesGoldenFile('goldens/home-reference-bottom.png'),
    );
  });
}
