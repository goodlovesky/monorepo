import 'package:app/core/vpn/vpn_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildRuntimeVpnConfig', () {
    test('appends the Android-owned TUN descriptor', () {
      final result = buildRuntimeVpnConfig(
        'mode: rule\nrules:\n  - MATCH,DIRECT\n',
        42,
      );

      expect(result, contains('device-id: "fd://42"'));
      expect(result, contains('route-all: false'));
      expect(result, contains('dns-hijack: true'));
      expect(result, contains('dns:\n  enable: true'));
      expect(result, contains('mode: rule'));
    });

    test('replaces disabled DNS with the VPN runtime resolver', () {
      final result = buildRuntimeVpnConfig(
        'dns:\n  enable: false\n  nameserver:\n    - 9.9.9.9\nrules:\n  - MATCH,DIRECT\n',
        8,
      );

      expect('dns:'.allMatches(result), hasLength(1));
      expect(result, isNot(contains('9.9.9.9')));
      expect(result, contains('enhanced-mode: normal'));
      expect(result, contains('1.1.1.1'));
    });

    test('replaces an existing top-level tun block', () {
      final result = buildRuntimeVpnConfig(
        'port: 7890\ntun:\n  enable: false\n  device-id: old\nrules:\n  - MATCH,DIRECT\n',
        7,
      );

      expect('tun:'.allMatches(result), hasLength(1));
      expect(result, isNot(contains('device-id: old')));
      expect(result, contains('device-id: "fd://7"'));
      expect(result, contains('rules:'));
    });

    test('rejects an invalid descriptor', () {
      expect(
        () => buildRuntimeVpnConfig('mode: rule', 0),
        throwsA(isA<VpnException>()),
      );
    });

    test('applies network and core override settings', () {
      final result = buildRuntimeVpnConfig(
        'mixed-port: 7890\nmode: rule\n',
        17,
        dnsHijack: false,
        ipv6: true,
        stackMode: 'mixed',
        overrides: const {
          'mixed-port': '17892',
          'dns.enhanced-mode': 'fake-ip',
          'dns.nameserver': '9.9.9.9, 1.0.0.1',
        },
        meta: const {'unified-delay': 'true'},
      );

      expect(result, contains('mixed-port: 17892'));
      expect(result, isNot(contains('mixed-port: 7890')));
      expect(result, contains('ipv6: true'));
      expect(result, contains('stack: mixed'));
      expect(result, contains('dns-hijack: false'));
      expect(result, contains('enhanced-mode: fake-ip'));
      expect(result, contains('    - 9.9.9.9'));
      expect(result, contains('unified-delay: true'));
    });
  });

  group('buildRuntimeMacTunConfig', () {
    test('replaces runtime blocks with macOS auto-route TUN settings', () {
      final result = buildRuntimeMacTunConfig(
        'mode: rule\ndns:\n  enable: false\ntun:\n  enable: false\nrules:\n  - MATCH,DIRECT\n',
      );

      expect('dns:'.allMatches(result), hasLength(1));
      expect('tun:'.allMatches(result), hasLength(1));
      expect(result, contains('auto-route: true'));
      expect(result, contains('auto-detect-interface: true'));
      expect(result, contains('dns-hijack:\n    - any:53'));
      // sanitize 走 yaml 解析后,字符串会被加单引号(jsonDecode 格式),
      // 行为上等价,这里接受 quoted 形式。
      expect(result, contains('rules:'));
      expect(result, contains('MATCH,DIRECT'));
    });

    test('preserves mihomo anytls proxies in macOS TUN runtime config', () {
      final result = buildRuntimeMacTunConfig('''
proxies:
  - name: "good"
    type: ss
    server: 1.1.1.1
    port: 8388
  - name: "bad"
    type: anytls
    server: 2.2.2.2
    port: 443
proxy-groups:
  - name: G
    type: select
    proxies:
      - good
      - bad
rules:
  - MATCH,good
''');

      expect(result, contains('name: "good"'));
      expect(result, contains('type: ss'));
      expect(result, contains('anytls'));
      expect(result, contains('"bad"'));
      expect(result, contains('      - bad'));
      expect(result, contains('MATCH,good'));
      expect(result, contains('external-controller: 127.0.0.1:9090'));
    });

    test('applies desktop TUN network settings', () {
      final result = buildRuntimeMacTunConfig(
        'rules:\n  - MATCH,DIRECT\n',
        ipv6: true,
        stackMode: 'gvisor',
        dnsHijack: false,
        autoRoute: false,
      );
      expect(result, contains('ipv6: true'));
      expect(result, contains('stack: gvisor'));
      expect(result, contains('auto-route: false'));
      expect(result, isNot(contains('dns-hijack:')));
    });
  });
}
