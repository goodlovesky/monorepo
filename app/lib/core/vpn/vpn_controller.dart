import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart' as yaml;

class VpnException implements Exception {
  final String message;
  const VpnException(this.message);

  @override
  String toString() => message;
}

class VpnStatus {
  final bool permissionGranted;
  final bool serviceRunning;

  const VpnStatus({
    required this.permissionGranted,
    required this.serviceRunning,
  });
}

class VpnStartOptions {
  final bool autoRoute;
  final bool bypassPrivate;
  final bool allowBypass;
  final bool ipv6;
  final bool systemProxy;
  final int mixedPort;
  final String accessMode;
  final List<String> accessPackages;

  const VpnStartOptions({
    this.autoRoute = true,
    this.bypassPrivate = true,
    this.allowBypass = true,
    this.ipv6 = false,
    this.systemProxy = true,
    this.mixedPort = 17892,
    this.accessMode = 'all',
    this.accessPackages = const [],
  });

  Map<String, dynamic> toMap() => {
    'autoRoute': autoRoute,
    'bypassPrivate': bypassPrivate,
    'allowBypass': allowBypass,
    'ipv6': ipv6,
    'systemProxy': systemProxy,
    'mixedPort': mixedPort,
    'accessMode': accessMode,
    'accessPackages': accessPackages,
  };
}

class VpnController {
  VpnController._();

  static final VpnController instance = VpnController._();
  static const _channel = MethodChannel('com.proxyapp.app/vpn');

  void _requireAndroid() {
    if (!Platform.isAndroid) {
      throw const VpnException('系统 VPN 接管仅在 Android 上启用');
    }
  }

  Future<void> prepare() async {
    _requireAndroid();
    await _invoke('prepare');
  }

  Future<int> establish([
    VpnStartOptions options = const VpnStartOptions(),
  ]) async {
    _requireAndroid();
    final result = await _invoke('establish', options.toMap());
    final fd = result['tunFd'];
    if (fd is! int || fd <= 0) {
      throw const VpnException('系统 VPN 未返回有效的 TUN 文件描述符');
    }
    return fd;
  }

  Future<void> commitFd(int fd) async {
    _requireAndroid();
    await _invoke('commitFd', {'tunFd': fd});
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _invoke('stop');
  }

  Future<void> applyAppBehavior({
    required bool hideLauncher,
    required bool hideRecents,
  }) async {
    if (!Platform.isAndroid) return;
    await _invoke('appBehavior', {
      'hideLauncher': hideLauncher,
      'hideRecents': hideRecents,
    });
  }

  Future<void> updateTraffic(int bytes, bool showTraffic) async {
    if (!Platform.isAndroid) return;
    await _invoke('updateTraffic', {
      'bytes': bytes,
      'showTraffic': showTraffic,
    });
  }

  Future<VpnStatus> status() async {
    _requireAndroid();
    final result = await _invoke('status');
    return VpnStatus(
      permissionGranted: result['permissionGranted'] == true,
      serviceRunning: result['serviceRunning'] == true,
    );
  }

  Future<Map<String, dynamic>> _invoke(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        method,
        arguments,
      );
      if (result == null || result['ok'] != true) {
        throw VpnException('VPN $method 返回了无效状态');
      }
      return result;
    } on PlatformException catch (error) {
      throw VpnException(error.message ?? error.code);
    }
  }
}

