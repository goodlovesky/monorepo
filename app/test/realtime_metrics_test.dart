import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/ffi/clash_controller.dart';

void main() {
  late HttpServer server;
  late ClashController controller;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    controller = ClashController(
      baseUrl: 'http://127.0.0.1:${server.port}',
      secret: 'test-secret',
      timeout: const Duration(seconds: 2),
    );
    unawaited(
      server.forEach((request) async {
        expect(request.headers.value('authorization'), 'Bearer test-secret');
        request.response.bufferOutput = false;
        request.response.headers.contentType = ContentType.json;
        switch (request.uri.path) {
          case '/traffic':
            request.response.write(
              '${jsonEncode({'up': 123, 'down': 456, 'upTotal': 789, 'downTotal': 1011})}\n',
            );
            await request.response.flush();
          case '/memory':
            request.response.write('${jsonEncode({'inuse': 0})}\n');
            await request.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 20));
            request.response.write('${jsonEncode({'inuse': 52428800})}\n');
            await request.response.flush();
          case '/connections':
            request.response.write(
              jsonEncode({
                'uploadTotal': 2048,
                'downloadTotal': 4096,
                'connections': [
                  {'id': 'live-connection'},
                ],
              }),
            );
            await request.response.close();
        }
      }),
    );
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('reads one traffic frame without waiting for stream close', () async {
    final traffic = await controller.getTraffic();
    expect(traffic.up, 123);
    expect(traffic.down, 456);
    expect(traffic.upTotal, 789);
    expect(traffic.downTotal, 1011);
  });

  test('uses the non-zero memory frame and reports MB', () async {
    expect(await controller.getMemory(), 50);
  });

  test('connections remain available beside realtime streams', () async {
    final snapshot = await controller.getConnectionSnapshot();
    expect(snapshot.connections.single['id'], 'live-connection');
    expect(snapshot.uploadTotal, 2048);
    expect(snapshot.downloadTotal, 4096);
  });
}
