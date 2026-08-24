import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/ffi/clash_bridge.dart';
import '../core/ffi/clash_controller.dart';
import '../core/vpn/vpn_controller.dart';
import '../models/app_settings.dart';
import '../models/ip_info.dart';
import '../models/proxy_profile.dart';
import 'home_layout.dart';
import 'mihomo_client.dart';
import 'mihomo_geodata_installer.dart';
import 'profile_import_service.dart';
import 'profile_proxy_catalog.dart';
import 'profile_repository.dart';
import 'refresh_diff.dart';
import 'settings_repository.dart';
import 'theme_controller.dart';
import 'update_checker.dart';

class UrlProbeResult {
  final bool ok;
  final int latencyMs;
  final int? statusCode;
  final String path;
  final String? error;

  const UrlProbeResult({
    required this.ok,
    required this.latencyMs,
    required this.path,
    this.statusCode,
    this.error,
  });
}

IpInfo parseIpInfoPayload(Map<String, dynamic> json) {
  final connection = json['connection'] is Map
      ? Map<String, dynamic>.from(json['connection'] as Map)
      : const <String, dynamic>{};
  final timezoneValue = json['timezone'];
  final timezone = timezoneValue is Map
      ? timezoneValue['id']?.toString() ?? ''
      : timezoneValue?.toString() ?? '';
  var asn = (json['asn'] ?? connection['asn'] ?? json['as'] ?? '').toString();
  if (asn.isNotEmpty && !asn.toUpperCase().startsWith('AS')) asn = 'AS$asn';
  return IpInfo(
    countryCode: (json['country_code'] ?? json['countryCode'] ?? '').toString(),
    countryName: (json['country_name'] ?? json['country'] ?? '').toString(),
    ip: (json['ip'] ?? json['query'] ?? '').toString(),
    asn: asn.replaceFirst(RegExp(r'^ASAS', caseSensitive: false), 'AS'),
    isp: (json['isp'] ?? connection['isp'] ?? '').toString(),
    org: (json['org'] ?? connection['org'] ?? '').toString(),
    timezone: timezone,
    lat: _asDouble(json['latitude'] ?? json['lat']),
    lng: _asDouble(json['longitude'] ?? json['lon']),
    fetchedAt: DateTime.now(),
    loading: false,
  );
}

double? _asDouble(Object? value) => value is num ? value.toDouble() : null;

class ProxyAppController extends ChangeNotifier {
  /// 全局主题/语言控制器。允许注入以便测试。
  final ThemeController themeController;
  ProxyAppController({
    ThemeController? themeController,
    @visibleForTesting ClashController? controllerForTesting,
    @visibleForTesting
    this.selectedNodeHealthInterval = const Duration(seconds: 15),
  }) : themeController = themeController ?? ThemeController.instance,
       _controller = controllerForTesting;

  final Duration selectedNodeHealthInterval;

  /// 自动检查更新器（启动后台运行）。
  final UpdateChecker updateChecker = UpdateChecker();
  UpdateInfo? get updateInfo => updateChecker.lastResult;

  ClashBridge? _bridge; // 桌面端为 null(走 mihomo HTTP API)
  final VpnController _vpn = VpnController.instance;
  final ProfileImportService importer = ProfileImportService();
  final ProfileProxyCatalog _profileProxyCatalog = const ProfileProxyCatalog();

  ProfileRepository? _repository;
  SettingsRepository? _settingsRepository;
  ClashController? _controller;
  Process? _desktopCoreProcess;
  Timer? _trafficTimer;
  Timer? _selectedNodeHealthTimer;
  Timer? _profileUpdateTimer;
  Timer? _desktopRestartTimer;
  StreamSubscription<Map<String, dynamic>>? _coreLogSubscription;
  bool _refreshingProfiles = false;
  bool _trafficPolling = false;
  bool _memoryPolling = false;
  bool _connectionsPolling = false;
  bool _disposed = false;
  int _externalEngineFailureCount = 0;
  bool _externalRecoverySignaled = false;
  String? _lastTrafficPollError;
  bool _restartScheduled = false;
  int _desktopRestartAttempts = 0;
  int _delayGeneration = 0;

  bool ready = false;
  bool busy = false;
  bool engineRunning = false;
  bool vpnRunning = false;
  bool externalEngineRunning = false;
  bool checkingDelays = false;
  final Set<String> _checkingNodeDelays = <String>{};
  String version = '...';
  String? error;
  String? supportPath;
  List<ProxyProfile> profiles = const [];
  Map<String, ProxyGroup> groups = const {};
  String? selectedGroup;
  Map<String, int> delays = const {};
  List<Map<String, dynamic>> connections = const [];
  int connectionUploadTotal = 0;
  int connectionDownloadTotal = 0;
  List<Map<String, dynamic>> rules = const [];
  String proxyMode = 'rule';
  int totalUp = 0;
  int totalDown = 0;
  int uploadSpeed = 0;
  int downloadSpeed = 0;
  int memoryMb = 0;
  int ruleCount = 0;
  DateTime? startedAt;
  // 启动时间
  String engineVersion = 'mihomo';
  final List<TrafficStats> trafficHistory = [];
  final List<String> logs = [];
  IpInfo _ipInfo = const IpInfo();
  IpInfo get ipInfo => _ipInfo;
  Timer? _ipRefreshTimer;
  int? _ipInfoProxyPort;
  int _ipInfoRefreshGeneration = 0;

  /// DesktopApp 注入的 TUN 恢复入口。连续 API 失败时只触发一次，
  /// 由网络服务负责重新取得管理员权限和重建路由。
  Future<void> Function()? onExternalEngineLost;

  /// 下一次 IP 刷新的目标时间，用于首页倒计时显示。
  DateTime? _nextIpRefreshAt;
  DateTime? get nextIpRefreshAt => _nextIpRefreshAt;
  AppSettings settings = AppSettings.defaults;

  /// 桌面核心、TUN、API 客户端和诊断共用的唯一控制端口。
  int get controllerPort =>
      int.tryParse(settings.overrides['controller-port'] ?? '') ?? 9090;

  int get httpPort => int.tryParse(settings.overrides['port'] ?? '') ?? 17890;

  String get configurationDirectory => activeProfile == null
      ? '${supportPath ?? Directory.systemTemp.path}/profiles'
      : File(activeProfile!.localYamlPath).parent.path;

  String get coreDirectory {
    final executable = File(Platform.resolvedExecutable);
    return Platform.isMacOS
        ? '${executable.parent.parent.path}/Resources'
        : executable.parent.path;
  }

  String get logDirectory {
    final home = Platform.environment['HOME'];
    if (Platform.isMacOS && home != null) return '$home/Library/Logs/ClashRS';
    return '${supportPath ?? Directory.systemTemp.path}/logs';
  }

  /// 最近一次刷新失败时间（key = profile.id），UI 用来显示"上次刷新失败"。
  final Map<String, DateTime> _refreshErrors = {};
  final Map<String, int> _refreshFailureCounts = {};
  final Map<String, DateTime> _refreshRetryAt = {};

  /// 最近一次刷新 diff（key = profile.id），UI 用来显示变更摘要。
  final Map<String, RefreshDiff> _refreshDiffs = {};

  /// 桌面端 engine 启动等待超时。
  static const _engineStartTimeout = Duration(seconds: 15);

  /// 从设置收集所有需要预检的端口（含外部控制端口）。
  Map<String, int> _collectPorts() {
    final out = <String, int>{};
    final overrides = settings.overrides;
    out['port'] = int.tryParse(overrides['port'] ?? '') ?? 17890;
    out['socks-port'] = int.tryParse(overrides['socks-port'] ?? '') ?? 17891;
    final mixed = int.tryParse(overrides['mixed-port'] ?? '');
    if (mixed != null) out['mixed-port'] = mixed;
    out['controller-port'] = controllerPort;
    return out;
  }