String buildRuntimeVpnConfig(
  String baseConfig,
  int tunFd, {
  bool dnsHijack = true,
  bool ipv6 = false,
  String stackMode = 'system',
  Map<String, String> overrides = const {},
  Map<String, String> meta = const {},
}) {
  if (tunFd <= 0) {
    throw const VpnException('TUN 文件描述符必须为正整数');
  }

  final scalarOverrides = <String, String>{};
  const supportedTopLevel = {
    'port',
    'socks-port',
    'redir-port',
    'tproxy-port',
    'mixed-port',
    'authentication',
    'allow-lan',
    'ipv6',
    'bind-address',
    'external-controller',
    'external-controller-tls',
    'secret',
    'mode',
    'log-level',
  };
  for (final entry in overrides.entries) {
    if (supportedTopLevel.contains(entry.key)) {
      scalarOverrides[entry.key] = entry.value;
    }
  }
  const metaKeys = {
    'unified-delay': 'unified-delay',
    'geodata-mode': 'geodata-mode',
    'tcp-concurrent': 'tcp-concurrent',
    'process-mode': 'find-process-mode',
  };
  for (final entry in metaKeys.entries) {
    final value = meta[entry.key];
    if (value != null && value.isNotEmpty) scalarOverrides[entry.value] = value;
  }

  final output = <String>[];
  var skippingRuntimeBlock = false;
  for (final line in _sanitizeUnsupportedProxyTypes(baseConfig).split('\n')) {
    final topLevel = line.isNotEmpty && !line.startsWith(RegExp(r'\s'));
    final key = topLevel && line.contains(':')
        ? line.split(':').first.trim()
        : '';
    if (topLevel && (key == 'tun' || key == 'dns')) {
      skippingRuntimeBlock = true;
      continue;
    }
    if (skippingRuntimeBlock) {
      if (line.trim().isEmpty || !topLevel) continue;
      skippingRuntimeBlock = false;
    }
    if (topLevel && scalarOverrides.containsKey(key)) continue;
    output.add(line);
  }
  for (final entry in scalarOverrides.entries) {
    output.add('${entry.key}: ${entry.value}');
  }

  List<String> listValue(String key, List<String> fallback) {
    final value = overrides[key]?.trim();
    if (value == null || value.isEmpty) return fallback;
    return value
        .split(RegExp(r'[,\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  final defaultNameservers = listValue('dns.default-nameserver', const [
    '1.1.1.1',
    '8.8.8.8',
  ]);
  final nameservers = listValue('dns.nameserver', const ['1.1.1.1', '8.8.8.8']);
  final enhancedMode = overrides['dns.enhanced-mode'] ?? 'normal';
  final dnsListen = overrides['dns.listen'];
  final normalized = output.join('\n').trimRight();
  return '''$normalized

dns:
  enable: true
  ipv6: $ipv6
  enhanced-mode: $enhancedMode
${dnsListen == null || dnsListen.isEmpty ? '' : '  listen: $dnsListen\n'}  default-nameserver:
${defaultNameservers.map((server) => '    - $server').join('\n')}
  nameserver:
${nameservers.map((server) => '    - $server').join('\n')}

tun:
  enable: true
  device-id: "fd://$tunFd"
  gateway: 198.18.0.1/24
  route-all: false
  stack: $stackMode
  mtu: 1500
  dns-hijack: $dnsHijack
''';
}

String buildRuntimeMacTunConfig(
  String baseConfig, {
  bool ipv6 = false,
  String stackMode = 'system',
  bool dnsHijack = true,
  bool autoRoute = true,
  int controllerPort = 9090,
  String merge = '',
  String script = '',
}) {
  baseConfig = applyConfigExtensions(baseConfig, merge: merge, script: script);
  final output = <String>[];
  var skippingRuntimeBlock = false;
  for (final line in baseConfig.split('\n')) {
    final topLevel = line.isNotEmpty && !line.startsWith(RegExp(r'\s'));
    final key = topLevel && line.contains(':')
        ? line.split(':').first.trim()
        : '';
    if (topLevel &&
        (key == 'tun' || key == 'dns' || key == 'external-controller')) {
      skippingRuntimeBlock = true;
      continue;
    }
    if (skippingRuntimeBlock) {
      if (line.trim().isEmpty || !topLevel) continue;
      skippingRuntimeBlock = false;
    }
    output.add(line);
  }
  final normalized = output.join('\n').trimRight();
  return '''$normalized

external-controller: 127.0.0.1:$controllerPort

dns:
  enable: true
  ipv6: $ipv6
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver:
    - 1.1.1.1
    - 8.8.8.8
  nameserver:
    - 1.1.1.1
    - 8.8.8.8

tun:
  enable: true
  stack: $stackMode
  auto-route: $autoRoute
  auto-detect-interface: true
  mtu: 1500
${dnsHijack ? '  dns-hijack:\n    - any:53\n' : ''}''';
}

/// 把引擎不支持 / 不可被 group 引用的代理节点从配置中彻底删掉,避免启动时
/// InvalidConfig("proxy X not found")。
///
/// 之前的实现只是把不支持的 type 改成 `reject`,但 clash-lib 0.8.2 在解析时
/// 只把真实代理协议(vmess / vless / trojan / ss 等)注册到全局 proxy 表,
/// `direct` 和 `reject` 视为内置,不会出现在 name -> proxy 的映射里。
/// 一旦 proxy-groups / rules 引用了一个被降级为 reject 的节点名,核心就会
/// 报 "proxy X not found" 并拒绝启动,导致上层出现
/// "外部控制器未在 5s 内就绪" 的连锁错误。
///
/// 正确做法:把 unsupported / non-referable 节点从 proxies 段里整条删掉,并把
/// proxy-groups 和 rules 里所有对这些 name 的引用也一并删掉。
///
/// 当前已知 unsupported:anytls(需要升级 clash-rs 到 v0.10.x,nightly,暂未升级)。
/// 已知 non-referable:direct / reject。
String _sanitizeUnsupportedProxyTypes(String config) {
  const unsupportedTypes = <String>{'anytls'};
  const nonReferableTypes = <String>{'reject', 'direct'};

  late Map yamlData;
  try {
    final loaded = yaml.loadYaml(config);
    if (loaded is! Map) return config;
    // yaml.loadYaml 返回 YamlMap,嵌套结构也是 unmodifiable;
    // 经 json 序列化一次转成普通 Dart Map/List 便于原地修改。
    yamlData = jsonDecode(jsonEncode(loaded)) as Map;
  } catch (_) {
    // YAML 解析失败:原样返回,让上层报更明确的错误而不是悄悄改写
    return config;
  }

  // 1) 收集被删的 name
  final removed = <String>{};
  final rawProxies = (yamlData['proxies'] as List?) ?? const [];
  final keepProxies = <Object>[];
  for (final entry in rawProxies) {
    if (entry is! Map) {
      keepProxies.add(entry);
      continue;
    }
    final type = entry['type'];
    final name = entry['name'];
    if (type is String &&
        (unsupportedTypes.contains(type) || nonReferableTypes.contains(type)) &&
        name is String) {
      removed.add(name);
    } else {
      keepProxies.add(entry);
    }
  }
  yamlData['proxies'] = keepProxies;

  // 2) 删 proxy-groups 引用
  final rawGroups = (yamlData['proxy-groups'] as List?) ?? const [];
  for (final g in rawGroups) {
    if (g is Map && g['proxies'] is List) {
      (g['proxies'] as List).removeWhere(
        (n) => n is String && removed.contains(n),
      );
    }
  }

  // 3) 删 rules 引用
  final rawRules = yamlData['rules'];
  if (rawRules is List) {
    rawRules.removeWhere((r) {
      if (r is! String) return false;
      final parts = r.split(',');
      if (parts.isEmpty) return false;
      return removed.contains(parts.last.trim());
    });
  }

  return _dumpYaml(yamlData);
}

/// 把 [data] 序列化成 block-style YAML 字符串。
///
/// 仅支持本项目实际用到的标量/容器类型:String / num / bool / null / List / Map。
/// 字符串在含特殊字符时加单引号,内部 `'` 用 `''` 转义。Flow style
/// (`{...}` / `[...]`) 不会被生成,确保 clash-lib 0.8.2 的 Rust YAML
/// 解析器能稳定解析。
String _dumpYaml(Object? data) {
  final buf = StringBuffer();
  _dumpNode(data, 0, buf);
  return buf.toString();
}

void _dumpNode(Object? node, int indent, StringBuffer buf) {
  final pad = '  ' * indent;
  if (node is Map) {
    if (node.isEmpty) {
      buf.writeln('{}');
      return;
    }
    for (final entry in node.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is Map || value is List) {
        buf.writeln('$pad$key:');
        _dumpNode(value, indent + 1, buf);
      } else {
        buf.writeln('$pad$key: ${_dumpScalar(value)}');
      }
    }
    return;
  }
  if (node is List) {
    if (node.isEmpty) {
      buf.writeln('[]');
      return;
    }
    for (final item in node) {
      if (item is Map) {
        // 列表元素是 map:首行写 `-`,后续行缩进对齐 key
        final first = true;
        final inner = StringBuffer();
        _dumpNode(item, 0, inner);
        final lines = inner.toString().split('\n');
        // 去掉末尾空行
        while (lines.isNotEmpty && lines.last.isEmpty) {
          lines.removeLast();
        }
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].isEmpty) continue;
          if (i == 0 && first) {
            buf.writeln('$pad- ${lines[i]}');
          } else {
            buf.writeln('$pad  ${lines[i]}');
          }
        }
      } else if (item is List) {
        buf.writeln('$pad-');
        _dumpNode(item, indent + 1, buf);
      } else {
        buf.writeln('$pad- ${_dumpScalar(item)}');
      }
    }
    return;
  }
  // 顶层就是标量的情况
  buf.writeln('$pad${_dumpScalar(node)}');
}

