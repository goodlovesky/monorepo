// 验证 start() 流程里新增的 controller 端口就绪轮询逻辑。
//
// 重点覆盖两件事：
// 1) 端口从未起来时,轮询能正确等到超时并返回 false。
// 2) 端口在中途被占用时,轮询能立刻感知并返回 true。
//
// 这个用例直接构造 ProxyAppController 调用私有 helper；用 @visibleForTesting
// 暴露出来的接口来避开 private 限制。
import 'dart:io';

import 'package:app/services/proxy_app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IP 信息在系统代理模式显式使用本地 HTTP 端口', () {
    expect(ProxyAppController.ipInfoProxyForPort(null), 'DIRECT');
    expect(
      ProxyAppController.ipInfoProxyForPort(17890),
      'PROXY 127.0.0.1:17890',
    );
  });

  test('_waitForControllerPortReady 在端口未起时超时返回 false', () async {
    final controller = ProxyAppController();
    // 选一个极不可能被占的端口
    final picked = await _pickFreePort();
    final start = DateTime.now();
    final ready = await controller.waitForControllerPortReadyForTest(
      picked,
      timeout: const Duration(milliseconds: 600),
    );
    final elapsed = DateTime.now().difference(start);
    expect(ready, isFalse);
    expect(elapsed.inMilliseconds, greaterThanOrEqualTo(550));
  });

  test('_waitForControllerPortReady 在端口被占时立刻返回 true', () async {
    final controller = ProxyAppController();
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    addTearDown(() async => await server.close());
    final start = DateTime.now();
    final ready = await controller.waitForControllerPortReadyForTest(
      port,
      timeout: const Duration(seconds: 2),
    );
    final elapsed = DateTime.now().difference(start);
    expect(ready, isTrue);
    expect(elapsed.inMilliseconds, lessThan(400));
  });
}

Future<int> _pickFreePort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}
