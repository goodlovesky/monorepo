import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/log/app_log.dart';

import '../../core/vpn/vpn_controller.dart';
import '../desktop/desktop_network_service.dart';

typedef LinuxProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

enum LinuxDesktopEnvironment { gnome, kde }

LinuxDesktopEnvironment? detectLinuxDesktopEnvironment(
  Map<String, String> env,
) {
  final value =
      '${env['XDG_CURRENT_DESKTOP'] ?? ''};${env['DESKTOP_SESSION'] ?? ''}'
          .toLowerCase();
  if (value.contains('gnome') ||
      value.contains('unity') ||
      value.contains('cinnamon') ||
      value.contains('pantheon')) {
    return LinuxDesktopEnvironment.gnome;
  }
  if (value.contains('kde') || value.contains('plasma')) {
    return LinuxDesktopEnvironment.kde;
  }
  return null;
}

class LinuxNetworkService extends ChangeNotifier
    implements DesktopNetworkService {
  LinuxNetworkService({
    LinuxProcessRunner? runner,
    Map<String, String>? environment,
    File? recoveryFile,
    File? bundledMihomo,
  }) : _runner = runner ?? Process.run,
       _environment = environment ?? Platform.environment,
       _recoveryFileOverride = recoveryFile,
       _bundledMihomoOverride = bundledMihomo;

  final LinuxProcessRunner _runner;
  final Map<String, String> _environment;
  final File? _recoveryFileOverride;
  final File? _bundledMihomoOverride;
  Map<String, String>? _proxySnapshot;
  LinuxDesktopEnvironment? _snapshotDesktop;
  int? _tunPid;
  int _controllerPort = 9090;

  @override
  DesktopNetworkMode mode = DesktopNetworkMode.off;
  @override
  String? lastError;

  void _update({
    DesktopNetworkMode? nextMode,
    String? error,
    bool clearError = false,
  }) {
    var changed = false;
    if (nextMode != null && mode != nextMode) {
      mode = nextMode;
      changed = true;
    }
    final nextError = clearError ? null : error ?? lastError;
    if (lastError != nextError) {
      lastError = nextError;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  File get _recoveryFile {
    if (_recoveryFileOverride != null) return _recoveryFileOverride;
    final home = _environment['HOME'] ?? Directory.current.path;
    final state = _environment['XDG_STATE_HOME'] ?? '$home/.local/state';
    return File('$state/clash-rs/network-recovery.json');
  }

  File get _bundledMihomo {
    if (_bundledMihomoOverride != null) return _bundledMihomoOverride;
    return File('${File(Platform.resolvedExecutable).parent.path}/mihomo');
  }

  @override
  Future<void> recover() async {
    if (!Platform.isLinux && identical(_runner, Process.run)) return;
    final file = _recoveryFile;
    if (!await file.exists()) return;
    try {
      final root =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _tunPid = (root['tunPid'] as num?)?.toInt();
      _controllerPort = (root['controllerPort'] as num?)?.toInt() ?? 9090;
      final desktop = root['desktop']?.toString();
      _snapshotDesktop = desktop == 'kde'
          ? LinuxDesktopEnvironment.kde
          : desktop == 'gnome'
          ? LinuxDesktopEnvironment.gnome
          : null;
      _proxySnapshot = (root['proxy'] as Map?)?.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      await restore();
      _update(clearError: true);
    } catch (error) {
      _update(
        error: AppLog.pick('恢复 Linux 网络状态失败：$error', 'Failed to restore Linux network state: $error'),
      );
      rethrow;
    }
  }

  @override
  Future<void> enableSystemProxy({
    int httpPort = 17890,
    int socksPort = 17891,
  }) async {
    if (!Platform.isLinux && identical(_runner, Process.run)) return;
    final desktop = detectLinuxDesktopEnvironment(_environment);
    if (desktop == null) {
      throw StateError('未识别 Linux 桌面环境，仅支持 GNOME 与 KDE Plasma');
    }
    try {
      _snapshotDesktop = desktop;
      _proxySnapshot = desktop == LinuxDesktopEnvironment.gnome
          ? await _readGnomeSnapshot()
          : await _readKdeSnapshot();
      await _persistRecovery('systemProxy');
      if (desktop == LinuxDesktopEnvironment.gnome) {
        await _enableGnome(httpPort, socksPort);
      } else {
        await _enableKde(httpPort, socksPort);
      }
      _update(nextMode: DesktopNetworkMode.systemProxy, clearError: true);
    } catch (error) {
      try {
        await _restoreProxy();
      } catch (e, s) {
        debugPrint('linux_network_service.best-effort restoreProxy: $e\n$s');
      }
      _update(
        nextMode: DesktopNetworkMode.off,
        error: AppLog.pick('启用 Linux 系统代理失败：$error', 'Failed to enable Linux system proxy: $error'),
      );
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
    if (!Platform.isLinux && identical(_runner, Process.run)) return;
    final mihomo = _bundledMihomo;
    if (!await mihomo.exists()) {
      throw StateError('Linux Mihomo 未找到：${mihomo.path}');
    }
    final capability = await _runner('getcap', [mihomo.path]);
    final capabilityText = '${capability.stdout}';
    if (capability.exitCode != 0 || !capabilityText.contains('cap_net_admin')) {
      throw StateError(
        'Linux TUN 尚未初始化，请执行：pkexec setcap cap_net_admin,cap_net_raw+ep ${mihomo.path}',
      );
    }
    await Directory(supportPath).create(recursive: true);
    final base = await File(baseConfigPath).readAsString();
    final runtime = File('$supportPath/runtime-linux-tun.yaml');
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
    final log = File('$supportPath/linux-tun.log');
    final command =
        'nohup ${_quote(mihomo.path)} -d ${_quote(supportPath)} '
        '-f ${_quote(runtime.path)} >> ${_quote(log.path)} 2>&1 < /dev/null & echo \$!';
    final launched = await _runner('/bin/bash', ['-lc', command]);
    if (launched.exitCode != 0) throw StateError('${launched.stderr}'.trim());
    _tunPid = int.tryParse(
      '${launched.stdout}'.trim().split(RegExp(r'\s+')).last,
    );
    if (_tunPid == null || _tunPid! <= 0) throw StateError('Mihomo 未返回有效 PID');
    _controllerPort = controllerPort;
    await _persistRecovery('tun');
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      if (await isHealthy(controllerPort: controllerPort)) {
        _update(nextMode: DesktopNetworkMode.tun, clearError: true);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await disableTun();
    throw StateError('Linux TUN 核心未在 15 秒内启动');
  }

  @override
  Future<void> disableTun() async {
    final pid = _tunPid;
    if (pid != null && pid > 0) {
      final lookup = await _runner('/bin/ps', ['-p', '$pid', '-o', 'command=']);
      if (lookup.exitCode == 0 && '${lookup.stdout}'.contains('mihomo')) {
        await _runner('/bin/kill', ['-TERM', '$pid']);
      }
    }
    _tunPid = null;
    _update(nextMode: DesktopNetworkMode.off);
    await _clearRecovery();
  }

  @override
  Future<void> restore() async {
    if (_tunPid != null) await disableTun();
    if (_proxySnapshot != null) await _restoreProxy();
    _proxySnapshot = null;
    _snapshotDesktop = null;
    _update(nextMode: DesktopNetworkMode.off, clearError: true);
    await _clearRecovery();
  }

  @override
  Future<bool> isHealthy({int controllerPort = 9090}) async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        controllerPort,
        timeout: const Duration(milliseconds: 500),
      );
      socket.destroy();
      return true;
    } catch (e, s) {
      debugPrint('linux_network_service.controllerPortOpen: $e\n$s');
      return false;
    }
  }

  Future<Map<String, String>> _readGnomeSnapshot() async {
    final values = <String, String>{};
    for (final entry in _gnomeKeys.entries) {
      values[entry.key] = await _run('gsettings', ['get', ...entry.value]);
    }
    return values;
  }

  Future<void> _enableGnome(int httpPort, int socksPort) async {
    await _gset('mode', "'manual'");
    await _gset('httpHost', "'127.0.0.1'");
    await _gset('httpPort', '$httpPort');
    await _gset('httpsHost', "'127.0.0.1'");
    await _gset('httpsPort', '$httpPort');
    await _gset('socksHost', "'127.0.0.1'");
    await _gset('socksPort', '$socksPort');
    await _gset('ignoreHosts', "['localhost', '127.0.0.0/8', '::1']");
  }

  Future<void> _restoreProxy() async {
    final snapshot = _proxySnapshot;
    final desktop = _snapshotDesktop;
    if (snapshot == null || desktop == null) return;
    if (desktop == LinuxDesktopEnvironment.gnome) {
      for (final entry in snapshot.entries) {
        await _gset(entry.key, entry.value);
      }
    } else {
      final command = await _kdeCommand();
      for (final entry in snapshot.entries) {
        await _run(command, [
          '--file',
          'kioslaverc',
          '--group',
          'Proxy Settings',
          '--key',
          entry.key,
          entry.value,
        ]);
      }
      await _notifyKde();
    }
  }

  Future<Map<String, String>> _readKdeSnapshot() async {
    final command = await _kdeReadCommand();
    final values = <String, String>{};
    for (final key in _kdeKeys) {
      values[key] = await _run(command, [
        '--file',
        'kioslaverc',
        '--group',
        'Proxy Settings',
        '--key',
        key,
      ]);
    }
    return values;
  }

  Future<void> _enableKde(int httpPort, int socksPort) async {
    final command = await _kdeCommand();
    final values = <String, String>{
      'ProxyType': '1',
      'httpProxy': 'http://127.0.0.1:$httpPort',
      'httpsProxy': 'http://127.0.0.1:$httpPort',
      'socksProxy': 'socks://127.0.0.1:$socksPort',
      'NoProxyFor': 'localhost,127.0.0.1,::1',
    };
    for (final entry in values.entries) {
      await _run(command, [
        '--file',
        'kioslaverc',
        '--group',
        'Proxy Settings',
        '--key',
        entry.key,
        entry.value,
      ]);
    }
    await _notifyKde();
  }

  Future<String> _kdeCommand() async =>
      (await _runner('which', ['kwriteconfig6'])).exitCode == 0
      ? 'kwriteconfig6'
      : 'kwriteconfig5';
  Future<String> _kdeReadCommand() async =>
      (await _runner('which', ['kreadconfig6'])).exitCode == 0
      ? 'kreadconfig6'
      : 'kreadconfig5';

  Future<void> _notifyKde() async {
    for (final command in const ['qdbus6', 'qdbus']) {
      final available = await _runner('which', [command]);
      if (available.exitCode != 0) continue;
      await _runner(command, const [
        'org.kde.KIO.Scheduler',
        '/KIO/Scheduler',
        'reparseSlaveConfiguration',
      ]);
      return;
    }
  }

  Future<void> _gset(String name, String value) =>
      _run('gsettings', ['set', ..._gnomeKeys[name]!, value]).then((_) {});

  Future<String> _run(String executable, List<String> arguments) async {
    final result = await _runner(executable, arguments);
    if (result.exitCode != 0) {
      throw StateError(
        '$executable ${arguments.join(' ')}: ${result.stderr}'.trim(),
      );
    }
    return '${result.stdout}'.trim();
  }

  Future<void> _persistRecovery(String kind) async {
    final file = _recoveryFile;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'mode': kind,
        'desktop': _snapshotDesktop?.name,
        'proxy': _proxySnapshot,
        'tunPid': _tunPid,
        'controllerPort': _controllerPort,
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<void> _clearRecovery() async {
    final file = _recoveryFile;
    if (await file.exists()) await file.delete();
  }

  String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
}

const _gnomeKeys = <String, List<String>>{
  'mode': ['org.gnome.system.proxy', 'mode'],
  'httpHost': ['org.gnome.system.proxy.http', 'host'],
  'httpPort': ['org.gnome.system.proxy.http', 'port'],
  'httpsHost': ['org.gnome.system.proxy.https', 'host'],
  'httpsPort': ['org.gnome.system.proxy.https', 'port'],
  'socksHost': ['org.gnome.system.proxy.socks', 'host'],
  'socksPort': ['org.gnome.system.proxy.socks', 'port'],
  'ignoreHosts': ['org.gnome.system.proxy', 'ignore-hosts'],
};

const _kdeKeys = [
  'ProxyType',
  'httpProxy',
  'httpsProxy',
  'socksProxy',
  'NoProxyFor',
];