String _dumpScalar(Object? value) {
  if (value == null) return 'null';
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return value.toString();
  if (value is String) {
    if (_needsQuoting(value)) {
      final escaped = value.replaceAll("'", "''");
      return "'$escaped'";
    }
    return value;
  }
  return value.toString();
}

bool _needsQuoting(String s) {
  if (s.isEmpty) return true;
  // 命中这些特殊字符或看起来像 bool / null / 数字的字符串都需要引号
  if (s == 'true' || s == 'false' || s == 'null' || s == '~') return true;
  if (RegExp(r'^-?\d').hasMatch(s)) return true;
  return RegExp(r'[:#\[\]\{\},\&\*\?\|\-\<\>\=\!\%\@\`]|^\s|\s$|^\s*#')
      .hasMatch(s);
}

String buildRuntimeDesktopConfig(
  String baseConfig, {
  Map<String, String> overrides = const {},
  String mode = 'rule',
  bool allowLan = false,
  bool ipv6 = false,
  bool dnsEnabled = true,
  bool unifiedDelay = true,
  String logLevel = 'info',
  String merge = '',
  String script = '',
}) {
  baseConfig = applyConfigExtensions(baseConfig, merge: merge, script: script);
  final values = <String, String>{
    ...overrides,
    'allow-lan': '$allowLan',
    'ipv6': '$ipv6',
    'mode': mode,
    'log-level': logLevel,
    'unified-delay': '$unifiedDelay',
  };
  final controllerPort = values.remove('controller-port') ?? '9090';
  values['external-controller'] = '127.0.0.1:$controllerPort';
  const accepted = {
    'port',
    'socks-port',
    'mixed-port',
    'redir-port',
    'tproxy-port',
    'allow-lan',
    'ipv6',
    'mode',
    'log-level',
    'unified-delay',
    'external-controller',
    'secret',
    'bind-address',
  };
  final output = <String>[];
  var skippingDns = false;
  var skippingTun = false;
  var wroteTun = false;
  for (final line in baseConfig.split('\n')) {
    final topLevel = line.isNotEmpty && !line.startsWith(RegExp(r'\s'));
    final key = topLevel && line.contains(':')
        ? line.split(':').first.trim()
        : '';
    if (skippingDns) {
      if (!topLevel || line.trim().isEmpty) continue;
      skippingDns = false;
    }
    if (skippingTun) {
      if (!topLevel || line.trim().isEmpty) continue;
      skippingTun = false;
    }
    if (topLevel && key == 'tun') {
      output.add('tun:\n  enable: false');
      wroteTun = true;
      skippingTun = true;
      continue;
    }
    if (topLevel && accepted.contains(key) && values.containsKey(key)) continue;
    if (topLevel && key == 'dns' && !dnsEnabled) {
      output.add('dns:\n  enable: false');
      skippingDns = true;
      continue;
    }
    output.add(line);
  }
  if (!wroteTun) output.add('tun:\n  enable: false');
  for (final entry in values.entries) {
    if (accepted.contains(entry.key)) {
      output.add('${entry.key}: ${entry.value}');
    }
  }
  return output.join('\n').trimRight();
}

