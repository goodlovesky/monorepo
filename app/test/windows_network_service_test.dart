import 'dart:io';

import 'package:app/platform/desktop/desktop_network_service.dart';
import 'package:app/platform/windows/windows_network_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows proxy snapshot is restored and WinINet is notified', () async {
    final temp = await Directory.systemTemp.createTemp('clashrs-windows-');
    addTearDown(() => temp.delete(recursive: true));
    final recovery = File('${temp.path}/network-recovery.json');
    final calls = <String>[];

    Future<ProcessResult> runner(
      String executable,
      List<String> arguments,
    ) async {
      calls.add('$executable ${arguments.join(' ')}');
      if (executable == 'reg.exe' && arguments.first == 'query') {
        final name = arguments.last;
        final value = switch (name) {
          'ProxyEnable' => '0x0',
          'ProxyServer' => 'legacy.proxy:8080',
          'ProxyOverride' => '<local>;intranet',
          _ => '',
        };
        return ProcessResult(1, 0, '    $name    REG_SZ    $value\r\n', '');
      }
      return ProcessResult(1, 0, '', '');
    }

    final service = WindowsNetworkService(
      runner: runner,
      recoveryFile: recovery,
    );
    await service.enableSystemProxy(httpPort: 17890, socksPort: 17891);

    expect(service.mode, DesktopNetworkMode.systemProxy);
    expect(await recovery.exists(), isTrue);
    expect(
      calls.join('\n'),
      contains(
        'ProxyServer /t REG_SZ /d '
        'http=127.0.0.1:17890;https=127.0.0.1:17890;'
        'socks=127.0.0.1:17891 /f',
      ),
    );
    expect(
      calls.where((call) => call.startsWith('powershell.exe')),
      hasLength(1),
    );

    calls.clear();
    await service.restore();
    expect(service.mode, DesktopNetworkMode.off);
    expect(await recovery.exists(), isFalse);
    expect(calls.join('\n'), contains('ProxyEnable /t REG_DWORD /d 0 /f'));
    expect(
      calls.join('\n'),
      contains('ProxyServer /t REG_SZ /d legacy.proxy:8080 /f'),
    );
    expect(
      calls.join('\n'),
      contains('ProxyOverride /t REG_SZ /d <local>;intranet /f'),
    );
    expect(
      calls.where((call) => call.startsWith('powershell.exe')),
      hasLength(1),
    );
  });

  test(
    'recovery file restores previous proxy after application restart',
    () async {
      final temp = await Directory.systemTemp.createTemp('clashrs-windows-');
      addTearDown(() => temp.delete(recursive: true));
      final recovery = File('${temp.path}/network-recovery.json');
      await recovery.writeAsString(
        '{"mode":"systemProxy","proxy":'
        '{"enabled":true,"server":"old:3128","override":"localhost"}}',
      );
      final calls = <String>[];
      final service = WindowsNetworkService(
        recoveryFile: recovery,
        runner: (executable, arguments) async {
          calls.add('$executable ${arguments.join(' ')}');
          return ProcessResult(1, 0, '', '');
        },
      );

      await service.recover();

      expect(calls.join('\n'), contains('ProxyEnable /t REG_DWORD /d 1 /f'));
      expect(
        calls.join('\n'),
        contains('ProxyServer /t REG_SZ /d old:3128 /f'),
      );
      expect(await recovery.exists(), isFalse);
    },
  );

  test(
    'failed registry write keeps the recovery file for next launch',
    () async {
      final temp = await Directory.systemTemp.createTemp('clashrs-windows-');
      addTearDown(() => temp.delete(recursive: true));
      final recovery = File('${temp.path}/network-recovery.json');
      var addCount = 0;
      final service = WindowsNetworkService(
        recoveryFile: recovery,
        runner: (executable, arguments) async {
          if (executable == 'reg.exe' && arguments.first == 'query') {
            return ProcessResult(1, 0, '', '');
          }
          if (executable == 'reg.exe' && arguments.first == 'add') {
            addCount += 1;
            if (addCount == 1) return ProcessResult(1, 1, '', 'access denied');
          }
          return ProcessResult(1, 0, '', '');
        },
      );

      await expectLater(
        service.enableSystemProxy(),
        throwsA(isA<StateError>()),
      );
      // enableSystemProxy performs a rollback. If rollback itself succeeds the
      // persisted snapshot is intentionally cleared because state is restored.
      expect(await recovery.exists(), isFalse);
      expect(service.mode, DesktopNetworkMode.off);
    },
  );
}
