import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/log/app_log.dart';
import '../../core/vpn/vpn_controller.dart';
import '../../services/mihomo_geodata_installer.dart';
import '../desktop/desktop_network_service.dart';

/// macOS 网络层日志输出：
/// - 写到 `~/Library/Logs/ClashRS/network.log`(用于自用定位错误)
/// - 同时通过 dart:developer 输出到 macOS Console(便于 `log show` 抓)
/// - 文本按 [AppLog] 当前 locale 自动选 zh / en
File? _logFile;
void _netLog(String tag, String zh, String en) {
  final stamp = DateTime.now().toIso8601String();
  final line = '[$stamp] [$tag] ${AppLog.pick(zh, en)}';
  developer.log(line, name: 'ClashRS.Network');
  try {
    _logFile ??= File(
      '${Platform.environment['HOME'] ?? Directory.current.path}'
      '/Library/Logs/ClashRS/network.log',
    )..parent.createSync(recursive: true);
    _logFile!.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  } catch (e) {
    developer.log(
      AppLog.pick('写日志失败：$e', 'failed to write log: $e'),
      name: 'ClashRS.Network',
    );
  }
}

class MacNetworkSnapshot {
  final String service;
  final MacProxyEndpoint web;
  final MacProxyEndpoint secureWeb;
  final MacProxyEndpoint socks;

  const MacNetworkSnapshot({
    required this.service,
    required this.web,
    required this.secureWeb,
    required this.socks,
  });

  Map<String, dynamic> toJson() => {
    'service': service,
    'web': web.toJson(),
    'secureWeb': secureWeb.toJson(),
    'socks': socks.toJson(),
  };
}

class MacProxyEndpoint {
  final bool enabled;
  final String server;
  final int port;

  const MacProxyEndpoint({
    required this.enabled,
    required this.server,
    required this.port,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'server': server,
    'port': port,
  };
}

class MacProcessIdentity {
  final int pid;
  final String executable;
  final String startToken;

  const MacProcessIdentity({
    required this.pid,
    required this.executable,
    required this.startToken,
  });

  Map<String, dynamic> toJson() => {
    'pid': pid,
    'executable': executable,
    'startToken': startToken,
  };

  factory MacProcessIdentity.fromJson(Map<dynamic, dynamic> json) =>
      MacProcessIdentity(
        pid: (json['pid'] as num?)?.toInt() ?? 0,
        executable: json['executable']?.toString() ?? '',
        startToken: json['startToken']?.toString() ?? '',
      );
}

MacProxyEndpoint parseMacProxyEndpoint(String output) {
  final values = <String, String>{};
  for (final line in const LineSplitter().convert(output)) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    values[line.substring(0, separator).trim()] = line
        .substring(separator + 1)
        .trim();
  }
  return MacProxyEndpoint(
    enabled: values['Enabled'] == 'Yes',
    server: values['Server'] ?? '',
    port: int.tryParse(values['Port'] ?? '') ?? 0,
  );
}

