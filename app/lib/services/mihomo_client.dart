// mihomo REST API 客户端(替代之前的 FFI clash_bridge)。
//
// 端点:http://127.0.0.1:9090
// 文档:https://wiki.metacubex.one/en/api/
//
// 主要路径:
//   GET  /version
//   GET  /proxies                          全部代理组
//   GET  /proxies/{name}                   单个代理组详情
//   PUT  /proxies/{name} body {"name": "node"}  切换 selector
//   GET  /traffic?size=8                   实时流量(byte/s)
//   GET  /connections?size=N               当前连接
//   DELETE /connections                    关闭所有连接
//   POST /configs/flushfakeip
//   GET  /logs?level=info&size=200         日志
//   PATCH /configs  body {...}             改运行时配置
//   PUT   /configs?force=true  body {...}  整体热重载

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/ffi/clash_controller.dart' show TrafficStats;

class ProxyNode {
  final String name;
  final String type; // 'Selector' / 'URLTest' / 'Fallback' / 'Direct' / 'Reject' / 'Shadowsocks' ...
  final List<String> all; // 所有节点
  final String? now; // 当前节点
  final Map<String, dynamic> raw;

  ProxyNode({
    required this.name,
    required this.type,
    required this.all,
    required this.now,
    required this.raw,
  });

  factory ProxyNode.fromJson(String name, Map<String, dynamic> json) {
    final all = (json['all'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    return ProxyNode(
      name: name,
      type: json['type']?.toString() ?? 'Unknown',
      all: all,
      now: json['now']?.toString(),
      raw: json,
    );
  }
}

class MihomoClient {
  MihomoClient({this.base = 'http://127.0.0.1:9090', this.secret});

  final String base;
  final String? secret;

  Map<String, String> get _headers => {
    if (secret != null && secret!.isNotEmpty) 'Authorization': 'Bearer $secret',
    'Content-Type': 'application/json',
  };

  Uri _url(String path) => Uri.parse('$base$path');

  /// 健康检查:能拿到 /version 就算 mihomo 起来了
  Future<bool> healthCheck({int timeoutMs = 1000}) async {
    try {
      final resp = await http
          .get(_url('/version'), headers: _headers)
          .timeout(Duration(milliseconds: timeoutMs));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 拉所有代理组(Selector / URLTest / Fallback)
  Future<Map<String, ProxyNode>> getProxies() async {
    final resp = await http.get(_url('/proxies'), headers: _headers);
    if (resp.statusCode != 200) {
      throw StateError('mihomo /proxies 失败: ${resp.statusCode} ${resp.body}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final proxies = body['proxies'] as Map<String, dynamic>? ?? const {};
    return {
      for (final entry in proxies.entries)
        entry.key: ProxyNode.fromJson(
          entry.key,
          entry.value as Map<String, dynamic>,
        ),
    };
  }

  /// 切换 selector(只对 type=Selector / URLTest / Fallback 有效)
  Future<void> selectProxy(String group, String nodeName) async {
    final resp = await http.put(
      _url('/proxies/$group'),
      headers: _headers,
      body: jsonEncode({'name': nodeName}),
    );
    if (resp.statusCode != 204 && resp.statusCode != 200) {
      throw StateError(
        '切换代理失败 [$group -> $nodeName]: ${resp.statusCode} ${resp.body}',
      );
    }
  }

  /// 测单个节点延迟(ms)。null 表示超时。
  Future<int?> delayTest(
    String name, {
    String? group,
    int timeoutMs = 5000,
  }) async {
    final query = group == null
        ? '?timeout=$timeoutMs'
        : '?timeout=$timeoutMs&url=http://www.gstatic.com/generate_204';
    final resp = await http.get(
      _url('/proxies/$name$query'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return null;
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final delay =
        body['history'] is List && (body['history'] as List).isNotEmpty
        ? (body['history'] as List).last['delay'] as int?
        : null;
    return delay;
  }

  /// 实时流量(byte/s)
  Future<TrafficStats> getTraffic() async {
    final resp = await http.get(_url('/traffic'), headers: _headers);
    if (resp.statusCode != 200) {
      return TrafficStats.zero;
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return TrafficStats(
      up: (body['up'] as num? ?? 0).toInt(),
      down: (body['down'] as num? ?? 0).toInt(),
      time: DateTime.now(),
    );
  }

  /// 当前所有连接
  Future<List<dynamic>> getConnections() async {
    final resp = await http.get(_url('/connections'), headers: _headers);
    if (resp.statusCode != 200) return const [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return (body['connections'] as List? ?? const []);
  }

  /// 关闭所有连接
  Future<void> closeAllConnections() async {
    await http.delete(_url('/connections'), headers: _headers);
  }

  /// 切代理模式(rule / global / direct)
  Future<void> switchMode(String mode) async {
    final resp = await http.patch(
      _url('/configs'),
      headers: _headers,
      body: jsonEncode({'mode': mode}),
    );
    if (resp.statusCode != 204 && resp.statusCode != 200) {
      throw StateError('切换模式失败: ${resp.statusCode} ${resp.body}');
    }
  }

  /// 测一组 URLTest / Fallback 节点
  Future<Map<String, int>> groupDelay(String group) async {
    final resp = await http.get(_url('/group/$group/delay'), headers: _headers);
    if (resp.statusCode != 200) return const {};
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return body.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }
}
