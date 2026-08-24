import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

class ProfileImportException implements Exception {
  final String message;
  const ProfileImportException(this.message);
  @override
  String toString() => message;
}

class ImportedProfile {
  final String yaml;
  final String sourceType;
  final String? source;
  final int? usedTrafficBytes;
  final int? totalTrafficBytes;
  final DateTime? expiresAt;

  const ImportedProfile({
    required this.yaml,
    required this.sourceType,
    this.source,
    this.usedTrafficBytes,
    this.totalTrafficBytes,
    this.expiresAt,
  });
}

class ProfileImportService {
  static const _maxBytes = 8 * 1024 * 1024;

  Future<ImportedProfile> fromUrl(String source) async {
    final uri = Uri.tryParse(source.trim());
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      throw const ProfileImportException('URL 必须以 http:// 或 https:// 开头');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 4;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'ClashMetaForAndroid/1.0',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ProfileImportException('下载失败：HTTP ${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > _maxBytes) {
          throw const ProfileImportException('配置文件超过 8 MiB');
        }
      }
      final converted = convertText(utf8.decode(bytes, allowMalformed: true));
      final usage = _parseUsage(
        response.headers.value('subscription-userinfo'),
      );
      return ImportedProfile(
        yaml: converted,
        sourceType: 'url',
        source: uri.toString(),
        usedTrafficBytes: usage.$1,
        totalTrafficBytes: usage.$2,
        expiresAt: usage.$3,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<ImportedProfile> fromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const ProfileImportException('配置文件不存在');
    if (await file.length() > _maxBytes) {
      throw const ProfileImportException('配置文件超过 8 MiB');
    }
    return ImportedProfile(
      yaml: convertText(await file.readAsString()),
      sourceType: 'file',
      source: path,
    );
  }

