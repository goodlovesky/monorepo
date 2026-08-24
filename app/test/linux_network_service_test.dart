import 'dart:io';

import 'package:app/platform/desktop/desktop_network_service.dart';
import 'package:app/platform/linux/linux_network_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects GNOME and KDE desktop environments', () {
    expect(
      detectLinuxDesktopEnvironment({'XDG_CURRENT_DESKTOP': 'ubuntu:GNOME'}),
      LinuxDesktopEnvironment.gnome,
    );
    expect(
      detectLinuxDesktopEnvironment({'XDG_CURRENT_DESKTOP': 'KDE'}),
      LinuxDesktopEnvironment.kde,
    );
    expect(
      detectLinuxDesktopEnvironment({'XDG_CURRENT_DESKTOP': 'sway'}),
      isNull,
    );
  });

  test('GNOME proxy snapshot is persisted and restored', () async {
    final temp = await Directory.systemTemp.createTemp('clashrs-linux-');
    addTearDown(() => temp.delete(recursive: true));
    final recovery = File('${temp.path}/network-recovery.json');
    final calls = <String>[];

    Future<ProcessResult> runner(
      String executable,
      List<String> arguments,
    ) async {
      calls.add('$executable ${arguments.join(' ')}');
      if (executable == 'gsettings' && arguments.first == 'get') {
        final key = arguments.last;
        final value = key.endsWith('port')
            ? '3128'
            : key == 'mode'
            ? "'auto'"
            : key == 'ignore-hosts'
            ? "['legacy.local']"
            : "'legacy.proxy'";
        return ProcessResult(1, 0, '$value\n', '');
      }
      return ProcessResult(1, 0, '', '');
    }

    final service = LinuxNetworkService(
      runner: runner,
      environment: const {'XDG_CURRENT_DESKTOP': 'GNOME'},
      recoveryFile: recovery,
    );
    await service.enableSystemProxy(httpPort: 17890, socksPort: 17891);

    expect(service.mode, DesktopNetworkMode.systemProxy);
    expect(await recovery.exists(), isTrue);
    expect(
      calls.join('\n'),
      contains("gsettings set org.gnome.system.proxy mode 'manual'"),
    );
    expect(
      calls.join('\n'),
      contains('gsettings set org.gnome.system.proxy.http port 17890'),
    );

    calls.clear();
    await service.restore();
    expect(service.mode, DesktopNetworkMode.off);
    expect(await recovery.exists(), isFalse);
    expect(
      calls.join('\n'),
      contains("gsettings set org.gnome.system.proxy mode 'auto'"),
    );
    expect(
      calls.join('\n'),
      contains('gsettings set org.gnome.system.proxy.http port 3128'),
    );
  });

  test('unknown desktop fails instead of reporting proxy success', () async {
    final service = LinuxNetworkService(
      runner: (executable, arguments) async => ProcessResult(1, 0, '', ''),
      environment: const {'XDG_CURRENT_DESKTOP': 'sway'},
    );
    await expectLater(service.enableSystemProxy(), throwsA(isA<StateError>()));
    expect(service.mode, DesktopNetworkMode.off);
  });
}