/// DesktopNetworkService macOS 实现。
///
/// 职责:系统代理(proxy + state) + TUN(mihomo 子进程)的状态机。
/// 关键安全策略:任何终止 mihomo PID 的动作都先校验进程身份
/// (`_readProcessIdentity` + `_matchesProcessIdentity`),避免误杀同 PID
/// 复用的其他进程。
class MacNetworkService extends ChangeNotifier
    implements DesktopNetworkService {
  MacNetworkService() {
    _setMode(DesktopNetworkMode.off);
  }

  DesktopNetworkMode _mode = DesktopNetworkMode.off;
  String? _lastError;

  @override
  DesktopNetworkMode get mode => _mode;

  @override
  String? get lastError => _lastError;

  void _setMode(DesktopNetworkMode next) {
    if (_mode == next) return;
    _mode = next;
    notifyListeners();
  }

  void _setLastError(String? value) {
    if (_lastError == value) return;
    _lastError = value;
    notifyListeners();
  }

  final List<MacNetworkSnapshot> _snapshots = [];
  int? _tunPid;
  MacProcessIdentity? _tunIdentity;
  List<String> _baselineUtun = const [];
  int _tunControllerPort = 9090;
  File? _recoveryFile;

  @override
  Future<void> recover() async {
    if (!Platform.isMacOS) return;
    _netLog('recover', 'start', 'start');
    final file = await _recoveryStateFile();
    if (!await file.exists()) {
      _netLog('recover', 'no recovery file', 'no recovery file');
      return;
    }
    try {
      final root =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final snapshots = (root['snapshots'] as List? ?? const []);
      _snapshots
        ..clear()
        ..addAll(snapshots.map((item) => _snapshotFromJson(item as Map)));
      _tunPid =
          (root['tunPid'] as num?)?.toInt() ??
          (root['helperPid'] as num?)?.toInt();
      if (root['processIdentity'] is Map) {
        _tunIdentity = MacProcessIdentity.fromJson(
          root['processIdentity'] as Map,
        );
      }
      // 兼容 1.0.0 开发期只保存 PID 的恢复文件：只在 PID 当前命令行
      // 精确指向本 App 的打包 mihomo 时补齐身份，其他进程一律拒绝终止。
      if (_tunIdentity == null && _tunPid != null) {
        final bundledMihomo =
            '${File(Platform.resolvedExecutable).parent.parent.path}'
            '/Resources/mihomo';
        try {
          _tunIdentity = await _readProcessIdentity(
            _tunPid!,
            bundledMihomo,
          );
        } catch (e, s) {
          // disableTun 会保留恢复文件并返回明确的身份不一致错误。
          debugPrint('mac_network_service.disableTun cleanup: $e\n$s');
        }
      }
      _baselineUtun = ((root['baselineUtun'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList();
      _tunControllerPort = (root['controllerPort'] as num?)?.toInt() ?? 9090;
      _netLog(
        'recover',
        'snapshots=${_snapshots.length} tunPid=$_tunPid mode=${root['mode']}',
        'snapshots=${_snapshots.length} tunPid=$_tunPid mode=${root['mode']}',
      );
      await restore();
      _setLastError(null);
      _netLog('recover', 'done', 'done');
    } catch (error, stack) {
      _netLog(
        'recover',
        'recover 失败：$error\n$stack',
        'recover failed: $error\n$stack',
      );
      _setLastError(
        AppLog.pick('恢复 macOS 网络状态失败：$error', 'Failed to restore macOS network state: $error'),
      );
      rethrow;
    }
  }

  Future<List<String>> activeServices() async {
    _netLog('activeServices', '开始列出网络服务', 'start listing network services');
    final result = await Process.run('/usr/sbin/networksetup', const [
      '-listallnetworkservices',
    ]);
    if (result.exitCode != 0) {
      _netLog(
        'activeServices',
        '失败 exit=${result.exitCode} stderr=${result.stderr} stdout=${result.stdout}',
        'failed exit=${result.exitCode} stderr=${result.stderr} stdout=${result.stdout}',
      );
      throw StateError(result.stderr.toString().trim());
    }
    // networksetup -listallnetworkservices 真实输出格式:
    //   An asterisk (*) denotes that a network service is disabled.
    //   (空行)
    //   <service 1>
    //   *<disabled service 2>
    //   ...
    // 第一行是说明文字,不能当成 service 名;否则后面
    // networksetup -getwebproxy "An asterisk ..." 会报
    // "Unable to find item in network database.",exit=8,stderr 为空。
    final list = const LineSplitter()
        .convert(result.stdout.toString())
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty &&
              !line.startsWith('*') &&
              !line.contains('denotes that a network service'),
        )
        .toList();
    _netLog(
      'activeServices',
      '得到 ${list.length} 个 service: $list',
      'got ${list.length} services: $list',
    );
    return list;
  }

  @override
  Future<void> enableSystemProxy({
    int httpPort = 17890,
    int socksPort = 17891,
  }) async {
    if (!Platform.isMacOS) return;
    _netLog(
      'enableSystemProxy',
      'ENTER http=$httpPort socks=$socksPort',
      'ENTER http=$httpPort socks=$socksPort',
    );
    try {
      final services = await activeServices();
      _netLog(
        'enableSystemProxy',
        'snapshots 清空,开始记录原状态',
        'snapshots cleared, start recording original state',
      );
      _snapshots.clear();
      for (final service in services) {
        final web = await _endpoint(service, '-getwebproxy');
        final sw = await _endpoint(service, '-getsecurewebproxy');
        final sk = await _endpoint(service, '-getsocksfirewallproxy');
        _netLog(
          'enableSystemProxy',
          'snapshot[$service] web=$web secure=$sw socks=$sk',
          'snapshot[$service] web=$web secure=$sw socks=$sk',
        );
        _snapshots.add(
          MacNetworkSnapshot(
            service: service,
            web: web,
            secureWeb: sw,
            socks: sk,
          ),
        );
      }
      await _persistRecovery('systemProxy');
      _netLog(
        'enableSystemProxy',
        '开始 set 代理',
        'start setting proxy',
      );
      // 直接用 networksetup 进程设代理,不经过 osascript + sudo。
      for (final service in services) {
        _netLog(
          'enableSystemProxy',
          '-- service=$service --',
          '-- service=$service --',
        );
        await _runNetworksetup([
          '-setwebproxy',
          service,
          '127.0.0.1',
          '$httpPort',
        ]);
        await _runNetworksetup([
          '-setsecurewebproxy',
          service,
          '127.0.0.1',
          '$httpPort',
        ]);
        await _runNetworksetup([
          '-setsocksfirewallproxy',
          service,
          '127.0.0.1',
          '$socksPort',
        ]);
        await _runNetworksetup(['-setwebproxystate', service, 'on']);
        await _runNetworksetup(['-setsecurewebproxystate', service, 'on']);
        await _runNetworksetup(['-setsocksfirewallproxystate', service, 'on']);
      }
      _netLog(
        'enableSystemProxy',
        'OK,所有 service 都 set 完',
        'OK, all services set',
      );
      _setMode(DesktopNetworkMode.systemProxy);
      _setLastError(null);
    } catch (error, stack) {
      // 把具体哪一步失败抛到上层,不要让底层 throw 出空 StateError
      // (例如 networksetup 失败时 stderr 可能是空)
      _netLog(
        'enableSystemProxy',
        'enableSystemProxy 失败：$error',
        'enableSystemProxy failed: $error',
      );
      _netLog(
        'enableSystemProxy',
        '调用栈：$stack',
        'stack: $stack',
      );
      _setLastError(
        AppLog.pick('启用系统代理失败：$error', 'Failed to enable system proxy: $error'),
      );
      throw StateError(
        AppLog.pick(
          '启用系统代理失败 ($httpPort/$socksPort)：$error',
          'Failed to enable system proxy ($httpPort/$socksPort): $error',
        ),
      );
    }
  }

  @override
  Future<void> restore() async {
    if (_tunPid != null) {
      await disableTun();
    }
    if (!Platform.isMacOS || _snapshots.isEmpty) {
      _setMode(DesktopNetworkMode.off);
      await _clearRecovery();
      return;
    }
    final failures = <String>[];
    for (final snapshot in _snapshots) {
      for (final operation
          in <({String set, String state, MacProxyEndpoint endpoint})>[
        (
          set: '-setwebproxy',
          state: '-setwebproxystate',
          endpoint: snapshot.web,
        ),
        (
          set: '-setsecurewebproxy',
          state: '-setsecurewebproxystate',
          endpoint: snapshot.secureWeb,
        ),
        (
          set: '-setsocksfirewallproxy',
          state: '-setsocksfirewallproxystate',
          endpoint: snapshot.socks,
        ),
      ]) {
        try {
          await _restoreOne(
            snapshot,
            operation.set,
            operation.state,
            operation.endpoint,
          );
        } catch (error) {
          failures.add('${snapshot.service} ${operation.state}: $error');
        }
      }
    }
    if (failures.isNotEmpty) {
      final detail = failures.join('\n');
      _setLastError(
        AppLog.pick('恢复 macOS 系统代理失败：\n$detail', 'Failed to restore macOS system proxy:\n$detail'),
      );
      // 保留快照与 recovery 文件，下一次启动仍可继续恢复。
      throw StateError(detail);
    }
    _snapshots.clear();
    _setMode(DesktopNetworkMode.off);
    await _clearRecovery();
  }

  Future<void> _restoreOne(
    MacNetworkSnapshot snapshot,
    String setOp,
    String stateOp,
    MacProxyEndpoint? endpoint,
  ) async {
    if (endpoint == null) {
      await _runNetworksetup([stateOp, snapshot.service, 'off']);
      return;
    }
    // 原本就没开代理(endpoint.enabled=false 或 server/port 为空),
    // 只 set state off 即可,不要再 set 空 server/port,否则 networksetup
    // 会报 "The parameters were not valid." 整个 restore 链路就会断。
    if (!endpoint.enabled || endpoint.server.isEmpty || endpoint.port <= 0) {
      _netLog(
        'restoreOne',
        '${snapshot.service} $stateOp 原本未开,只关 state',
        '${snapshot.service} $stateOp was off, only turning off state',
      );
      await _runNetworksetup([stateOp, snapshot.service, 'off']);
      return;
    }
    _netLog(
      'restoreOne',
      '${snapshot.service} $setOp ${endpoint.server}:${endpoint.port} '
          'was=${endpoint.enabled ? 'on' : 'off'}',
      '${snapshot.service} $setOp ${endpoint.server}:${endpoint.port} '
          'was=${endpoint.enabled ? 'on' : 'off'}',
    );
    await _runNetworksetup([
      setOp,
      snapshot.service,
      endpoint.server,
      '${endpoint.port}',
    ]);
    await _runNetworksetup([
      stateOp,
      snapshot.service,
      endpoint.enabled ? 'on' : 'off',
    ]);
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
    if (!Platform.isMacOS) return;
    _netLog(
      'enableTun',
      'ENTER base=$baseConfigPath support=$supportPath',
      'ENTER base=$baseConfigPath support=$supportPath',
    );
    try {
      // 永久 setuid helper 已移除。每次启动只对固定的打包 mihomo
      // 执行一次明确的管理员操作，避免留下可被任意本地用户调用的 root 入口。
      await recover();
      final base = await File(baseConfigPath).readAsString();
      _netLog(
        'enableTun',
        '已读 base config, length=${base.length}',
        'read base config, length=${base.length}',
      );
      final runtime = File('$supportPath/runtime-macos-tun.yaml');
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
      _netLog(
        'enableTun',
        '已写 runtime-macos-tun.yaml',
        'wrote runtime-macos-tun.yaml',
      );
      // mihomo binary 路径:bundle/Contents/Resources/mihomo
      final mihomoBin = File(
        '${File(Platform.resolvedExecutable).parent.parent.path}/Resources/mihomo',
      );
      if (!mihomoBin.existsSync()) {
        throw StateError(
          'mihomo binary 未找到:${mihomoBin.path}\n'
          '请跑 tools/download_mihomo.sh 下载后重 build',
        );
      }
      _netLog(
        'enableTun',
        'mihomo 路径=${mihomoBin.path}',
        'mihomo path=${mihomoBin.path}',
      );
      await const MihomoGeodataInstaller().ensureInstalled(
        bundledResourceDirectory: mihomoBin.parent,
        supportDirectory: Directory(supportPath),
      );
      _netLog(
        'enableTun',
        'mihomo 地理数据库已就绪',
        'mihomo geodata ready',
      );
      final log = File('$supportPath/macos-tun.log');
      _baselineUtun = await _listUtunInterfaces();
      _tunControllerPort = controllerPort;
      final output = await _runAdministrator(
        '/usr/bin/nohup ${_shellQuote(mihomoBin.path)} '
        '-d ${_shellQuote(supportPath)} -f ${_shellQuote(runtime.path)} '
        '>> ${_shellQuote(log.path)} 2>&1 < /dev/null & /bin/echo \$!',
      );
      final tunPid = int.tryParse(output.trim().split(RegExp(r'\s+')).last);
      if (tunPid == null || tunPid <= 0) {
        throw StateError('管理员启动未返回有效 mihomo PID：$output');
      }
      _tunPid = tunPid;
      _tunIdentity = await _readProcessIdentityWithRetry(
        tunPid,
        mihomoBin.path,
      );
      _netLog(
        'enableTun',
        'mihomo pid=$tunPid, 等待 controller $controllerPort 上线',
        'mihomo pid=$tunPid, waiting for controller $controllerPort to come up',
      );

      await _persistRecovery('tun');

      // 等 mihomo controller API 起来,最多 15s
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(deadline)) {
        try {
          final socket = await Socket.connect(
            InternetAddress.loopbackIPv4,
            controllerPort,
            timeout: const Duration(milliseconds: 500),
          );
          socket.destroy();
          final boundPid = _findPidBoundToPort(controllerPort) ?? tunPid;
          _tunPid = boundPid;
          _tunIdentity = await _readProcessIdentityWithRetry(
            boundPid,
            mihomoBin.path,
          );
          await _persistRecovery('tun');
          _netLog(
            'enableTun',
            'OK mihomo controller $controllerPort 上线, _tunPid=$_tunPid',
            'OK mihomo controller $controllerPort is up, _tunPid=$_tunPid',
          );
          _setMode(DesktopNetworkMode.tun);
          _setLastError(null);
          return;
        } catch (e, s) {
          // mihomo 启动失败/异常退出时,及时清理
          debugPrint('mac_network_service.enableTun validate: $e\n$s');
          if (!await _pidAlive(tunPid)) {
            _netLog(
              'enableTun',
              'FAIL mihomo 启动后立即退出, pid=$tunPid',
              'FAIL mihomo exited immediately after start, pid=$tunPid',
            );
            _setMode(DesktopNetworkMode.off);
            throw StateError('mihomo 启动后立即退出,请查看 $supportPath/macos-tun.log');
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      await disableTun();
      _netLog(
        'enableTun',
        'FAIL 等待 $controllerPort 端口超时',
        'FAIL timeout waiting for port $controllerPort',
      );
      throw StateError('mihomo 启动超时,请查看 $supportPath/macos-tun.log');
    } catch (error, stack) {
      _netLog(
        'enableTun',
        'enableTun 失败：$error',
        'enableTun failed: $error',
      );
      _netLog(
        'enableTun',
        '调用栈：$stack',
        'stack: $stack',
      );
      rethrow;
    }
  }

  /// 用 lsof 找哪个进程绑定指定端口，用于确认控制端口属于刚启动的 mihomo。
  int? _findPidBoundToPort(int port) {
    try {
      final result = Process.runSync('/usr/sbin/lsof', [
        '-nP',
        '-iTCP:$port',
        '-sTCP:LISTEN',
        '-t',
      ]);
      if (result.exitCode != 0) return null;
      final text = result.stdout.toString().trim();
      if (text.isEmpty) return null;
      return int.tryParse(text.split(RegExp(r'\s+')).first);
    } catch (e, s) {
      debugPrint('mac_network_service.readPid: $e\n$s');
      return null;
    }
  }

  @override
  Future<void> disableTun() async {
    final pid = _tunPid;
    if (pid != null && await _pidAlive(pid)) {
      final identity = _tunIdentity;
      if (identity == null || !await _matchesProcessIdentity(identity)) {
        final message = AppLog.pick(
          '拒绝终止 PID $pid：进程身份与恢复记录不一致',
          'Refused to kill PID $pid: process identity does not match recovery record',
        );
        _setLastError(message);
        throw StateError(message);
      }
      _netLog(
        'disableTun',
        'try SIGTERM pid=$pid via administrator',
        'try SIGTERM pid=$pid via administrator',
      );
      await _runAdministrator('/bin/kill -TERM $pid 2>/dev/null || true');
      if (!await _waitForProcessExit(pid, const Duration(seconds: 4))) {
        _netLog(
          'disableTun',
          'TERM 4s 内未退出, 使用 SIGKILL',
          'TERM did not exit within 4s, using SIGKILL',
        );
        await _runAdministrator('/bin/kill -KILL $pid 2>/dev/null || true');
        if (!await _waitForProcessExit(pid, const Duration(seconds: 2))) {
          throw StateError('TUN 核心进程 $pid 在 SIGKILL 后仍未退出');
        }
      }
    }
    await _verifyTunCleanup();
    _tunPid = null;
    _tunIdentity = null;
    _baselineUtun = const [];
    _setMode(DesktopNetworkMode.off);
    await _clearRecovery();
  }

  /// 检查 PID 是否仍存在；存在则等待 [timeout] 让它自然退出。
  Future<bool> _waitForProcessExit(int pid, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!await _pidAlive(pid)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return !await _pidAlive(pid);
  }

  Future<bool> _pidAlive(int pid) async {
    try {
      // TUN 核心属于 root；普通用户对它执行 kill -0 会得到 EPERM，
      // 因此使用 ps 查询而不是把"无信号权限"误判为进程已经退出。
      final result = await Process.run('/bin/ps', ['-p', '$pid', '-o', 'pid=']);
      return result.exitCode == 0 && result.stdout.toString().trim() == '$pid';
    } catch (e, s) {
      debugPrint('mac_network_service.pidAlive ps failed for $pid: $e\n$s');
      return false;
    }
  }

  Future<MacProcessIdentity> _readProcessIdentity(
    int pid,
    String executable,
  ) async {
    final command = await Process.run('/bin/ps', [
      '-p',
      '$pid',
      '-o',
      'command=',
    ]);
    final started = await Process.run('/bin/ps', [
      '-p',
      '$pid',
      '-o',
      'lstart=',
    ]);
    final commandLine = command.stdout.toString().trim();
    final startToken = started.stdout.toString().trim();
    if (command.exitCode != 0 ||
        started.exitCode != 0 ||
        commandLine.isEmpty ||
        startToken.isEmpty ||
        !commandLine.startsWith(executable)) {
      throw StateError('PID $pid 不是预期的打包 mihomo：$commandLine');
    }
    return MacProcessIdentity(
      pid: pid,
      executable: executable,
      startToken: startToken,
    );
  }

  Future<MacProcessIdentity> _readProcessIdentityWithRetry(
    int pid,
    String executable,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        return await _readProcessIdentity(pid, executable);
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    throw StateError('无法确认 mihomo 进程身份：$lastError');
  }

  Future<bool> _matchesProcessIdentity(MacProcessIdentity expected) async {
    if (!await _pidAlive(expected.pid)) return false;
    try {
      final current = await _readProcessIdentity(
        expected.pid,
        expected.executable,
      );
      return current.startToken == expected.startToken;
    } catch (e, s) {
      debugPrint('mac_network_service.verifyProcess pid=${expected.pid}: $e\n$s');
      return false;
    }
  }

  Future<List<String>> _listUtunInterfaces() async {
    final result = await Process.run('/sbin/ifconfig', const ['-l']);
    if (result.exitCode != 0) return const [];
    return result.stdout
        .toString()
        .trim()
        .split(RegExp(r'\s+'))
        .where((name) => name.startsWith('utun'))
        .toList();
  }

  Future<bool> _controllerPortOpen(int port) async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 250),
      );
      socket.destroy();
      return true;
    } catch (e, s) {
      debugPrint('mac_network_service._controllerPortOpen port=$port: $e\n$s');
      return false;
    }
  }

  Future<void> _verifyTunCleanup() async {
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    List<String> unexpected = const [];
    var portOpen = false;
    do {
      final current = await _listUtunInterfaces();
      unexpected = current
          .where((name) => !_baselineUtun.contains(name))
          .toList();
      portOpen = await _controllerPortOpen(_tunControllerPort);
      if (unexpected.isEmpty && !portOpen) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    } while (DateTime.now().isBefore(deadline));
    final detail = [
      if (portOpen)
        AppLog.pick('控制端口 $_tunControllerPort 仍在监听', 'control port $_tunControllerPort still listening'),
      if (unexpected.isNotEmpty)
        AppLog.pick('残留虚拟网卡：${unexpected.join(', ')}', 'residual virtual NICs: ${unexpected.join(', ')}'),
    ].join('；');
    final message = AppLog.pick('TUN 清理未完成：$detail', 'TUN cleanup incomplete: $detail');
    _setLastError(message);
    throw StateError(message);
  }

  @override
  Future<bool> isHealthy({int controllerPort = 9090}) async {
    if (mode != DesktopNetworkMode.tun) return true;
    final identity = _tunIdentity;
    return identity != null &&
        await _matchesProcessIdentity(identity) &&
        await _controllerPortOpen(controllerPort);
  }

  Future<File> _recoveryStateFile() async {
    if (_recoveryFile != null) return _recoveryFile!;
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    return _recoveryFile = File(
      '$home/Library/Application Support/Clash RS/network-recovery.json',
    );
  }

  Future<void> _persistRecovery(String currentMode) async {
    final file = await _recoveryStateFile();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'version': 1,
        'mode': currentMode,
        'tunPid': _tunPid,
        'processIdentity': _tunIdentity?.toJson(),
        'baselineUtun': _baselineUtun,
        'controllerPort': _tunControllerPort,
        'snapshots': _snapshots.map((item) => item.toJson()).toList(),
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<void> _clearRecovery() async {
    final file = await _recoveryStateFile();
    if (await file.exists()) await file.delete();
  }

  static MacNetworkSnapshot _snapshotFromJson(Map<dynamic, dynamic> json) =>
      MacNetworkSnapshot(
        service: json['service']?.toString() ?? '',
        web: _endpointFromJson(json['web']),
        secureWeb: _endpointFromJson(json['secureWeb']),
        socks: _endpointFromJson(json['socks']),
      );

  static MacProxyEndpoint _endpointFromJson(dynamic value) {
    final json = value is Map ? value : const {};
    return MacProxyEndpoint(
      enabled: json['enabled'] == true,
      server: json['server']?.toString() ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
    );
  }

  Future<MacProxyEndpoint> _endpoint(String service, String operation) async {
    _netLog('endpoint', '$operation $service', '$operation $service');
    final result = await Process.run('/usr/sbin/networksetup', [
      operation,
      service,
    ]);
    if (result.exitCode != 0) {
      _netLog(
        'endpoint',
        'FAIL exit=${result.exitCode} stderr=${result.stderr} stdout=${result.stdout}',
        'FAIL exit=${result.exitCode} stderr=${result.stderr} stdout=${result.stdout}',
      );
      throw StateError(result.stderr.toString().trim());
    }
    final ep = parseMacProxyEndpoint(result.stdout.toString());
    _netLog('endpoint', 'OK $ep', 'OK $ep');
    return ep;
  }

  Future<String> _runAdministrator(String command) async {
    _netLog('runAdministrator', 'CALL $command', 'CALL $command');
    final escaped = command.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    final result = await Process.run('/usr/bin/osascript', [
      '-e',
      'do shell script "$escaped" with administrator privileges',
    ]);
    if (result.exitCode != 0) {
      // exitCode != 0 但 stderr 可能为空(比如用户在授权弹窗里点了"取消")。
      // 带上 exit code + stdout/stderr 拼成可读消息,避免上层看到 Bad state: 空。
      final stderr = result.stderr.toString().trim();
      final stdout = result.stdout.toString().trim();
      _netLog(
        'runAdministrator',
        'FAIL exit=${result.exitCode} stderr=${stderr.isEmpty ? '<空>' : stderr} '
            'stdout=${stdout.isEmpty ? '<空>' : stdout}',
        'FAIL exit=${result.exitCode} stderr=${stderr.isEmpty ? '<empty>' : stderr} '
            'stdout=${stdout.isEmpty ? '<empty>' : stdout}',
      );
      final detail = stderr.isNotEmpty
          ? stderr
          : (stdout.isNotEmpty
                ? stdout
                : 'osascript 退出码 ${result.exitCode}(用户可能取消了授权)');
      throw StateError(detail);
    }
    _netLog(
      'runAdministrator',
      'OK -> ${result.stdout.toString().trim()}',
      'OK -> ${result.stdout.toString().trim()}',
    );
    return result.stdout.toString();
  }

  /// 直接调 networksetup(不通过 sudo),现代 macOS 上设置自己的网络服务
  /// 代理偏好不需要管理员权限,可以避免无谓的授权弹窗。
  /// 失败时抛 StateError 并带上 stderr 让上层能定位。
  Future<String> _runNetworksetup(List<String> argList) async {
    _netLog('networksetup', 'CALL ${argList.join(' ')}', 'CALL ${argList.join(' ')}');
    final result = await Process.run('/usr/sbin/networksetup', argList);
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      final stdout = result.stdout.toString().trim();
      _netLog(
        'networksetup',
        'FAIL exit=${result.exitCode} stderr=${stderr.isEmpty ? '<空>' : stderr} '
            'stdout=${stdout.isEmpty ? '<空>' : stdout}',
        'FAIL exit=${result.exitCode} stderr=${stderr.isEmpty ? '<empty>' : stderr} '
            'stdout=${stdout.isEmpty ? '<empty>' : stdout}',
      );
      final detail = stderr.isNotEmpty
          ? stderr
          : (stdout.isNotEmpty
                ? stdout
                : 'networksetup 退出码 ${result.exitCode}');
      throw StateError('networksetup ${argList.join(' ')} 失败：$detail');
    }
    _netLog('networksetup', 'OK', 'OK');
    return result.stdout.toString();
  }

  static String _shellQuote(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";
}
