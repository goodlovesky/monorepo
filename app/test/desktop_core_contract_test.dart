import 'dart:convert';
import 'dart:io';

import 'package:app/core/ffi/clash_controller.dart';
import 'package:app/core/vpn/vpn_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop runtime replaces a subscription controller secret', () {
    final output = buildRuntimeDesktopConfig(
      "secret: subscription-secret\nrules:\n  - MATCH,DIRECT\n",
      overrides: const {'secret': "''", 'controller-port': '9090'},
    );

    expect(output, isNot(contains('subscription-secret')));
    expect(output, contains("secret: ''"));
    expect(output, contains('external-controller: 127.0.0.1:9090'));
  });

  test('single node delay uses the mihomo node delay endpoint', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    late Uri requestUri;
    late String? authorization;
    server.listen((request) async {
      requestUri = request.uri;
      authorization = request.headers.value(HttpHeaders.authorizationHeader);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'delay': 92}));
      await request.response.close();
    });

    final controller = ClashController(
      baseUrl: 'http://127.0.0.1:${server.port}',
      secret: 'local-secret',
    );
    final delay = await controller.healthCheck('GLOBAL', '香港 03 | 1x HK');

    expect(delay, 92);
    expect(
      Uri.decodeComponent(requestUri.path),
      '/proxies/香港 03 | 1x HK/delay',
    );
    expect(
      requestUri.queryParameters['url'],
      'https://www.gstatic.com/generate_204',
    );
    expect(requestUri.queryParameters['timeout'], '5000');
    expect(authorization, 'Bearer local-secret');
  });
}
