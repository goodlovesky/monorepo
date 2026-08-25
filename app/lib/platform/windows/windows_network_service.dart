import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/log/app_log.dart';
import '../../core/vpn/vpn_controller.dart';
import '../desktop/desktop_network_service.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class WindowsProxySnapshot {
  final bool enabled;
  final String server;
  final String override;

  const WindowsProxySnapshot({
    required this.enabled,
    required this.server,
    required this.override,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'server': server,
    'override': override,
  };

  factory WindowsProxySnapshot.fromJson(Map<String, dynamic> json) =>
      WindowsProxySnapshot(
        enabled: json['enabled'] == true,
        server: json['server']?.toString() ?? '',
        override: json['override']?.toString() ?? '',
      );
}

class WindowsNetworkService extends ChangeNotifier
    implements DesktopNetworkService {
  WindowsNetworkService({ProcessRunner? runner, this.recoveryFile})
    : _runner = runner ?? Process.run;

  static const _internetSettings =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
  final ProcessRunner _runner;
  WindowsProxySnapshot? _snapshot;
  Process? _tunProcess;
  int? _tunPid;
  @visibleForTesting
  File? recoveryFile;

  @override
  DesktopNetworkMode mode = DesktopNetworkMode.off;
  @override
  String? lastError;

  @override
  Future<void> recover() async {
    final file = await _locateRecoveryFile();
    if (!await file.exists()) return;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (json['mode'] == 'systemProxy' && json['proxy'] is Map) {
        _snapshot = WindowsProxySnapshot.fromJson(
          json['proxy'] as Map<String, dynamic>,
        );
      } else if (json['mode'] == 'tun') {
        _tunPid = (json['pid'] as num?)?.toInt();
      }
      await restore();
    } catch (error) {
      lastError = AppLog.pick(
        '恢复 Windows 网络状态失败：$error',
        'Failed to restore Windows network state: $error',
      );
      rethrow;
    }
  }

  @override
  Future<void> enableSystemProxy({
    int httpPort = 17890,
    int socksPort = 17891,
  }) async {
    if (!Platform.isWindows && identical(_runner, Process.run)) return;
    await restore();
    _snapshot = await _readSnapshot();
    final file = await _locateRecoveryFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'mode': 'systemProxy', 'proxy': _snapshot!.toJson()}),
      flush: true,
    );
    try {
      await _regAdd(
        'ProxyServer',
        'REG_SZ',
        'http=127.0.0.1:$httpPort;https=127.0.0.1:$httpPort;socks=127.0.0.1:$socksPort',
      );
      await _regAdd('ProxyOverride', 'REG_SZ', '<local>');
      await _regAdd('ProxyEnable', 'REG_DWORD', '1');
      await _notifyInternetSettings();
      mode = DesktopNetworkMode.systemProxy;
      lastError = null;
    } catch (error) {
      lastError = error.toString();
      await restore();
      rethrow;
    }
  }

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
  }) async {
    if (!Platform.isWindows) return;
    await restore();
    final base = await File(baseConfigPath).readAsString();
    final runtime = File('$supportPath/runtime-windows-tun.yaml');
    await runtime.writeAsString(
      buildRuntimeMacTunConfig(
        base,
        ipv6: ipv6,
        stackMode: stackMode,
        dnsHijack: dnsHijack,
        autoRoute: autoRoute,
        controllerPort: controllerPort,
        merge: merge,
        script: script,
      ),
      flush: true,
    );
    final mihomo = await _findMihomo();
    recoveryFile = File('$supportPath/windows-network-recovery.json');
    await recoveryFile!.writeAsString(
      jsonEncode({'mode': 'tun', 'pid': 0}),
      flush: true,
    );
    _tunProcess = await Process.start(mihomo.path, [
      '-d',
      supportPath,
      '-f',
      runtime.path,
    ], mode: ProcessStartMode.detachedWithStdio);
    _tunPid = _tunProcess!.pid;
    await recoveryFile!.writeAsString(
      jsonEncode({'mode': 'tun', 'pid': _tunPid}),
      flush: true,
    );
    await _waitForController(controllerPort);
    mode = DesktopNetworkMode.tun;
  }

  @override
  Future<void> restore() async {
    final tunPid = _tunPid;
    if (tunPid != null && tunPid > 0) {
      final result = await _runner('taskkill.exe', [
        '/PID',
        '$tunPid',
        '/T',
        '/F',
      ]);
      if (result.exitCode != 0 && _tunProcess != null) {
        _tunProcess!.kill();
      }
      _tunProcess = null;
      _tunPid = null;
    }
    final snapshot = _snapshot;
    if (snapshot != null) {
      await _regAdd('ProxyEnable', 'REG_DWORD', snapshot.enabled ? '1' : '0');
      await _regAdd('ProxyServer', 'REG_SZ', snapshot.server);
      await _regAdd('ProxyOverride', 'REG_SZ', snapshot.override);
      await _notifyInternetSettings();
      _snapshot = null;
    }
    final file = await _locateRecoveryFile();
    if (await file.exists()) await file.delete();
    mode = DesktopNetworkMode.off;
  }

  @override
  Future<void> disableTun() => restore();

  @override
  Future<bool> isHealthy({int controllerPort = 9090}) async {
    if (mode != DesktopNetworkMode.tun) return true;
    final pid = _tunPid;
    if (pid == null || pid <= 0) return false;
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        controllerPort,
        timeout: const Duration(milliseconds: 250),
      );
      socket.destroy();
      return true;
    } catch (e, s) {
      debugPrint('windows_network_service.controllerPortOpen: $e\n$s');
      return false;
    }
  }

  Future<WindowsProxySnapshot> _readSnapshot() async => WindowsProxySnapshot(
    enabled: (await _regQuery('ProxyEnable')).trim().endsWith('0x1'),
    server: _regValue(await _regQuery('ProxyServer')),
    override: _regValue(await _regQuery('ProxyOverride')),
  );

  Future<String> _regQuery(String name) async {
    final result = await _runner('reg.exe', [
      'query',
      _internetSettings,
      '/v',
      name,
    ]);
    if (result.exitCode != 0) return '';
    return result.stdout.toString();
  }

  String _regValue(String output) {
    final lines = const LineSplitter().convert(output);
    for (final line in lines) {
      final match = RegExp(r'^\s*\S+\s+REG_\S+\s+(.*)$').firstMatch(line);
      if (match != null) return match.group(1)?.trim() ?? '';
    }
    return '';
  }

  Future<void> _regAdd(String name, String type, String value) async {
    final result = await _runner('reg.exe', [
      'add',
      _internetSettings,
      '/v',
      name,
      '/t',
      type,
      '/d',
      value,
      '/f',
    ]);
    if (result.exitCode != 0) {
      throw StateError(result.stderr.toString().trim());
    }
  }

  Future<void> _notifyInternetSettings() async {
    final script = r'''
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinInetNotify {
  [DllImport("wininet.dll", SetLastError=true)]
  public static extern bool InternetSetOption(IntPtr h, int option, IntPtr b, int l);
}
"@
[WinInetNotify]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
[WinInetNotify]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
''';
    final result = await _runner('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      script,
    ]);
    if (result.exitCode != 0) {
      throw StateError(result.stderr.toString().trim());
    }
  }

  Future<File> _locateRecoveryFile() async {
    if (recoveryFile != null) return recoveryFile!;
    final base = Platform.environment['LOCALAPPDATA'] ?? Directory.current.path;
    return recoveryFile = File('$base/Clash RS/network-recovery.json');
  }

  Future<File> _findMihomo() async {
    final sibling = File(
      '${File(Platform.resolvedExecutable).parent.path}/mihomo.exe',
    );
    if (await sibling.exists()) return sibling;
    final development = File(
      '${Directory.current.path}/windows/runner/resources/mihomo.exe',
    );
    if (await development.exists()) return development;
    final rootDevelopment = File(
      '${Directory.current.path}/app/windows/runner/resources/mihomo.exe',
    );
    if (await rootDevelopment.exists()) return rootDevelopment;
    throw StateError('未找到 Windows mihomo.exe');
  }

  Future<void> _waitForController(int controllerPort) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      try {
        final socket = await Socket.connect(
          '127.0.0.1',
          controllerPort,
          timeout: const Duration(milliseconds: 250),
        );
        socket.destroy();
        return;
      } catch (e, s) {
        debugPrint('windows_network_service.waitForPortClose: $e\n$s');
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    await restore();
    throw StateError('Windows mihomo TUN 启动超时');
  }
}
