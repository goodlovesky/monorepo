import 'dart:io';

import 'package:app/core/vpn/vpn_controller.dart';
import 'package:app/platform/desktop/desktop_network_service.dart';
import 'package:app/platform/windows/windows_network_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop runtime config preserves mihomo anytls proxies', () {
    final output = buildRuntimeDesktopConfig(
      '''
mixed-port: 7890
proxies:
    - { name: 'a', type: anytls, server: 1.1.1.1, port: 443 }
    - { name: 'b', type: vmess, server: 2.2.2.2, port: 443 }
proxy-groups:
    - name: G
      type: select
      proxies: [a, b]
rules:
  - MATCH,DIRECT
''',
      overrides: const {'controller-port': '16171'},
    );

    expect(output, contains("name: 'a'"));
    expect(output, contains('anytls'));
    expect(output, contains("name: 'b'"));
    expect(output, contains('vmess'));
    expect(output, contains('proxies: [a, b]'));
  });

  test('desktop runtime config applies settings without losing rules', () {
    final output = buildRuntimeDesktopConfig(
      '''
mixed-port: 7890
mode: global
log-level: debug
dns:
  enable: true
  nameserver: [1.1.1.1]
rules:
  - MATCH,DIRECT
''',
      overrides: const {'mixed-port': '17892', 'controller-port': '16171'},
      mode: 'rule',
      dnsEnabled: false,
      allowLan: true,
    );

    expect(output, contains('mixed-port: 17892'));
    expect(output, contains('external-controller: 127.0.0.1:16171'));
    expect(output, contains('mode: rule'));
    expect(output, contains('allow-lan: true'));
    expect(output, contains('dns:\n  enable: false'));
    expect(output, contains('MATCH,DIRECT'));
    expect(output, isNot(contains('nameserver:')));
  });

  test('desktop listener overrides replace privileged subscription ports', () {
    final output = buildRuntimeDesktopConfig(
      'mixed-port: 520\nport: 80\nsocks-port: 1080\nrules:\n  - MATCH,DIRECT\n',
      overrides: const {
        'port': '17890',
        'socks-port': '17891',
        'mixed-port': '17892',
        'controller-port': '9090',
      },
    );

    expect(output, contains('port: 17890'));
    expect(output, contains('socks-port: 17891'));
    expect(output, contains('mixed-port: 17892'));
    expect(output, isNot(contains('mixed-port: 520')));
  });

  test('Windows system proxy writes and restores exact snapshot', () async {
    final directory = await Directory.systemTemp.createTemp(
      'clash-rs-win-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final calls = <String>[];
    Future<ProcessResult> runner(String executable, List<String> args) async {
      calls.add('$executable ${args.join(' ')}');
      if (args.contains('query')) {
        final name = args.last;
        final value = switch (name) {
          'ProxyEnable' => '0x1',
          'ProxyServer' => 'old.proxy:8080',
          'ProxyOverride' => 'localhost;<local>',
          _ => '',
        };
        return ProcessResult(1, 0, '    $name    REG_SZ    $value', '');
      }
      return ProcessResult(1, 0, '', '');
    }

    final service = WindowsNetworkService(
      runner: runner,
      recoveryFile: File('${directory.path}/recovery.json'),
    );
    await service.enableSystemProxy(httpPort: 17890, socksPort: 17891);
    expect(service.mode, DesktopNetworkMode.systemProxy);
    expect(calls.join('\n'), contains('http=127.0.0.1:17890'));
    await service.restore();
    expect(service.mode, DesktopNetworkMode.off);
    expect(calls.join('\n'), contains('old.proxy:8080'));
    expect(await File('${directory.path}/recovery.json').exists(), isFalse);
  });
}