/// 应用订阅页的 Merge 覆写与受限 Script DSL。
///
/// Script 支持：
/// - `set dns.enable = true`
/// - `delete tun`
/// - `prepend-rule DOMAIN,example.com,DIRECT`
/// - `append-rule MATCH,PROXY`
String applyConfigExtensions(
  String baseConfig, {
  String merge = '',
  String script = '',
}) {
  if (merge.trim().isEmpty && script.trim().isEmpty) return baseConfig;
  final rootValue = yaml.loadYaml(baseConfig);
  if (rootValue is! yaml.YamlMap) {
    throw const FormatException('基础配置必须是 YAML 对象');
  }
  final root = Map<String, dynamic>.from(_plainYaml(rootValue) as Map);
  if (merge.trim().isNotEmpty) {
    final overlayValue = yaml.loadYaml(merge);
    if (overlayValue is! yaml.YamlMap) {
      throw const FormatException('Merge 扩展必须是 YAML 对象');
    }
    final overlay = Map<String, dynamic>.from(_plainYaml(overlayValue) as Map);
    final prependRules = overlay.remove('prepend-rules');
    final appendRules = overlay.remove('append-rules');
    _deepMerge(root, overlay);
    if (prependRules is List) {
      root['rules'] = [...prependRules, ..._listValue(root['rules'])];
    }
    if (appendRules is List) {
      root['rules'] = [..._listValue(root['rules']), ...appendRules];
    }
  }
  if (script.trim().isNotEmpty) _applyExtensionScript(root, script);
  return _emitYaml(root).trimRight();
}