  ImportedProfile fromQr(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      throw const ProfileImportException('QR_URL');
    }
    return ImportedProfile(
      yaml: convertText(trimmed),
      sourceType: 'qr',
      source: trimmed,
    );
  }

  String convertText(String source) {
    final trimmed = source.trim().replaceFirst('\ufeff', '');
    if (trimmed.isEmpty) throw const ProfileImportException('配置内容为空');

    if (_looksLikeYaml(trimmed)) return normalizeClashConfig(trimmed);
    final decoded = _tryDecodeBase64(trimmed);
    if (decoded != null && decoded.contains('://')) {
      return _linksToYaml(
        decoded
            .split(RegExp(r'[\r\n]+'))
            .where((line) => line.trim().isNotEmpty),
      );
    }
    if (trimmed.contains('://')) {
      return _linksToYaml(
        trimmed
            .split(RegExp(r'[\r\n]+'))
            .where((line) => line.trim().isNotEmpty),
      );
    }
    throw const ProfileImportException('未识别到 Clash YAML 或代理节点链接');
  }

  String normalizeClashConfig(String source) {
    dynamic document;
    try {
      document = loadYaml(source);
    } catch (error) {
      throw ProfileImportException('YAML 解析失败：$error');
    }
    if (document is! YamlMap) throw const ProfileImportException('配置根节点必须是对象');
    final hasProxy =
        document['proxies'] is YamlList ||
        document['proxy-providers'] is YamlMap;
    final hasGroup = document['proxy-groups'] is YamlList;
    final hasRules = document['rules'] is YamlList;
    if (!hasProxy) {
      throw const ProfileImportException('配置不包含 proxies 或 proxy-providers');
    }
    if (!hasGroup) throw const ProfileImportException('配置不包含 proxy-groups');
    if (!hasRules) throw const ProfileImportException('配置不包含 rules');

    // 深度校验：proxies 不能为空，每个 proxy 必须有 type + name
    final proxies = document['proxies'];
    if (proxies is YamlList) {
      if (proxies.isEmpty) {
        throw const ProfileImportException('proxies 列表为空，至少需要一个节点');
      }
      final names = <String>{};
      for (final entry in proxies) {
        if (entry is! YamlMap) {
          throw const ProfileImportException('proxies 中存在非对象项');
        }
        final name = entry['name']?.toString();
        if (name == null || name.isEmpty) {
          throw const ProfileImportException('proxies 中存在缺少 name 的节点');
        }
        if (names.contains(name)) {
          throw ProfileImportException('proxies 中存在重复的节点名：$name');
        }
        names.add(name);
        if (entry['type'] == null) {
          throw ProfileImportException('节点 "$name" 缺少 type 字段');
        }
      }
    }

    // 深度校验：proxy-groups 引用必须指向已定义的节点或内置选项
    final groups = document['proxy-groups'];
    if (groups is YamlList) {
      final builtins = <String>{'DIRECT', 'REJECT', 'GLOBAL', 'PASS'};
      for (final entry in groups) {
        if (entry is! YamlMap) continue;
        final gname = entry['name']?.toString() ?? '<未命名>';
        if (entry['type'] == null) {
          throw ProfileImportException('代理组 "$gname" 缺少 type 字段');
        }
        final proxies2 = entry['proxies'];
        if (proxies2 is YamlList) {
          for (final p in proxies2) {
            final pname = p?.toString();
            if (pname == null) continue;
            if (builtins.contains(pname)) continue;
            if (pname == gname) {
              throw ProfileImportException('代理组 "$gname" 不能引用自身');
            }
          }
        }
      }
    }

    final output = <String>[];
    for (final line in source.split('\n')) {
      final trimmed = line.trimLeft();
      final topLevel = trimmed.length == line.length;
      if (topLevel &&
          (trimmed.startsWith('external-controller:') ||
              trimmed.startsWith('secret:'))) {
        continue;
      }
      output.add(line);
    }
    return '''${output.join('\n').trimRight()}

external-controller: 127.0.0.1:9090
secret: proxy_app_ffi_demo
''';
  }

  bool _looksLikeYaml(String source) {
    try {
      final value = loadYaml(source);
      return value is YamlMap &&
          (value.containsKey('proxies') ||
              value.containsKey('proxy-providers'));
    } catch (_) {
      return false;
    }
  }

  String _linksToYaml(Iterable<String> sourceLines) {
    final proxies = <Map<String, dynamic>>[];
    for (final raw in sourceLines) {
      final link = raw.trim();
      Map<String, dynamic>? proxy;
      if (link.startsWith('vless://')) proxy = _vless(link);
      if (link.startsWith('trojan://')) proxy = _trojan(link);
      if (link.startsWith('vmess://')) proxy = _vmess(link);
      if (link.startsWith('ss://')) proxy = _shadowsocks(link);
      if (proxy != null) proxies.add(proxy);
    }
    if (proxies.isEmpty) {
      throw const ProfileImportException('订阅中没有可识别的节点');
    }
    final names = proxies.map((proxy) => proxy['name'] as String).toList();
    return '''port: 17890
socks-port: 17891
mixed-port: 17892
allow-lan: false
mode: rule
log-level: info
external-controller: 127.0.0.1:9090
secret: proxy_app_ffi_demo

proxies:
${proxies.map(_yamlProxy).join('\n')}

proxy-groups:
  - name: PROXY
    type: select
    proxies:
${names.map((name) => '      - ${_quote(name)}').join('\n')}
      - DIRECT

rules:
  - MATCH,PROXY
''';
  }

  Map<String, dynamic> _vless(String link) {
    final uri = Uri.parse(link);
    if (uri.userInfo.isEmpty || uri.host.isEmpty || uri.port == 0) {
      throw const ProfileImportException('VLESS 链接缺少 UUID、主机或端口');
    }
    final query = uri.queryParameters;
    final proxy = <String, dynamic>{
      'name': _name(uri, 'VLESS ${uri.host}'),
      'type': 'vless',
      'server': uri.host,
      'port': uri.port,
      'uuid': uri.userInfo,
      'network': query['type'] ?? 'tcp',
      'udp': true,
    };
    final security = query['security'];
    if (security == 'tls' || security == 'reality') {
      proxy['tls'] = true;
      if ((query['sni'] ?? '').isNotEmpty) proxy['servername'] = query['sni'];
      if ((query['flow'] ?? '').isNotEmpty) proxy['flow'] = query['flow'];
      if ((query['fp'] ?? '').isNotEmpty) {
        proxy['client-fingerprint'] = query['fp'];
      }
    }
    if (security == 'reality') {
      proxy['reality-opts'] = {
        'public-key': query['pbk'] ?? '',
        'short-id': query['sid'] ?? '',
      };
    }
    if ((query['path'] ?? '').isNotEmpty) proxy['ws-path'] = query['path'];
    if ((query['host'] ?? '').isNotEmpty) {
      proxy['ws-headers'] = {'Host': query['host']};
    }
    return proxy;
  }

  Map<String, dynamic> _trojan(String link) {
    final uri = Uri.parse(link);
    return {
      'name': _name(uri, 'Trojan ${uri.host}'),
      'type': 'trojan',
      'server': uri.host,
      'port': uri.port,
      'password': uri.userInfo,
      'sni':
          uri.queryParameters['sni'] ?? uri.queryParameters['peer'] ?? uri.host,
      'udp': true,
    };
  }

  Map<String, dynamic> _vmess(String link) {
    final payload = link.substring('vmess://'.length);
    final decoded = _tryDecodeBase64(payload);
    if (decoded == null) {
      throw const ProfileImportException('VMess Base64 内容无效');
    }
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    return {
      'name': (json['ps'] ?? 'VMess ${json['add']}').toString(),
      'type': 'vmess',
      'server': json['add'].toString(),
      'port': int.parse(json['port'].toString()),
      'uuid': json['id'].toString(),
      'alterId': int.tryParse((json['aid'] ?? 0).toString()) ?? 0,
      'cipher': 'auto',
      'udp': true,
      if (json['tls'] == 'tls') 'tls': true,
      if ((json['sni'] ?? '').toString().isNotEmpty)
        'servername': json['sni'].toString(),
      if ((json['net'] ?? '').toString().isNotEmpty)
        'network': json['net'].toString(),
    };
  }

  Map<String, dynamic> _shadowsocks(String link) {
    final raw = link.substring('ss://'.length);
    final hash = raw.indexOf('#');
    final name = hash >= 0
        ? Uri.decodeComponent(raw.substring(hash + 1))
        : 'Shadowsocks';
    final core = hash >= 0 ? raw.substring(0, hash) : raw;
    final at = core.lastIndexOf('@');
    String credentials;
    String serverPart;
    if (at >= 0) {
      credentials =
          _tryDecodeBase64(core.substring(0, at)) ?? core.substring(0, at);
      serverPart = core.substring(at + 1);
    } else {
      final decoded = _tryDecodeBase64(core);
      if (decoded == null || !decoded.contains('@')) {
        throw const ProfileImportException('Shadowsocks 链接无效');
      }
      final decodedAt = decoded.lastIndexOf('@');
      credentials = decoded.substring(0, decodedAt);
      serverPart = decoded.substring(decodedAt + 1);
    }
    final separator = credentials.indexOf(':');
    final hostSeparator = serverPart.lastIndexOf(':');
    return {
      'name': name,
      'type': 'ss',
      'server': serverPart.substring(0, hostSeparator),
      'port': int.parse(serverPart.substring(hostSeparator + 1)),
      'cipher': credentials.substring(0, separator),
      'password': credentials.substring(separator + 1),
      'udp': true,
    };
  }

  String _yamlProxy(Map<String, dynamic> proxy) {
    final buffer = StringBuffer(
      '  - name: ${_quote(proxy['name'] as String)}\n',
    );
    for (final entry in proxy.entries) {
      if (entry.key == 'name') continue;
      if (entry.value is Map<String, dynamic>) {
        buffer.writeln('    ${entry.key}:');
        for (final child in (entry.value as Map<String, dynamic>).entries) {
          buffer.writeln('      ${child.key}: ${_scalar(child.value)}');
        }
      } else {
        buffer.writeln('    ${entry.key}: ${_scalar(entry.value)}');
      }
    }
    return buffer.toString().trimRight();
  }

  String _scalar(dynamic value) {
    if (value is bool || value is num) return '$value';
    return _quote(value.toString());
  }

  String _quote(String value) => jsonEncode(value);

  String _name(Uri uri, String fallback) => uri.fragment.isEmpty
      ? fallback
      : Uri.decodeComponent(uri.fragment).trim();

  String? _tryDecodeBase64(String input) {
    try {
      var value = input.trim().replaceAll('-', '+').replaceAll('_', '/');
      value += '=' * ((4 - value.length % 4) % 4);
      return utf8.decode(base64Decode(value));
    } catch (_) {
      return null;
    }
  }

  (int?, int?, DateTime?) _parseUsage(String? value) {
    if (value == null) return (null, null, null);
    final values = <String, int>{};
    for (final part in value.split(';')) {
      final pair = part.trim().split('=');
      if (pair.length == 2) values[pair[0]] = int.tryParse(pair[1]) ?? 0;
    }
    final used = (values['upload'] ?? 0) + (values['download'] ?? 0);
    final total = values['total'];
    final expire = values['expire'];
    return (
      used == 0 ? null : used,
      total == null || total == 0 ? null : total,
      expire == null || expire == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expire * 1000),
    );
  }
}
