import 'package:app/core/vpn/vpn_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'mihomo desktop runtime preserves supported protocols and references',
    () {
      const input = '''
proxies:
  - name: AnyTLS-01
    type: anytls
    server: hk.example.com
    port: 443
    password: test
proxy-groups:
  - name: PROXY
    type: select
    proxies: [AnyTLS-01, DIRECT]
rules:
  - MATCH,PROXY
''';
      final output = buildRuntimeDesktopConfig(input);
      expect(output, contains('type: anytls'));
      expect(output, contains('AnyTLS-01'));
      expect(output, contains('external-controller: 127.0.0.1:9090'));
      expect(output, contains('tun:\n  enable: false'));
    },
  );

  test('desktop runtime applies overrides without losing rules', () {
    final output = buildRuntimeDesktopConfig(
      'mixed-port: 7890\nrules:\n  - MATCH,DIRECT\n',
      overrides: const {'mixed-port': '17892', 'controller-port': '19090'},
      mode: 'direct',
    );
    expect(output, contains('mixed-port: 17892'));
    expect(output, contains('external-controller: 127.0.0.1:19090'));
    expect(output, contains('mode: direct'));
    expect(output, contains('MATCH,DIRECT'));
  });
}