dynamic _plainYaml(dynamic value) {
  if (value is yaml.YamlMap || value is Map) {
    return <String, dynamic>{
      for (final entry in (value as Map).entries)
        entry.key.toString(): _plainYaml(entry.value),
    };
  }
  if (value is yaml.YamlList || value is List) {
    return [for (final item in value as Iterable) _plainYaml(item)];
  }
  return value;
}

List<dynamic> _listValue(dynamic value) => value is List ? value : <dynamic>[];

void _deepMerge(Map<String, dynamic> target, Map<String, dynamic> overlay) {
  for (final entry in overlay.entries) {
    final current = target[entry.key];
    if (current is Map && entry.value is Map) {
      final next = Map<String, dynamic>.from(current);
      _deepMerge(next, Map<String, dynamic>.from(entry.value as Map));
      target[entry.key] = next;
    } else {
      target[entry.key] = entry.value;
    }
  }
}

void _applyExtensionScript(Map<String, dynamic> root, String script) {
  for (var index = 0; index < script.split('\n').length; index++) {
    final raw = script.split('\n')[index].trim();
    if (raw.isEmpty || raw.startsWith('//') || raw.startsWith('#')) continue;
    if (raw.startsWith('prepend-rule ')) {
      root['rules'] = [raw.substring(13).trim(), ..._listValue(root['rules'])];
      continue;
    }
    if (raw.startsWith('append-rule ')) {
      root['rules'] = [..._listValue(root['rules']), raw.substring(12).trim()];
      continue;
    }
    if (raw.startsWith('delete ')) {
      _deleteYamlPath(root, raw.substring(7).trim());
      continue;
    }
    if (raw.startsWith('set ')) {
      final assignment = raw.substring(4);
      final equals = assignment.indexOf('=');
      if (equals <= 0) {
        throw FormatException('Script 第 ${index + 1} 行缺少 =');
      }
      final path = assignment.substring(0, equals).trim();
      final literal = assignment.substring(equals + 1).trim();
      _setYamlPath(root, path, _plainYaml(yaml.loadYaml(literal)));
      continue;
    }
    throw FormatException('Script 第 ${index + 1} 行指令无效：$raw');
  }
}

void _setYamlPath(Map<String, dynamic> root, String path, dynamic value) {
  final parts = path.split('.').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) throw const FormatException('Script 路径不能为空');
  var current = root;
  for (final part in parts.take(parts.length - 1)) {
    final child = current[part];
    if (child is Map<String, dynamic>) {
      current = child;
    } else if (child is Map) {
      final next = Map<String, dynamic>.from(child);
      current[part] = next;
      current = next;
    } else {
      final next = <String, dynamic>{};
      current[part] = next;
      current = next;
    }
  }
  current[parts.last] = value;
}

void _deleteYamlPath(Map<String, dynamic> root, String path) {
  final parts = path.split('.').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) throw const FormatException('Script 路径不能为空');
  Map<String, dynamic> current = root;
  for (final part in parts.take(parts.length - 1)) {
    final child = current[part];
    if (child is! Map) return;
    current = Map<String, dynamic>.from(child);
  }
  current.remove(parts.last);
}

String _emitYaml(dynamic value, {int indent = 0}) {
  final prefix = ' ' * indent;
  if (value is Map) {
    final lines = <String>[];
    for (final entry in value.entries) {
      final key = _dumpScalar(entry.key.toString());
      final child = entry.value;
      if (child is Map || child is List) {
        lines.add('$prefix$key:');
        lines.add(_emitYaml(child, indent: indent + 2));
      } else {
        lines.add('$prefix$key: ${_dumpScalar(child)}');
      }
    }
    return lines.join('\n');
  }
  if (value is List) {
    final lines = <String>[];
    for (final child in value) {
      if (child is Map || child is List) {
        final emitted = _emitYaml(child, indent: indent + 2);
        final childLines = emitted.split('\n');
        lines.add('$prefix- ${childLines.first.trimLeft()}');
        lines.addAll(childLines.skip(1));
      } else {
        lines.add('$prefix- ${_dumpScalar(child)}');
      }
    }
    return lines.join('\n');
  }
  return '$prefix${_dumpScalar(value)}';
}