  /// 用 TCP connect 探活：能 connect 上 = 端口被占。
  Future<bool> _isPortInUse(int port) async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 250),
      );
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 轮询等 [port] 被占用（即有 listener 已绑定），最多 [timeout]。
  /// 用于 engine 启动后等 external-controller HTTP 服务可连通。
  Future<bool> _waitForControllerPortReady(
    int port, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _isPortInUse(port)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  /// 测试用入口:等价于 [_waitForControllerPortReady]。
  @visibleForTesting
  Future<bool> waitForControllerPortReadyForTest(
    int port, {
    Duration timeout = const Duration(seconds: 5),
  }) => _waitForControllerPortReady(port, timeout: timeout);

  bool get isRunning => engineRunning && (!Platform.isAndroid || vpnRunning);
  ProxyProfile? get activeProfile {
    for (final profile in profiles) {
      if (profile.active) return profile;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  /// UI 查询：某个 profile 最近一次刷新是否失败。
  DateTime? lastRefreshError(String profileId) => _refreshErrors[profileId];

  /// UI 查询：某个 profile 最近一次刷新的 diff 摘要。
  RefreshDiff? lastRefreshDiff(String profileId) => _refreshDiffs[profileId];

  Future<void> initialize() async {
    if (ready) return;
    try {
      final support = await getApplicationSupportDirectory();
      supportPath = support.path;
      if (!Platform.isAndroid) await _recoverDesktopCore(support);
      final legacy = File('${support.path}/config.yaml');
      if (!await legacy.exists()) {
        await legacy.writeAsString(
          ProfileRepository.defaultConfig,
          flush: true,
        );
      }
      _repository = ProfileRepository(support);
      _settingsRepository = SettingsRepository(support);
      settings = await _settingsRepository!.load();
      if (!Platform.isAndroid) await _applyDesktopBehavior(settings);
      // 启动后把 settings 主题/语言同步到 ThemeController
      await themeController.applyDarkMode(settings.darkMode);
      await themeController.setLanguage(settings.language);
      proxyMode = settings.meta['proxyMode'] ?? 'rule';
      selectedGroup = settings.meta['selectedGroup'];
      profiles = await _repository!.initialize();
      await _loadOfflineGroups();
      _configureController();
      // 桌面端 (macOS / Windows):不走 core-bridge FFI,
      // 由 mac_network_service 通过 helper + mihomo 启核心。
      // 详见 _startDesktop() / networkService.start。
      if (Platform.isAndroid) {
        _bridge = ClashBridge.instance;
        version = _bridge!.version();
        _bridge!.init(homeDir: support.path, version: version, sdk: 36);
        engineRunning = _bridge!.engineIsRunning();
      } else {
        version = 'mihomo';
        await _refreshDesktopEngineVersion();
      }
      if (Platform.isAndroid) {
        await _vpn.applyAppBehavior(
          hideLauncher: settings.hideLauncher,
          hideRecents: settings.hideRecents,
        );
        final status = await _vpn.status();
        vpnRunning = status.serviceRunning;
        if (engineRunning != vpnRunning) {
          if (engineRunning) _bridge!.engineStop();
          if (vpnRunning) await _vpn.stop();
          engineRunning = false;
          vpnRunning = false;
        }
      }
      if (!Platform.isAndroid) await _applyDesktopBehavior(settings);
      if (isRunning) {
        await refreshGroups();
        _startTrafficTimer();
        _startSelectedNodeHealthMonitor();
      }
      _startProfileUpdateTimer();
      startIpRefreshTimer();
      _log('应用初始化完成，核心 $version');
      // 后台检查更新
      unawaited(_checkUpdatesInBackground());
    } catch (exception) {
      error = exception.toString();
      _log('初始化失败：$error');
    }
    ready = true;
    notifyListeners();
  }

  Future<void> toggle() => isRunning ? stop() : start();

  Future<void> start() async {
    final profile = activeProfile;
    if (busy || profile == null || supportPath == null) return;

    // 桌面端 (macOS / Windows):系统代理模式直接托管 mihomo；TUN 模式
    // 由平台网络服务启动提权后的 mihomo，两者统一使用 9090 控制 API。
    final isDesktop = !Platform.isAndroid;
    if (isDesktop) {
      await _startDesktop(profile);
      return;
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      // 启动前预检：1) engine 不应已经在跑（防止双实例）
      if (!Platform.isAndroid && (_bridge?.engineIsRunning() ?? false)) {
        throw StateError('代理核心已经在运行，请先停止');
      }
      // 2) 端口冲突检测
      final ports = _collectPorts();
      for (final entry in ports.entries) {
        if (await _isPortInUse(entry.value)) {
          throw StateError('端口 ${entry.value}（${entry.key}）已被占用，请先释放或调整设置');
        }
      }
      var configPath = profile.localYamlPath;
      int? tunFd;
      if (Platform.isAndroid) {
        await _vpn.prepare();
        final mixedPort =
            int.tryParse(settings.overrides['mixed-port'] ?? '') ?? 17892;
        tunFd = await _vpn.establish(
          VpnStartOptions(
            autoRoute: settings.autoRoute,
            bypassPrivate: settings.bypassPrivate,
            allowBypass: settings.allowBypass,
            ipv6: settings.ipv6,
            systemProxy: settings.systemProxy,
            mixedPort: mixedPort,
            accessMode: settings.accessMode,
            accessPackages: settings.accessPackages,
          ),
        );
        final base = await File(profile.localYamlPath).readAsString();
        final runtime = File(
          '${File(profile.localYamlPath).parent.path}/runtime-config.yaml',
        );
        await runtime.writeAsString(
          buildRuntimeVpnConfig(
            base,
            tunFd,
            dnsHijack: settings.dnsHijack,
            ipv6: settings.ipv6,
            stackMode: settings.stackMode,
            overrides: settings.overrides,
            meta: settings.meta,
          ),
          flush: true,
        );
        configPath = runtime.path;
      } else {
        final base = await File(profile.localYamlPath).readAsString();
        final runtime = File(
          '${File(profile.localYamlPath).parent.path}/runtime-desktop.yaml',
        );
        await runtime.writeAsString(
          buildRuntimeDesktopConfig(
            base,
            overrides: settings.overrides,
            mode: proxyMode,
            allowLan: settings.allowLan,
            ipv6: settings.ipv6,
            dnsEnabled: settings.dnsEnabled,
            unifiedDelay: settings.unifiedDelay,
            logLevel: settings.logLevel,
            merge: settings.meta['extension.merge'] ?? '',
            script: settings.meta['extension.script'] ?? '',
          ),
          flush: true,
        );
        configPath = runtime.path;
      }
      await _ensureControllerPortAvailable();
      final rc = _bridge!.engineStart(
        configPath: configPath,
        cwd: supportPath!,
      );
      if (rc != 0) {
        throw StateError('启动失败：${_bridge!.lastErrorMessage(rc)}');
      }
      if (Platform.isAndroid) await _vpn.commitFd(tunFd!);
      final deadline = DateTime.now().add(_engineStartTimeout);
      do {
        engineRunning = _bridge!.engineIsRunning();
        if (engineRunning) break;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } while (DateTime.now().isBefore(deadline));
      if (!engineRunning) {
        // 启动失败时尝试读取 FFI 错误信息
        final reason = _bridge!.engineStatus();
        throw StateError(
          '核心未在 ${_engineStartTimeout.inSeconds}s 内启动${reason == null ? '' : '：$reason'}',
        );
      }
      vpnRunning = !Platform.isAndroid || (await _vpn.status()).serviceRunning;
      // FFI 的 RUNNING 标志会在子线程一进入就置 true，但 external-controller
      // HTTP listener 还要时间绑端口；这里轮询等端口起来再调 /proxies，
      // 否则 refreshGroups 会在 connection refused 时被静默吞掉，导致 groups
      // 留空而误报"未通过启动检查"。
      if (_controller != null) {
        final controllerReady = await _waitForControllerPortReady(
          controllerPort,
          timeout: const Duration(seconds: 5),
        );
        if (!controllerReady) {
          throw StateError(
            '外部控制器未在 5s 内就绪（127.0.0.1:$controllerPort）；'
            '请检查配置中的 external-controller / secret 设置',
          );
        }
      }
      try {
        await refreshGroups();
      } catch (exception) {
        throw StateError('读取代理组失败：$exception');
      }
      if (!isRunning || groups.isEmpty) {
        throw StateError('核心或系统 VPN 未通过启动检查');
      }
      // 恢复保存的代理模式 + 节点选择
      await _restoreRuntimePreferences();
      _startTrafficTimer();
      _startSelectedNodeHealthMonitor();
      startedAt = DateTime.now();
      await _runStartupScript();
      _log('已启动：${profile.name}');
    } catch (exception) {
      error = exception.toString();
      if (_bridge?.engineIsRunning() ?? false) _bridge!.engineStop();
      if (Platform.isAndroid) await _vpn.stop().catchError((_) {});
      engineRunning = false;
      vpnRunning = false;
      _log('启动失败：$error');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// 桌面普通模式启动 mihomo。系统代理随后只负责把 OS 代理指向本地端口。
  Future<void> _startDesktop(ProxyProfile profile) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      _log('桌面端启动：profile=${profile.name}');
      final apiSecret = _desktopApiSecret;
      final mihomo = MihomoClient(
        base: 'http://127.0.0.1:$controllerPort',
        secret: apiSecret,
      );
      if (!await mihomo.healthCheck(timeoutMs: 400)) {
        for (final entry in _desktopPorts().entries) {
          if (await _isPortInUse(entry.value)) {
            throw StateError('端口 ${entry.value}（${entry.key}）已被占用');
          }
        }
        final binary = await _findDesktopMihomo();
        if (Platform.isMacOS) {
          await const MihomoGeodataInstaller().ensureInstalled(
            bundledResourceDirectory: binary.parent,
            supportDirectory: Directory(supportPath!),
          );
          _log('mihomo 地理数据库已就绪');
        }
        final base = await File(profile.localYamlPath).readAsString();
        final runtime = File('$supportPath/runtime-desktop.yaml');
        await runtime.writeAsString(
          buildRuntimeDesktopConfig(
            base,
            overrides: {
              ...settings.overrides,
              // Subscription files may ship privileged or conflicting local
              // ports (for example 520). Desktop system proxy must always use
              // the application's configured stable listeners instead.
              'port': settings.overrides['port'] ?? '17890',
              'socks-port': settings.overrides['socks-port'] ?? '17891',
              'mixed-port': settings.overrides['mixed-port'] ?? '17892',
              'controller-port': '$controllerPort',
              // Never inherit a subscription's controller secret. The local
              // API client and generated runtime must use the same value.
              'secret': _yamlQuoted(apiSecret ?? ''),
            },
            mode: proxyMode,
            allowLan: settings.allowLan,
            ipv6: settings.ipv6,
            dnsEnabled: settings.dnsEnabled,
            unifiedDelay: settings.unifiedDelay,
            logLevel: settings.logLevel,
            merge: settings.meta['extension.merge'] ?? '',
            script: settings.meta['extension.script'] ?? '',
          ),
          flush: true,
        );
        final log = File('$supportPath/mihomo-desktop.log');
        final sink = log.openWrite(mode: FileMode.append);
        _desktopCoreProcess = await Process.start(binary.path, [
          '-d',
          supportPath!,
          '-f',
          runtime.path,
        ]);
        await _persistDesktopCorePid(_desktopCoreProcess!.pid);
        final process = _desktopCoreProcess!;
        process.stdout.listen(sink.add);
        process.stderr.listen(sink.add);
        unawaited(
          process.exitCode.then((code) async {
            await sink.close();
            if (_desktopCoreProcess?.pid != process.pid) return;
            _desktopCoreProcess = null;
            await _clearDesktopCorePid();
            if (engineRunning) {
              engineRunning = false;
              vpnRunning = false;
              error = 'mihomo 意外退出（exit=$code）';
              _log(error!);
              notifyListeners();
              _scheduleDesktopRestart();
            }
          }),
        );
        final deadline = DateTime.now().add(_engineStartTimeout);
        while (DateTime.now().isBefore(deadline) &&
            !await mihomo.healthCheck(timeoutMs: 400)) {
          final exitCode = await _desktopCoreProcess!.exitCode.timeout(
            const Duration(milliseconds: 1),
            onTimeout: () => -999,
          );
          if (exitCode != -999) {
            throw StateError('mihomo 启动后退出（exit=$exitCode），请查看 ${log.path}');
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (!await mihomo.healthCheck(timeoutMs: 800)) {
          _desktopCoreProcess?.kill(ProcessSignal.sigterm);
          _desktopCoreProcess = null;
          await _clearDesktopCorePid();
          throw StateError('mihomo 未在 ${_engineStartTimeout.inSeconds}s 内启动');
        }
      }
      engineRunning = true;
      vpnRunning = true;
      startedAt = DateTime.now();
      _configureController();
      await refreshGroups();
      await _restoreRuntimePreferences();
      _startTrafficTimer();
      _startSelectedNodeHealthMonitor();
      _startCoreLogStream();
      _desktopRestartAttempts = 0;
      await _runStartupScript();
      _log('桌面端 mihomo 已就绪：127.0.0.1:$controllerPort');
    } catch (exception) {
      final process = _desktopCoreProcess;
      _desktopCoreProcess = null;
      process?.kill(ProcessSignal.sigterm);
      await _clearDesktopCorePid();
      engineRunning = false;
      vpnRunning = false;
      error = exception.toString();
      _log('桌面端启动失败:$error');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    _trafficTimer?.cancel();
    _selectedNodeHealthTimer?.cancel();
    _desktopRestartTimer?.cancel();
    await _coreLogSubscription?.cancel();
    _coreLogSubscription = null;
    try {
      if (!externalEngineRunning && (_bridge?.engineIsRunning() ?? false)) {
        final rc = _bridge!.engineStop();
        if (rc != 0) throw StateError(_bridge!.lastErrorMessage(rc));
      }
      final desktop = _desktopCoreProcess;
      if (desktop != null) {
        _desktopCoreProcess = null;
        desktop.kill(ProcessSignal.sigterm);
        await desktop.exitCode.timeout(
          const Duration(seconds: 4),
          onTimeout: () {
            desktop.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
        await _clearDesktopCorePid();
      }
      if (Platform.isAndroid) await _vpn.stop();
      engineRunning = false;
      externalEngineRunning = false;
      _externalEngineFailureCount = 0;
      _externalRecoverySignaled = false;
      vpnRunning = false;
      totalUp = 0;
      totalDown = 0;
      uploadSpeed = 0;
      downloadSpeed = 0;
      trafficHistory.clear();
      startedAt = null;
      await _loadOfflineGroups();
      delays = const {};
      connections = const [];
      connectionUploadTotal = 0;
      connectionDownloadTotal = 0;
      rules = const [];
      error = null;
      _log('已停止代理与系统 VPN');
    } catch (exception) {
      error = exception.toString();
      _log('停止失败：$error');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> attachExternalEngine() async {
    externalEngineRunning = true;
    engineRunning = true;
    vpnRunning = true;
    error = null;
    _externalEngineFailureCount = 0;
    _externalRecoverySignaled = false;
    _configureController();
    await refreshGroups();
    _startTrafficTimer();
    _startSelectedNodeHealthMonitor();
    _startCoreLogStream();
    _log('已连接 macOS 虚拟网卡助手');
    notifyListeners();
  }

  void detachExternalEngine() {
    externalEngineRunning = false;
    engineRunning = false;
    _externalEngineFailureCount = 0;
    _externalRecoverySignaled = false;
    unawaited(_loadOfflineGroups());
    delays = const {};
    _trafficTimer?.cancel();
    _selectedNodeHealthTimer?.cancel();
    unawaited(_coreLogSubscription?.cancel());
    _coreLogSubscription = null;
    _log('macOS 虚拟网卡助手已停止');
    notifyListeners();
  }

  Future<void> refreshGroups() async {
    final controller = _controller;
    if (controller == null || !engineRunning) return;
    try {
      groups = await controller.getProxies();
      final candidates = groups.entries
          .where((entry) => entry.value.all.isNotEmpty)
          .map((entry) => entry.key)
          .toList();
      if (selectedGroup == null || !candidates.contains(selectedGroup)) {
        selectedGroup = candidates.contains('PROXY')
            ? 'PROXY'
            : (candidates.isEmpty ? null : candidates.first);
      }
      notifyListeners();
    } catch (exception) {
      error = '读取代理组失败：$exception';
      notifyListeners();
    }
  }

  Future<void> _loadOfflineGroups() async {
    final profile = activeProfile;
    if (profile == null) {
      groups = const {};
      selectedGroup = null;
      return;
    }
    try {
      groups = await _profileProxyCatalog.fromFile(profile.localYamlPath);
      final candidates = groups.keys.toList();
      if (selectedGroup == null || !candidates.contains(selectedGroup)) {
        selectedGroup = proxyMode == 'global' && candidates.contains('GLOBAL')
            ? 'GLOBAL'
            : candidates.contains('PROXY')
            ? 'PROXY'
            : (candidates.isEmpty ? null : candidates.first);
      }
      final savedNode = selectedGroup == null
          ? null
          : settings.meta['node.$selectedGroup'];
      final group = groups[selectedGroup];
      if (group != null && savedNode != null && group.all.contains(savedNode)) {
        groups = {...groups, group.name: group.copyWith(now: savedNode)};
      }
    } catch (exception) {
      groups = const {};
      selectedGroup = null;
      error = '读取订阅节点失败：$exception';
    }
  }

  void chooseGroup(String name) {
    selectedGroup = name;
    delays = const {};
    unawaited(_saveRuntimePreference('selectedGroup', name));
    notifyListeners();
    if (engineRunning) unawaited(_checkSelectedNodeHealth());
  }

  Future<void> chooseNode(String name) async {
    final group = selectedGroup;
    if (group == null) return;
    if (!engineRunning || _controller == null) {
      final current = groups[group];
      if (current == null || !current.all.contains(name)) return;
      groups = {...groups, group: current.copyWith(now: name)};
      await _saveRuntimePreference('node.$group', name);
      _log('离线节点选择：$group → $name');
      notifyListeners();
      return;
    }
    try {
      await _controller!.selectNode(group, name);
      await refreshGroups();
      await _saveRuntimePreference('node.$group', name);
      _log('节点切换：$group → $name');
      await checkNodeDelay(name);
    } catch (exception) {
      error = '节点切换失败：$exception';
      notifyListeners();
    }
  }

  /// 切换当前选中的代理组（仅更新本地偏好，重启代理时生效）。
  void selectGroup(String name) {
    if (selectedGroup == name) return;
    selectedGroup = name;
    unawaited(_saveRuntimePreference('selectedGroup', name));
    notifyListeners();
    if (engineRunning) unawaited(_checkSelectedNodeHealth());
  }

  Future<void> checkAllDelays() => _runGroupDelayTest(selectedGroup);

  /// 对任意分组做延迟测试（不限于当前选中组）。
  Future<void> checkGroupDelays(String groupName) =>
      _runGroupDelayTest(groupName);

  /// 单个 URL 测速：根据当前网络模式使用本地 HTTP 代理或 TUN。
  Future<int> probeSingleUrl(String url, {int timeoutMs = 4000}) async {
    final result = await probeUrl(url, timeoutMs: timeoutMs);
    return result.ok ? result.latencyMs : 0;
  }

  Future<UrlProbeResult> probeUrl(String url, {int timeoutMs = 4000}) async {
    final stopwatch = Stopwatch()..start();
    final proxyPort = isRunning && !externalEngineRunning
        ? (_ipInfoProxyPort ?? httpPort)
        : _ipInfoProxyPort;
    final path = proxyPort != null
        ? '系统代理 127.0.0.1:$proxyPort'
        : (isRunning && externalEngineRunning ? '虚拟网卡 TUN' : '直连');
    final client = HttpClient()
      ..connectionTimeout = Duration(milliseconds: timeoutMs)
      ..findProxy = (_) => ipInfoProxyForPort(proxyPort);
    try {
      final uri = Uri.parse(url);
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'ClashRS/1.0');
      final resp = await req.close().timeout(Duration(milliseconds: timeoutMs));
      await resp.drain<void>().timeout(Duration(milliseconds: timeoutMs));
      stopwatch.stop();
      final ok = resp.statusCode < 500;
      return UrlProbeResult(
        ok: ok,
        latencyMs: stopwatch.elapsedMilliseconds,
        statusCode: resp.statusCode,
        path: path,
        error: ok ? null : 'HTTP ${resp.statusCode}',
      );
    } catch (exception) {
      stopwatch.stop();
      return UrlProbeResult(
        ok: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        path: path,
        error: exception.toString(),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _runGroupDelayTest(String? group) async {
    if (_controller == null || group == null || checkingDelays) return;
    final groupMeta = groups[group];
    if (groupMeta == null || groupMeta.all.isEmpty) {
      error = '分组 $group 不存在或没有节点';
      notifyListeners();
      return;
    }
    checkingDelays = true;
    final generation = ++_delayGeneration;
    // 保留其他分组的延迟：只清当前测试组节点的旧延迟
    final next = {...delays};
    for (final n in groupMeta.all) {
      next.remove(n);
    }
    delays = next;
    notifyListeners();
    try {
      final result = await _controller!.healthCheckGroup(
        group,
        timeout: const Duration(seconds: 6),
      );
      if (generation != _delayGeneration) return;
      delays = {...delays, ...result};
      _log('延迟测试完成：$group（${result.length} 个节点）');
    } catch (exception) {
      error = '延迟测试失败：$exception';
    } finally {
      if (generation == _delayGeneration) checkingDelays = false;
      notifyListeners();
    }
  }

  void cancelDelayChecks() {
    _delayGeneration++;
    checkingDelays = false;
    _log('已取消延迟测试');
    notifyListeners();
  }

  bool isCheckingNodeDelay(String node) => _checkingNodeDelays.contains(node);

  /// 选中节点并立即测速。离线目录也允许直接点 Check：先启动核心，
  /// 再把该节点切为当前节点，最后通过 mihomo health-check 返回毫秒延迟。
  Future<void> selectAndCheckNode(String node) async {
    if (_checkingNodeDelays.contains(node)) return;
    if (!engineRunning) await start();
    if (!engineRunning) {
      delays = {...delays, node: -1};
      notifyListeners();
      return;
    }
    await chooseNode(node);
  }

  void _startSelectedNodeHealthMonitor() {
    _selectedNodeHealthTimer?.cancel();
    if (!engineRunning || _controller == null) return;
    unawaited(_checkSelectedNodeHealth());
    _selectedNodeHealthTimer = Timer.periodic(
      selectedNodeHealthInterval,
      (_) => unawaited(_checkSelectedNodeHealth()),
    );
  }

  Future<void> _checkSelectedNodeHealth() async {
    if (!engineRunning || _controller == null) return;
    final group = groups[selectedGroup];
    final node = group?.now;
    if (node == null ||
        node.isEmpty ||
        node == 'DIRECT' ||
        node == 'REJECT' ||
        _checkingNodeDelays.contains(node)) {
      return;
    }
    await checkNodeDelay(node);
  }

  @visibleForTesting
  void startSelectedNodeHealthMonitorForTest() =>
      _startSelectedNodeHealthMonitor();

  Future<void> checkNodeDelay(String node) async {
    final group = selectedGroup;
    if (_controller == null || group == null || !engineRunning) return;
    if (!_checkingNodeDelays.add(node)) return;
    notifyListeners();
    try {
      final delay = await _controller!.healthCheck(group, node);
      delays = {...delays, node: delay};
    } catch (exception) {
      delays = {...delays, node: -1};
      error = '节点测速失败：$node，$exception';
    } finally {
      _checkingNodeDelays.remove(node);
      notifyListeners();
    }
  }

  Future<void> refreshRuntimeDetails() async {
    final controller = _controller;
    if (controller == null || !engineRunning) return;
    await Future.wait([refreshConnections(), _refreshRules()]);
  }

  Future<void> refreshConnections() async {
    final controller = _controller;
    if (controller == null || !engineRunning || _connectionsPolling) return;
    _connectionsPolling = true;
    try {
      final snapshot = await controller.getConnectionSnapshot();
      connections = snapshot.connections;
      connectionUploadTotal = snapshot.uploadTotal;
      connectionDownloadTotal = snapshot.downloadTotal;
      notifyListeners();
    } catch (exception) {
      error = '读取活动连接失败：$exception';
      notifyListeners();
    } finally {
      _connectionsPolling = false;
    }
  }

  Future<void> _refreshRules() async {
    final controller = _controller;
    if (controller == null || !engineRunning) return;
    try {
      rules = await controller.getRules();
      notifyListeners();
    } catch (exception) {
      error = '读取规则失败：$exception';
      notifyListeners();
    }
  }

  Future<void> changeProxyMode(String mode) async {
    final controller = _controller;
    if (controller == null || !engineRunning) {
      proxyMode = mode;
      if (mode == 'global' && groups.containsKey('GLOBAL')) {
        selectedGroup = 'GLOBAL';
        await _saveRuntimePreference('selectedGroup', 'GLOBAL');
      }
      await _saveRuntimePreference('proxyMode', mode);
      notifyListeners();
      return;
    }
    try {
      await controller.setMode(mode);
      proxyMode = mode;
      await _saveRuntimePreference('proxyMode', mode);
      _log('代理模式切换为：$mode');
      notifyListeners();
    } catch (exception) {
      error = '切换代理模式失败：$exception';
      notifyListeners();
    }
  }

  Future<void> closeConnection(String id) async {
    if (_controller == null) return;
    await _controller!.closeConnection(id);
    await refreshRuntimeDetails();
  }

  Future<void> closeAllConnections() async {
    if (_controller == null) return;
    await _controller!.closeAllConnections();
    await refreshRuntimeDetails();
  }

  Future<ProxyProfile> saveImported({
    ProxyProfile? existing,
    required String name,
    required ImportedProfile imported,
    int? autoUpdateIntervalMinutes,
  }) async {
    final saved = await _repository!.saveProfile(
      existing: existing,
      name: name,
      sourceType: imported.sourceType,
      source: imported.source,
      yaml: imported.yaml,
      autoUpdateIntervalMinutes: autoUpdateIntervalMinutes,
      usedTrafficBytes: imported.usedTrafficBytes,
      totalTrafficBytes: imported.totalTrafficBytes,
      expiresAt: imported.expiresAt,
    );
    profiles = await _repository!.load();
    if (!isRunning) await _loadOfflineGroups();
    _startProfileUpdateTimer();
    _log('配置已保存：${saved.name}');
    notifyListeners();
    return saved;
  }

  Future<void> activateProfile(String id) async {
    if (activeProfile?.id == id) return;
    final wasRunning = isRunning;
    if (wasRunning) await stop();
    try {
      profiles = await _repository!.activate(id);
      _configureController();
      if (!wasRunning) await _loadOfflineGroups();
      _log('配置已启用：${activeProfile?.name}');
      notifyListeners();
      if (wasRunning) await start();
    } catch (exception) {
      error = '启用配置失败：$exception';
      notifyListeners();
    }
  }

  Future<void> refreshProfile(ProxyProfile profile) async {
    final source = profile.source;
    if (profile.sourceType != 'url' || source == null) {
      throw StateError('该配置没有可更新的 URL');
    }
    ImportedProfile imported;
    try {
      imported = await importer.fromUrl(source);
    } catch (exception) {
      // 刷新失败：保留旧配置 + 记录原因 + UI 友好提示
      final reason = exception.toString();
      error = '订阅刷新失败（已保留旧配置）：$reason';
      _log('订阅刷新失败：${profile.name}，$reason');
      _refreshErrors[profile.id] = DateTime.now();
      notifyListeners();
      return;
    }
    final wasRunning = profile.active && isRunning;
    if (wasRunning) await stop();
    try {
      // 算 diff：用旧 yaml 和新 yaml 对比
      String? oldYaml;
      try {
        oldYaml = await File(profile.localYamlPath).readAsString();
      } catch (_) {}
      await saveImported(
        existing: profile,
        name: profile.name,
        imported: imported,
        autoUpdateIntervalMinutes: profile.autoUpdateIntervalMinutes,
      );
      _refreshErrors.remove(profile.id);
      _refreshFailureCounts.remove(profile.id);
      _refreshRetryAt.remove(profile.id);
      if (oldYaml != null) {
        _refreshDiffs[profile.id] = RefreshDiff.compute(oldYaml, imported.yaml);
        _log('订阅变更：${_refreshDiffs[profile.id]!.summary}');
        notifyListeners();
      }
    } catch (exception) {
      // 保存失败也回滚不到（新数据已经准备但写盘失败），保留旧文件
      error = '保存新配置失败（已保留旧配置）：$exception';
      _log('保存新配置失败：${profile.name}，$exception');
      notifyListeners();
    }
    if (profile.active) {
      _configureController();
      if (wasRunning) await start();
    }
  }

  Future<void> deleteProfile(String id) async {
    final deletingActive = activeProfile?.id == id;
    if (deletingActive && isRunning) await stop();
    profiles = await _repository!.delete(id);
    _configureController();
    if (!isRunning) await _loadOfflineGroups();
    _log('配置已删除');
    notifyListeners();
  }

  Future<void> renameProfile(String id, String name) async {
    profiles = await _repository!.rename(id, name);
    _log('配置已重命名：$name');
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings next, {bool? restartVpn}) async {
    final previous = settings;
    final shouldRestart =
        restartVpn ?? settingsRequireCoreRestart(previous, next);
    final profile = activeProfile;
    if (profile != null &&
        (previous.meta['extension.merge'] != next.meta['extension.merge'] ||
            previous.meta['extension.script'] !=
                next.meta['extension.script'])) {
      final base = await File(profile.localYamlPath).readAsString();
      applyConfigExtensions(
        base,
        merge: next.meta['extension.merge'] ?? '',
        script: next.meta['extension.script'] ?? '',
      );
    }
    settings = next;
    // 主题/语言实时同步到全局 ThemeController
    await themeController.applyDarkMode(next.darkMode);
    await themeController.setLanguage(next.language);
    notifyListeners();
    try {
      await _settingsRepository!.save(next);
      if (Platform.isAndroid) {
        await _vpn.applyAppBehavior(
          hideLauncher: next.hideLauncher,
          hideRecents: next.hideRecents,
        );
        await _vpn.updateTraffic(totalUp + totalDown, next.showTraffic);
      } else {
        await _applyDesktopBehavior(next);
      }
      final wasRunning = isRunning;
      if (shouldRestart && wasRunning) {
        await stop();
        await start();
        if (!isRunning) {
          final reason = error ?? '核心重启失败';
          settings = previous;
          await _settingsRepository!.save(previous);
          await start();
          throw StateError(reason);
        }
      }
      _log('设置已保存');
    } catch (exception) {
      settings = previous;
      await _settingsRepository!.save(previous).catchError((_) {});
      error = '保存设置失败：$exception';
      _log(error!);
      notifyListeners();
    }
  }

  static bool settingsRequireCoreRestart(
    AppSettings previous,
    AppSettings next,
  ) =>
      previous.autoRoute != next.autoRoute ||
      previous.bypassPrivate != next.bypassPrivate ||
      previous.dnsHijack != next.dnsHijack ||
      previous.allowBypass != next.allowBypass ||
      previous.ipv6 != next.ipv6 ||
      previous.systemProxy != next.systemProxy ||
      previous.stackMode != next.stackMode ||
      previous.allowLan != next.allowLan ||
      previous.dnsEnabled != next.dnsEnabled ||
      previous.unifiedDelay != next.unifiedDelay ||
      previous.logLevel != next.logLevel ||
      !mapEquals(previous.overrides, next.overrides) ||
      previous.meta['extension.merge'] != next.meta['extension.merge'] ||
      previous.meta['extension.script'] != next.meta['extension.script'];

  Future<void> importGeoFile(String kind, String sourcePath) async {
    final savedPath = await _settingsRepository!.importGeoFile(
      kind,
      sourcePath,
    );
    final meta = {...settings.meta, 'file.$kind': savedPath};
    await updateSettings(settings.copyWith(meta: meta));
    _log('Geo 文件已导入：$kind');
  }

  Future<File> exportLogs({String? targetPath}) async {
    final directory = Directory(supportPath ?? Directory.systemTemp.path);
    final file = File(
      targetPath ??
          '${directory.path}/clash-rs-${DateTime.now().millisecondsSinceEpoch}.log',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      logs.reversed.map(_redact).join('\n'),
      flush: true,
    );
    _log('日志已导出：${file.path}');
    notifyListeners();
    return file;
  }

  Future<File> exportBackup({String? targetPath}) async {
    final directory = Directory(supportPath ?? Directory.systemTemp.path);
    final file = File(
      targetPath ??
          '${directory.path}/clash-rs-backup-${DateTime.now().millisecondsSinceEpoch}.json',
    );
    final items = <Map<String, dynamic>>[];
    for (final profile in profiles) {
      items.add({
        'profile': profile.toJson(),
        'yaml': await File(profile.localYamlPath).readAsString(),
      });
    }
    await file.writeAsString(
      const JsonEncoder.withIndent(' ').convert({
        'version': 1,
        'settings': settings.toJson(),
        'profiles': items,
      }),
      flush: true,
    );
    _log('备份已导出：${file.path}');
    return file;
  }

  Future<void> restoreBackup(String sourcePath, {bool replace = true}) async {
    final root = jsonDecode(
      await File(sourcePath).readAsString(),
    ) as Map<String, dynamic>;
    if (root['version'] != 1 || root['profiles'] is! List) {
      throw const FormatException('备份格式或版本无效');
    }
    final settingsValue = root['settings'];
    if (settingsValue is! Map<String, dynamic>) {
      throw const FormatException('备份缺少设置对象');
    }
    final restoredSettings = AppSettings.fromJson(settingsValue);
    final restoredItems = <(ProxyProfile, ImportedProfile)>[];
    for (final item in root['profiles'] as List) {
      if (item is! Map<String, dynamic> ||
          item['profile'] is! Map<String, dynamic> ||
          item['yaml'] is! String) {
        throw const FormatException('备份配置项无效');
      }
      final map = item;
      final profile = ProxyProfile.fromJson(
        map['profile'] as Map<String, dynamic>,
      );
      final imported = ImportedProfile(
        yaml: importer.normalizeClashConfig(map['yaml'] as String),
        sourceType: profile.sourceType,
        source: profile.source,
        usedTrafficBytes: profile.usedTrafficBytes,
        totalTrafficBytes: profile.totalTrafficBytes,
        expiresAt: profile.expiresAt,
      );
      restoredItems.add((profile, imported));
    }
    if (restoredItems.isEmpty) throw const FormatException('备份没有配置');

    final repository = _repository!;
    final settingsRepository = _settingsRepository!;
    final profilesDirectory = repository.profilesDirectory;
    final transactionRoot = Directory(
      '${supportPath!}/restore-transaction-${DateTime.now().microsecondsSinceEpoch}',
    );
    final previousProfiles = Directory('${transactionRoot.path}/profiles');
    final previousSettings = settings;
    final wasRunning = isRunning;
    if (wasRunning) await stop();
    await transactionRoot.create(recursive: true);
    if (await profilesDirectory.exists()) {
      await _copyDirectory(profilesDirectory, previousProfiles);
    }
    try {
      if (replace) {
        if (await profilesDirectory.exists()) {
          await profilesDirectory.delete(recursive: true);
        }
        await profilesDirectory.create(recursive: true);
        await repository.indexFile.writeAsString('[]', flush: true);
        profiles = const [];
      }
      String? activeRestoredId;
      for (final item in restoredItems) {
        final profile = item.$1;
        final imported = item.$2;
        ProxyProfile? existing;
        if (!replace) {
          for (final candidate in profiles) {
            final sameSource =
                profile.source != null &&
                profile.source!.isNotEmpty &&
                candidate.source == profile.source;
            if (sameSource || candidate.name == profile.name) {
              existing = candidate;
              break;
            }
          }
        }
        final saved = await saveImported(
          existing: existing,
          name: profile.name,
          imported: imported,
          autoUpdateIntervalMinutes: profile.autoUpdateIntervalMinutes,
        );
        if (profile.active) activeRestoredId = saved.id;
      }
      if (activeRestoredId != null) {
        profiles = await repository.activate(activeRestoredId);
      }
      await settingsRepository.save(restoredSettings);
      settings = restoredSettings;
      await themeController.applyDarkMode(restoredSettings.darkMode);
      await themeController.setLanguage(restoredSettings.language);
      await _applyDesktopBehavior(restoredSettings);
      if (await transactionRoot.exists()) {
        await transactionRoot.delete(recursive: true);
      }
    } catch (exception) {
      if (await profilesDirectory.exists()) {
        await profilesDirectory.delete(recursive: true);
      }
      if (await previousProfiles.exists()) {
        await _copyDirectory(previousProfiles, profilesDirectory);
      }
      settings = previousSettings;
      await settingsRepository.save(previousSettings).catchError((_) {});
      profiles = await repository.load();
      _configureController();
      if (wasRunning) await start();
      throw StateError('备份恢复失败，已回滚：$exception');
    }
    profiles = await repository.load();
    _configureController();
    if (wasRunning) await start();
    _log('备份已${replace ? '替换' : '合并'}恢复：$sourcePath');
    notifyListeners();
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      final destination = '${target.path}/$name';
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(destination));
      } else if (entity is File) {
        await entity.copy(destination);
      }
    }
  }

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  /// 启动时后台检查更新，结果通过 notifyListeners 推到 UI。
  Future<void> _checkUpdatesInBackground() async {
    await updateChecker.load();
    if (updateChecker.lastResult != null) {
      notifyListeners();
    }
    final info = await updateChecker.check();
    if (info.available) {
      _log('发现新版本 v${info.version}：${info.url}');
    }
    notifyListeners();
  }

  /// 用户主动触发检查（设置页按钮）。
  Future<UpdateInfo> checkForUpdate() async {
    final info = await updateChecker.check(force: true);
    notifyListeners();
    return info;
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void reportExternalRecoveryFailure(Object exception) {
    externalEngineRunning = false;
    engineRunning = false;
    vpnRunning = false;
    error = 'TUN 自动恢复失败：$exception';
    _log(error!);
    notifyListeners();
  }

  void _configureController() {
    final profile = activeProfile;
    if (profile == null) return;
    final yaml = File(profile.localYamlPath).readAsStringSync();
    final endpoint = ClashConfigParser.parseController(yaml);
    if (!Platform.isAndroid) {
      _controller = ClashController(
        baseUrl: 'http://127.0.0.1:$controllerPort',
        secret: _desktopApiSecret,
      );
      return;
    }
    final configuredPort = int.tryParse(
      settings.overrides['controller-port'] ?? '',
    );
    _controller = endpoint == null
        ? null
        : ClashController(
            baseUrl:
                'http://${endpoint.host}:${configuredPort ?? endpoint.port}',
            secret: endpoint.secret.isEmpty ? null : endpoint.secret,
          );
  }

  String? get _desktopApiSecret {
    final value = settings.overrides['secret']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String _yamlQuoted(String value) => "'${value.replaceAll("'", "''")}'";

  Map<String, int> _desktopPorts() => {
    'HTTP': int.tryParse(settings.overrides['port'] ?? '') ?? 17890,
    'SOCKS': int.tryParse(settings.overrides['socks-port'] ?? '') ?? 17891,
    'Mixed': int.tryParse(settings.overrides['mixed-port'] ?? '') ?? 17892,
    '控制器': controllerPort,
  };

  File get _desktopPidFile => File('$supportPath/desktop-core.pid');

  Future<void> _persistDesktopCorePid(int pid) =>
      _desktopPidFile.writeAsString('$pid', flush: true);

  Future<void> _clearDesktopCorePid() async {
    if (await _desktopPidFile.exists()) await _desktopPidFile.delete();
  }

  Future<void> _recoverDesktopCore(Directory support) async {
    final file = File('${support.path}/desktop-core.pid');
    if (!await file.exists()) return;
    final pid = int.tryParse((await file.readAsString()).trim());
    if (pid != null && pid > 0) {
      if (Platform.isWindows) {
        final lookup = await Process.run('tasklist.exe', [
          '/FI',
          'PID eq $pid',
          '/FO',
          'CSV',
          '/NH',
        ]);
        if (lookup.stdout.toString().toLowerCase().contains('mihomo.exe')) {
          await Process.run('taskkill.exe', ['/PID', '$pid', '/T', '/F']);
        }
      } else {
        final lookup = await Process.run('/bin/ps', [
          '-p',
          '$pid',
          '-o',
          'command=',
        ]);
        if (lookup.stdout.toString().contains('mihomo')) {
          Process.killPid(pid, ProcessSignal.sigterm);
          await Future<void>.delayed(const Duration(milliseconds: 250));
          Process.killPid(pid, ProcessSignal.sigkill);
        }
      }
    }
    try {
      await file.delete();
    } catch (_) {}
  }

  Future<File> _findDesktopMihomo() async {
    final executable = File(Platform.resolvedExecutable);
    final candidates = Platform.isMacOS
        ? [
            File('${executable.parent.parent.path}/Resources/mihomo'),
            File('${Directory.current.path}/macos/Runner/Resources/mihomo'),
            File('${Directory.current.path}/app/macos/Runner/Resources/mihomo'),
          ]
        : [
            File('${executable.parent.path}/mihomo.exe'),
            File(
              '${Directory.current.path}/windows/runner/resources/mihomo.exe',
            ),
            File(
              '${Directory.current.path}/app/windows/runner/resources/mihomo.exe',
            ),
          ];
    for (final file in candidates) {
      if (await file.exists()) return file;
    }
    throw StateError('未找到桌面核心 mihomo${Platform.isWindows ? '.exe' : ''}');
  }

  Future<void> _runStartupScript() async {
    final script = settings.meta['startup.script']?.trim();
    if (script == null || script.isEmpty || Platform.isAndroid) return;
    final result = Platform.isWindows
        ? await Process.run('powershell.exe', [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            script,
          ])
        : await Process.run('/bin/zsh', ['-lc', script]);
    if (result.exitCode != 0) {
      throw StateError(
        '启动脚本失败（exit=${result.exitCode}）：${_redact('${result.stderr}')}',
      );
    }
    _log('启动脚本已执行');
  }

  void _startTrafficTimer() {
    _trafficTimer?.cancel();
    _trafficTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!isRunning || _controller == null || _trafficPolling) return;
      _trafficPolling = true;
      if (!externalEngineRunning &&
          _bridge != null &&
          !_bridge!.engineIsRunning()) {
        // 只在 mobile (有 FFI 引擎) 时检测核心退出。
        // 桌面端 _bridge == null,核心由 network service 启,这里不查 engineIsRunning。
        final shouldRestart = settings.autoRestart && !_restartScheduled;
        engineRunning = false;
        vpnRunning = false;
        _trafficTimer?.cancel();
        if (Platform.isAndroid) await _vpn.stop().catchError((_) {});
        error = '代理核心已退出，系统 VPN 已停止';
        _trafficPolling = false;
        notifyListeners();
        if (shouldRestart) {
          _restartScheduled = true;
          unawaited(
            Future<void>.delayed(const Duration(seconds: 1), () async {
              _restartScheduled = false;
              await start();
            }),
          );
        }
        return;
      }
      try {
        final traffic = await _controller!.getTraffic();
        uploadSpeed = traffic.up;
        downloadSpeed = traffic.down;
        totalUp = traffic.upTotal ?? totalUp + traffic.up;
        totalDown = traffic.downTotal ?? totalDown + traffic.down;
        trafficHistory.add(
          TrafficStats(
            up: traffic.up,
            down: traffic.down,
            time: DateTime.now(),
          ),
        );
        if (trafficHistory.length > 600) trafficHistory.removeAt(0);
        unawaited(refreshConnections());
        if (!_memoryPolling) unawaited(_refreshRealtimeMemory());
        _lastTrafficPollError = null;
        _externalEngineFailureCount = 0;
        _externalRecoverySignaled = false;
        if (error?.startsWith('实时状态刷新失败：') == true) error = null;
        if (Platform.isAndroid && settings.showTraffic) {
          await _vpn
              .updateTraffic(totalUp + totalDown, true)
              .catchError((_) {});
        }
        notifyListeners();
      } catch (exception) {
        final message = '实时状态刷新失败：$exception';
        if (_lastTrafficPollError != message) {
          _lastTrafficPollError = message;
          _log(message);
        }
        error = message;
        if (externalEngineRunning) {
          _externalEngineFailureCount++;
          if (_externalEngineFailureCount >= 3 && !_externalRecoverySignaled) {
            _externalRecoverySignaled = true;
            engineRunning = false;
            vpnRunning = false;
            _trafficTimer?.cancel();
            _selectedNodeHealthTimer?.cancel();
            _log('TUN 控制 API 连续失败，开始恢复外部核心');
            final recover = onExternalEngineLost;
            if (recover != null) unawaited(recover());
          }
        }
        notifyListeners();
      } finally {
        _trafficPolling = false;
      }
    });
  }

  void _startCoreLogStream() {
    unawaited(_coreLogSubscription?.cancel());
    _coreLogSubscription = null;
    final controller = _controller;
    if (controller == null || !engineRunning) return;
    _coreLogSubscription = controller
        .watchLogs(level: settings.logLevel)
        .listen(
          (frame) {
            final level = (frame['type'] ?? 'info').toString().toUpperCase();
            final payload = (frame['payload'] ?? frame['message'] ?? frame)
                .toString();
            final entry =
                '${DateTime.now().toIso8601String()} [$level] ${_redact(payload)}';
            logs.insert(0, entry);
            if (logs.length > 1000) logs.removeLast();
            notifyListeners();
          },
          onError: (Object exception) {
            _log('核心日志流已断开：$exception');
          },
        );
  }

  void _scheduleDesktopRestart() {
    if (Platform.isAndroid || !settings.autoRestart || busy) return;
    if (_desktopRestartAttempts >= 3) {
      error = 'mihomo 连续重启 3 次仍失败，已停止自动重启';
      _log(error!);
      notifyListeners();
      return;
    }
    _desktopRestartTimer?.cancel();
    final delay = Duration(seconds: 1 << _desktopRestartAttempts);
    _desktopRestartAttempts++;
    _log('将在 ${delay.inSeconds}s 后自动重启核心（$_desktopRestartAttempts/3）');
    _desktopRestartTimer = Timer(delay, () async {
      if (engineRunning || busy) return;
      await start();
      if (!engineRunning) _scheduleDesktopRestart();
    });
  }

  Future<void> _refreshDesktopEngineVersion() async {
    try {
      final binary = await _findDesktopMihomo();
      final result = await Process.run(binary.path, const [
        '-v',
      ]).timeout(const Duration(seconds: 3));
      final output = '${result.stdout}\n${result.stderr}'.trim();
      final match = RegExp(
        r'(mihomo[^\r\n]*?v?\d+\.\d+\.\d+[^\r\n]*)',
        caseSensitive: false,
      ).firstMatch(output);
      final detected = match?.group(1)?.trim();
      if (detected != null && detected.isNotEmpty) {
        engineVersion = detected;
        version = detected;
      }
    } catch (_) {
      engineVersion = version;
    }
  }

  Future<void> _refreshRealtimeMemory() async {
    final controller = _controller;
    if (controller == null || _memoryPolling) return;
    _memoryPolling = true;
    try {
      memoryMb = await controller.getMemory();
      notifyListeners();
    } catch (_) {
      // 流量和连接刷新不应被内存接口的瞬时失败阻塞。
    } finally {
      _memoryPolling = false;
    }
  }

  void _startProfileUpdateTimer() {
    _profileUpdateTimer?.cancel();
    _profileUpdateTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshDueProfiles(),
    );
  }

  void startIpRefreshTimer() {
    _ipRefreshTimer?.cancel();
    unawaited(refreshIpInfo());
    _scheduleNextIpRefresh();
    _ipRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(refreshIpInfo());
      _scheduleNextIpRefresh();
    });
  }

  void _scheduleNextIpRefresh() {
    _nextIpRefreshAt = DateTime.now().add(const Duration(minutes: 5));
    notifyListeners();
  }

  /// 系统代理模式下 Dart HttpClient 不会自动继承 macOS 的网络代理。
  /// 保存本地 HTTP 监听端口并立即重新查询，确保展示的是代理出口。
  void setIpInfoProxyPort(int? port) {
    _ipInfoProxyPort = port;
    unawaited(refreshIpInfo());
  }

  @visibleForTesting
  static String ipInfoProxyForPort(int? port) =>
      port == null ? 'DIRECT' : 'PROXY 127.0.0.1:$port';

  /// 通过公网 API 获取当前出口 IP / 地理位置（用户可手动调用刷新）。
  Future<void> refreshIpInfo() async {
    final generation = ++_ipInfoRefreshGeneration;
    final proxyPort = _ipInfoProxyPort;
    _ipInfo = _ipInfo.copyWith(loading: true, error: null);
    _nextIpRefreshAt = DateTime.now().add(const Duration(minutes: 5));
    notifyListeners();
    try {
      Object? lastFailure;
      IpInfo? resolved;
      for (final endpoint in const [
        'https://ipwho.is/',
        'https://ipapi.co/json/',
      ]) {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 6)
          ..findProxy = (_) => ipInfoProxyForPort(proxyPort);
        try {
          final request = await client.getUrl(Uri.parse(endpoint));
          request.headers.set('User-Agent', 'ClashRS/1.0.0');
          final response = await request.close().timeout(
            const Duration(seconds: 8),
          );
          final body = await response
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(seconds: 8));
          if (response.statusCode != 200) {
            throw HttpException('HTTP ${response.statusCode}');
          }
          final json = jsonDecode(body) as Map<String, dynamic>;
          if (json['success'] == false) {
            throw FormatException(json['message']?.toString() ?? '查询失败');
          }
          final parsed = parseIpInfoPayload(json);
          if (parsed.ip.isEmpty) throw const FormatException('响应缺少 IP');
          resolved = parsed;
          break;
        } catch (exception) {
          lastFailure = exception;
        } finally {
          client.close(force: true);
        }
      }
      if (generation != _ipInfoRefreshGeneration) return;
      if (resolved == null) throw StateError('所有 IP 服务均失败：$lastFailure');
      _ipInfo = resolved;
    } catch (error) {
      if (generation != _ipInfoRefreshGeneration) return;
      _ipInfo = _ipInfo.copyWith(loading: false, error: '$error');
    }
    notifyListeners();
  }

  Future<void> _refreshDueProfiles() async {
    if (_refreshingProfiles || busy) return;
    _refreshingProfiles = true;
    try {
      final now = DateTime.now();
      final due = profiles.where((profile) {
        final interval = profile.autoUpdateIntervalMinutes;
        if (profile.sourceType != 'url' || interval == null || interval <= 0) {
          return false;
        }
        final checkedAt = profile.lastCheckedAt ?? profile.updatedAt;
        final retryAt = _refreshRetryAt[profile.id];
        return (retryAt == null || !retryAt.isAfter(now)) &&
            now.difference(checkedAt) >= Duration(minutes: interval);
      }).toList();
      for (final profile in due) {
        try {
          await refreshProfile(profile);
          if (_refreshErrors.containsKey(profile.id)) {
            final failures = (_refreshFailureCounts[profile.id] ?? 0) + 1;
            _refreshFailureCounts[profile.id] = failures;
            final minutes = (1 << (failures - 1).clamp(0, 6));
            _refreshRetryAt[profile.id] = now.add(Duration(minutes: minutes));
            _log('自动更新退避：${profile.name}，$minutes 分钟后重试');
          } else {
            _refreshFailureCounts.remove(profile.id);
            _refreshRetryAt.remove(profile.id);
            _log('自动更新完成：${profile.name}');
          }
        } catch (exception) {
          _log('自动更新失败：${profile.name}，$exception');
        }
      }
    } finally {
      _refreshingProfiles = false;
    }
  }

  void _log(String message) {
    final entry =
        '${DateTime.now().toIso8601String()} [INFO] ${_redact(message)}';
    logs.insert(0, entry);
    if (logs.length > 1000) logs.removeLast();
    // 同时落盘到 ~/Library/Logs/ClashRS/controller.log,便于外部自用定位。
    try {
      final home = Platform.environment['HOME'] ?? Directory.current.path;
      final f = File('$home/Library/Logs/ClashRS/controller.log');
      f.parent.createSync(recursive: true);
      f.writeAsStringSync('$entry\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // 写文件失败不能影响主流程
    }
  }

  String _redact(String input) => input
      .replaceAllMapped(
        RegExp(
          r'(secret|token|password|uuid)=?\s*[^\s,;]+',
          caseSensitive: false,
        ),
        (match) => '${match.group(1)}=***',
      )
      .replaceAll(
        RegExp(r'authorization:\s*[^\s]+', caseSensitive: false),
        'authorization: ***',
      );

  /// UI 与导出共用的日志脱敏入口。
  String redactLog(String input) => _redact(input);

  Future<void> _saveRuntimePreference(String key, String value) async {
    final repository = _settingsRepository;
    if (repository == null) return;
    settings = settings.copyWith(meta: {...settings.meta, key: value});
    await repository.save(settings);
  }

  /// 更新首页布局（顺序 + 隐藏），立即持久化。
  Future<void> updateHomeLayout(HomeLayout layout) async {
    final repository = _settingsRepository;
    if (repository == null) return;
    settings = settings.copyWith(
      meta: {...settings.meta, 'home.layout': layout.encode()},
    );
    await repository.save(settings);
    notifyListeners();
  }

  /// 读取当前首页布局（meta 缺失时返回默认）。
  HomeLayout get homeLayout =>
      HomeLayout.fromMetaString(settings.meta['home.layout']);

  /// 把首页卡片上移 / 下移一位。
  Future<void> reorderHomeCard(String id, {required bool up}) async {
    final layout = homeLayout;
    final order = List<String>.from(layout.order);
    final idx = order.indexOf(id);
    if (idx < 0) {
      order.add(id);
    } else {
      order.removeAt(idx);
    }
    final target = up ? idx - 1 : idx + 1;
    order.insert(target.clamp(0, order.length), id);
    // 去掉重复项，保持唯一
    final unique = <String>[];
    for (final e in order) {
      if (!unique.contains(e)) unique.add(e);
    }
    await updateHomeLayout(layout.copyWith(order: unique));
  }

  /// 切换首页卡片可见性。
  Future<void> toggleHomeCardVisibility(String id) async {
    final layout = homeLayout;
    final hidden = Set<String>.from(layout.hidden);
    if (hidden.contains(id)) {
      hidden.remove(id);
    } else {
      hidden.add(id);
    }
    await updateHomeLayout(layout.copyWith(hidden: hidden));
  }

  /// 启动后恢复：把保存的 proxyMode 和 node 选择应用到 engine。
  Future<void> _restoreRuntimePreferences() async {
    final controller = _controller;
    if (controller == null) return;
    // 1) 模式
    final savedMode = settings.meta['proxyMode'];
    if (savedMode != null && savedMode != proxyMode) {
      try {
        await controller.setMode(savedMode);
        proxyMode = savedMode;
        _log('已恢复代理模式：$savedMode');
      } catch (error) {
        _log('恢复代理模式失败：$error');
      }
    }
    // 2) 节点：依次尝试把每个 group 的 saved node 重新 select
    final meta = settings.meta;
    for (final entry in groups.entries) {
      final groupName = entry.key;
      if (entry.value.all.isEmpty) continue;
      final savedNode = meta['node.$groupName'];
      if (savedNode == null || !entry.value.all.contains(savedNode)) continue;
      if (entry.value.now == savedNode) continue;
      try {
        await controller.selectNode(groupName, savedNode);
        _log('已恢复节点：$groupName → $savedNode');
      } catch (error) {
        _log('恢复节点失败：$groupName → $savedNode，$error');
      }
    }
    await refreshGroups();
  }

  Future<void> _ensureControllerPortAvailable() async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        controllerPort,
        timeout: const Duration(milliseconds: 250),
      );
      socket.destroy();
      throw StateError('控制端口 $controllerPort 已被占用');
    } on SocketException {
      return;
    }
  }

  Future<void> _applyDesktopBehavior(AppSettings value) async {
    try {
      const channel = MethodChannel('com.proxyapp.app/desktop_lifecycle');
      await channel.invokeMethod<void>('setCloseToTray', value.closeToTray);
      await channel.invokeMethod<void>(
        'setTrayClickAction',
        value.meta['tray.click'] ?? 'show',
      );
    } on MissingPluginException {
      // 单元测试或尚未注册桌面窗口时延后到下次保存。
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home == null) return;
      final file = File(
        '$home/Library/LaunchAgents/com.proxyapp.clashrs.plist',
      );
      final uidResult = await Process.run('/usr/bin/id', ['-u']);
      if (uidResult.exitCode != 0) {
        throw StateError('读取当前用户 ID 失败：${uidResult.stderr}');
      }
      final domain = 'gui/${uidResult.stdout.toString().trim()}';
      final service = '$domain/com.proxyapp.clashrs';
      if (!value.launchAtStartup) {
        await Process.run('/bin/launchctl', ['bootout', service]);
        if (await file.exists()) await file.delete();
        return;
      }
      await file.parent.create(recursive: true);
      final executable = const HtmlEscape().convert(
        Platform.resolvedExecutable,
      );
      await file.writeAsString('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>Label</key><string>com.proxyapp.clashrs</string>
<key>ProgramArguments</key><array><string>$executable</string>${value.silentStart ? '<string>--silent</string>' : ''}</array>
<key>RunAtLoad</key><true/></dict></plist>''', flush: true);
      await Process.run('/bin/launchctl', ['bootout', service]);
      final bootstrap = await Process.run('/bin/launchctl', [
        'bootstrap',
        domain,
        file.path,
      ]);
      if (bootstrap.exitCode != 0) {
        throw StateError('注册开机自启失败：${bootstrap.stderr.toString().trim()}');
      }
    } else if (Platform.isWindows) {
      final args = value.launchAtStartup
          ? [
              'add',
              r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
              '/v',
              'Clash RS',
              '/t',
              'REG_SZ',
              '/d',
              '"${Platform.resolvedExecutable}"${value.silentStart ? ' --silent' : ''}',
              '/f',
            ]
          : [
              'delete',
              r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
              '/v',
              'Clash RS',
              '/f',
            ];
      await Process.run('reg.exe', args);
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _trafficTimer?.cancel();
    _selectedNodeHealthTimer?.cancel();
    _profileUpdateTimer?.cancel();
    _ipRefreshTimer?.cancel();
    _desktopRestartTimer?.cancel();
    onExternalEngineLost = null;
    unawaited(_coreLogSubscription?.cancel());
    _ipInfoRefreshGeneration++;
    super.dispose();
  }
}
