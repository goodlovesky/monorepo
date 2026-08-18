// lib/core/ffi/clash_controller.dart
//
// Clash controller HTTP API client
// 调 clash 内核的 external-controller HTTP API 来：
//   - 列出所有代理组 / 节点
//   - 切换节点
//   - 流量统计
//   - 健康检查
//   - 订阅更新
//
// clash-lib 0.8.2 的 API 都是 async，从同步 FFI 调很难。
// 所以我们走 HTTP API（更标准 + 跟原版 Clash for Android 一样）。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ProxyGroup {
  final String name;
  final String type; // select / url-test / fallback / load-balance
  final List<String> all;
  final String now; // 当前选中的
  final Map<String, int> delays; // 节点名 -> 延迟 ms（可选）

  ProxyGroup({
    required this.name,
    required this.type,
    required this.all,
    required this.now,
    this.delays = const {},
  });

  factory ProxyGroup.fromJson(String name, Map<String, dynamic> json) {
    return ProxyGroup(
      name: name,
      type: json['type'] as String? ?? 'unknown',
      all: ((json['all'] as List?) ?? []).map((e) => e.toString()).toList(),
      now: json['now'] as String? ?? '',
    );
  }

  ProxyGroup copyWith({Map<String, int>? delays}) => ProxyGroup(
        name: name,
        type: type,
        all: all,
        now: now,
        delays: delays ?? this.delays,
      );
}

class TrafficStats {
  final int up;
  final int down;
  const TrafficStats({required this.up, required this.down});
  static const zero = TrafficStats(up: 0, down: 0);
}

class ClashController {
  final String baseUrl;
  final String? secret;
  final Duration timeout;

  ClashController({
    required this.baseUrl,
    this.secret,
    this.timeout = const Duration(seconds: 3),
  });

  /// 列出所有代理组 + 节点信息
  Future<Map<String, ProxyGroup>> getProxies() async {
    final body = await _get('/proxies');
    final json = jsonDecode(body) as Map<String, dynamic>;
    final proxies = json['proxies'] as Map<String, dynamic>;

    final result = <String, ProxyGroup>{};
    for (final entry in proxies.entries) {
      final name = entry.key;
      final data = entry.value as Map<String, dynamic>;
      result[name] = ProxyGroup.fromJson(name, data);
    }
    return result;
  }

  /// 切换节点
  Future<void> selectNode(String group, String name) async {
    await _put('/proxies/$group', body: {'name': name});
  }

  /// 健康检查（单节点）
  Future<int> healthCheck(String group, String name, {Duration? timeout}) async {
    final t = timeout ?? const Duration(milliseconds: 5000);
    final body = await _get(
      '/proxies/$group/delay',
      query: {
        'url': 'http://www.gstatic.com/generate_204',
        'timeout': t.inMilliseconds.toString(),
      },
    );
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json[name] as int? ?? 0;
  }

  /// 健康检查（整组）
  Future<Map<String, int>> healthCheckGroup(String group, {Duration? timeout}) async {
    final t = timeout ?? const Duration(milliseconds: 5000);
    final body = await _get(
      '/proxies/$group/delay',
      query: {
        'url': 'http://www.gstatic.com/generate_204',
        'timeout': t.inMilliseconds.toString(),
      },
    );
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json.map((k, v) => MapEntry(k, v as int));
  }

  /// 流量统计
  Future<TrafficStats> getTraffic() async {
    try {
      final body = await _get('/traffic');
      final json = jsonDecode(body) as Map<String, dynamic>;
      return TrafficStats(
        up: (json['up'] as num?)?.toInt() ?? 0,
        down: (json['down'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      return TrafficStats.zero;
    }
  }

  /// 列出所有订阅
  Future<Map<String, dynamic>> getProviders() async {
    final body = await _get('/providers');
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// 触发订阅更新
  Future<void> updateProvider(String name) async {
    await _put('/providers/$name');
  }

  // ============================================================
  // HTTP 客户端底层
  // ============================================================

  Map<String, String> get _headers {
    final h = <String, String>{
      'Accept': 'application/json',
    };
    if (secret != null && secret!.isNotEmpty) {
      h['Authorization'] = 'Bearer $secret';
    }
    return h;
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: '${base.path}$path',
      queryParameters: query,
    );
  }

  Future<String> _get(String path, {Map<String, String>? query}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(_buildUri(path, query));
      _headers.forEach((k, v) => req.headers.add(k, v));
      final resp = await req.close();
      return await _readBody(resp);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _put(String path, {Map<String, dynamic>? body}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.putUrl(_buildUri(path));
      _headers.forEach((k, v) => req.headers.add(k, v));
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final resp = await req.close();
      return await _readBody(resp);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _readBody(HttpClientResponse resp) async {
    final body = await resp.transform(utf8.decoder).join();
    if (resp.statusCode >= 400) {
      throw HttpException('HTTP ${resp.statusCode}: $body');
    }
    return body;
  }
}

/// 从 config.yaml 里解析 external-controller 端口和 secret
class ClashConfigParser {
  /// 简单 YAML 解析（只支持我们的最小配置格式）
  static Map<String, String> parseSimpleYaml(String yaml) {
    final result = <String, String>{};
    for (final line in yaml.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final m = RegExp(r'^([\w-]+):\s*(.+)$').firstMatch(trimmed);
      if (m != null) {
        // raw string: 匹配开头/结尾的 " 或 '
        result[m.group(1)!] = m.group(2)!.replaceAll(RegExp(r"""^["']|["']$"""), '');
      }
    }
    return result;
  }

  /// 解析 external-controller: host:port 格式
  static ({String host, int port, String secret})? parseController(String yaml) {
    final map = parseSimpleYaml(yaml);
    final controller = map['external-controller'];
    if (controller == null) return null;
    final parts = controller.split(':');
    if (parts.length != 2) return null;
    return (
      host: parts[0],
      port: int.tryParse(parts[1]) ?? 0,
      secret: map['secret'] ?? '',
    );
  }
}
