import 'dart:ui';

import 'package:app/core/ffi/clash_controller.dart';
import 'package:app/features/desktop/desktop_app.dart' show buildDesktopTheme;
import 'package:app/features/desktop/pages/proxy_page.dart';
import 'package:app/services/proxy_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClashController extends ClashController {
  _FakeClashController() : super(baseUrl: 'http://127.0.0.1:0');

  String now = '香港 01 | 1x HK';
  int healthCheckCalls = 0;

  ProxyGroup get group => ProxyGroup(
    name: 'GLOBAL',
    type: 'select',
    all: const ['香港 01 | 1x HK', '香港 03 | 1x HK'],
    now: now,
    nodeTypes: const {
      '香港 01 | 1x HK': 'Shadowsocks',
      '香港 03 | 1x HK': 'Shadowsocks',
    },
    nodeUdp: const {'香港 01 | 1x HK': true, '香港 03 | 1x HK': true},
  );

  @override
  Future<Map<String, ProxyGroup>> getProxies() async => {'GLOBAL': group};

  @override
  Future<void> selectNode(String group, String name) async => now = name;

  @override
  Future<int> healthCheck(
    String group,
    String name, {
    Duration? timeout,
  }) async {
    healthCheckCalls++;
    return 92;
  }
}

void main() {
  test('Check selects the node and stores its millisecond delay', () async {
    final api = _FakeClashController();
    final controller = ProxyAppController(controllerForTesting: api)
      ..engineRunning = true
      ..vpnRunning = true
      ..selectedGroup = 'GLOBAL'
      ..groups = {'GLOBAL': api.group};

    await controller.selectAndCheckNode('香港 03 | 1x HK');

    expect(api.now, '香港 03 | 1x HK');
    expect(controller.groups['GLOBAL']!.now, '香港 03 | 1x HK');
    expect(controller.delays['香港 03 | 1x HK'], 92);
    controller.dispose();
  });

  test(
    'selected running node is checked immediately and periodically',
    () async {
      final api = _FakeClashController();
      final controller =
          ProxyAppController(
              controllerForTesting: api,
              selectedNodeHealthInterval: const Duration(milliseconds: 20),
            )
            ..engineRunning = true
            ..vpnRunning = true
            ..selectedGroup = 'GLOBAL'
            ..groups = {'GLOBAL': api.group};

      controller.startSelectedNodeHealthMonitorForTest();
      await Future<void>.delayed(const Duration(milliseconds: 75));

      expect(api.healthCheckCalls, greaterThanOrEqualTo(3));
      expect(controller.delays['香港 01 | 1x HK'], 92);
      controller.dispose();
    },
  );

  testWidgets('Check only appears while hovering an untested proxy node', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ProxyAppController()
      ..selectedGroup = 'GLOBAL'
      ..groups = {
        'GLOBAL': ProxyGroup(
          name: 'GLOBAL',
          type: 'select',
          all: const ['DIRECT', 'REJECT', '剩余流量：58.93 GB', '香港 03 | 1x HK'],
          now: '香港 03 | 1x HK',
          nodeTypes: const {
            'DIRECT': 'Direct',
            'REJECT': 'Reject',
            '剩余流量：58.93 GB': 'anytls',
            '香港 03 | 1x HK': 'Shadowsocks',
          },
          nodeUdp: const {
            'DIRECT': true,
            'REJECT': true,
            '剩余流量：58.93 GB': true,
            '香港 03 | 1x HK': true,
          },
        ),
      };

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDesktopTheme(),
        home: Scaffold(body: ProxyPage(controller: controller)),
      ),
    );

    expect(find.text('Check'), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.text('DIRECT')));
    await tester.pump();
    expect(find.text('Check'), findsNothing);

    await mouse.moveTo(tester.getCenter(find.text('剩余流量：58.93 GB')));
    await tester.pump();
    expect(find.text('Check'), findsNothing);

    await mouse.moveTo(tester.getCenter(find.text('香港 03 | 1x HK')));
    await tester.pump();
    expect(find.text('Check'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.text('Check'), findsNothing);
    expect(find.text('香港 03 | 1x HK'), findsOneWidget);
    controller.dispose();
  });
}
