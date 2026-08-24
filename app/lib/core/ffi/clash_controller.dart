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

class ProxyGroup {
  final String name;
  final String type; // select / url-test / fallback / load-balance
  final List<String> all;
  final String now; // 当前选中的
  final Map<String, int> delays; // 节点名 -> 延迟 ms（可选）
  final Map<String, String> nodeTypes; // 节点名 -> 协议类型
  final Map<String, bool> nodeUdp; // 节点名 -> UDP 支持状态

  ProxyGroup({
    required this.name,
    required this.type,
    required this.all,
    required this.now,
    this.delays = const {},
    this.nodeTypes = const {},
    this.nodeUdp = const {},
  });

  factory ProxyGroup.fromJson(String name, Map<String, dynamic> json) {
    return ProxyGroup(
      name: name,
      type: json['type'] as String? ?? 'unknown',
      all: ((json['all'] as List?) ?? []).map((e) => e.toString()).toList(),
      now: json['now'] as String? ?? '',
    );
  }

  ProxyGroup copyWith({
    String? now,
    Map<String, int>? delays,
    Map<String, String>? nodeTypes,
    Map<String, bool>? nodeUdp,
  }) => ProxyGroup(
    name: name,
    type: type,
    all: all,
    now: now ?? this.now,
    delays: delays ?? this.delays,
    nodeTypes: nodeTypes ?? this.nodeTypes,
    nodeUdp: nodeUdp ?? this.nodeUdp,
  );
}

class TrafficStats {
  final int up;
  final int down;
  final int? upTotal;
  final int? downTotal;
  final DateTime time;
  const TrafficStats({
    required this.up,
    required this.down,
    this.upTotal,
    this.downTotal,
    required this.time,
  });
  static final zero = TrafficStats(
    up: 0,
    down: 0,
    time: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class ConnectionSnapshot {
  final List<Map<String, dynamic>> connections;
  final int uploadTotal;
  final int downloadTotal;

  const ConnectionSnapshot({
    required this.connections,
    required this.uploadTotal,
    required this.downloadTotal,
  });
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
      final group = ProxyGroup.fromJson(name, data);
      result[name] = group.copyWith(
        nodeTypes: {
          for (final nodeName in group.all)
            nodeName:
                (proxies[nodeName] as Map<String, dynamic>?)?['type']
                    ?.toString() ??
                'Proxy',
        },
        nodeUdp: {
          for (final nodeName in group.all)
            nodeName:
                (proxies[nodeName] as Map<String, dynamic>?)?['udp'] == true,
        },
      );
    }
    return result;
  }

  /// 切换节点
  Future<void> selectNode(String group, String name) async {
    await _put('/proxies/$group', body: {'name': name});
  }

  /// 健康检查（单节点）
  Future<int> healthCheck(
    String group,
    String name, {
    Duration? timeout,
  }) async {
    final t = timeout ?? const Duration(milliseconds: 5000);
    final body = await _get(
      '/proxies/$name/delay',
      query: {
        'url': 'https://www.gstatic.com/generate_204',
        'timeout': t.inMilliseconds.toString(),
      },
    );
    final json = jsonDecode(body) as Map<String, dynamic>;
    final delay = (json['delay'] as num?)?.toInt();
    if (delay == null || delay <= 0) {
      throw StateError('节点测速未返回有效延迟：$name');
    }
    return delay;
  }

  /// 健康检查（整组）
  Future<Map<String, int>> healthCheckGroup(
    String group, {
    Duration? timeout,
  }) async {
    final t = timeout ?? const Duration(milliseconds: 5000);
    final body = await _get(
      '/proxies/$group/delay',
      query: {
        'url': 'https://www.gstatic.com/generate_204',
        'timeout': t.inMilliseconds.toString(),
      },
    );
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json.map((k, v) => MapEntry(k, v as int));
  }

  /// 流量统计
  Future<TrafficStats> getTraffic() async {
    final json = await _getFirstJsonFrame('/traffic');
    return TrafficStats(
      up: (json['up'] as num?)?.toInt() ?? 0,
      down: (json['down'] as num?)?.toInt() ?? 0,
      upTotal: (json['upTotal'] as num?)?.toInt(),
      downTotal: (json['downTotal'] as num?)?.toInt(),
      time: DateTime.now(),
    );
  }

  /// 内存占用（MB）。mihomo 的首帧可能为 0，读取第二帧取得实际值。
  Future<int> getMemory() async {
    final frames = await _getJsonFrames('/memory', count: 2);
    final bytes = frames
        .map((frame) => (frame['inuse'] as num?)?.toInt() ?? 0)
        .fold<int>(0, (current, value) => value > current ? value : current);
    return (bytes / 1024 / 1024).round();
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

  Future<ConnectionSnapshot> getConnectionSnapshot() async {
    final body = await _get('/connections');
    final json = jsonDecode(body) as Map<String, dynamic>;
    final connections = ((json['connections'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return ConnectionSnapshot(
      connections: connections,
      uploadTotal: (json['uploadTotal'] as num?)?.toInt() ?? 0,
      downloadTotal: (json['downloadTotal'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<Map<String, dynamic>>> getConnections() async =>
      (await getConnectionSnapshot()).connections;

  Future<void> closeConnection(String id) async {
    await _delete('/connections/${Uri.encodeComponent(id)}');
  }

  Future<void> closeAllConnections() async {
    await _delete('/connections');
  }

  Future<List<Map<String, dynamic>>> getRules() async {
    final body = await _get('/rules');
    final json = jsonDecode(body) as Map<String, dynamic>;
    return ((json['rules'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// 订阅 mihomo `/logs` NDJSON 实时流。取消监听会立即关闭连接。
  Stream<Map<String, dynamic>> watchLogs({String level = 'info'}) async* {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(_buildUri('/logs', {'level': level}));
      _headers.forEach((key, value) => request.headers.add(key, value));
      final response = await request.close();
      if (response.statusCode >= 400) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        final value = jsonDecode(line);
        if (value is Map) yield Map<String, dynamic>.from(value);
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> setMode(String mode) async {
    await _patch('/configs', body: {'mode': mode});
  }

  // ============================================================
  // HTTP 客户端底层
  // ============================================================

  Map<String, String> get _headers {
    final h = <String, String>{'Accept': 'application/json'};
    if (secret != null && secret!.isNotEmpty) {
      h['Authorization'] = 'Bearer $secret';
    }
    return h;
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    return base.replace(path: '${base.path}$path', queryParameters: query);
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

  /// mihomo 的 /traffic 和 /memory 是不会主动结束的 NDJSON 流。
  /// 普通 `_get` 会一直等待连接关闭，因此这里按行取得有限帧后立即断开。
  Future<Map<String, dynamic>> _getFirstJsonFrame(String path) async {
    return (await _getJsonFrames(path, count: 1)).first;
  }

  Future<List<Map<String, dynamic>>> _getJsonFrames(
    String path, {
    required int count,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(_buildUri(path));
      _headers.forEach((k, v) => req.headers.add(k, v));
      final resp = await req.close();
      if (resp.statusCode >= 400) {
        throw HttpException(
          'HTTP ${resp.statusCode}: ${await resp.transform(utf8.decoder).join()}',
        );
      }
      final frames = <Map<String, dynamic>>[];
      final completed = Completer<List<Map<String, dynamic>>>();
      late final StreamSubscription<String> subscription;
      subscription = resp
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.trim().isEmpty || completed.isCompleted) return;
              try {
                frames.add(
                  Map<String, dynamic>.from(
                    jsonDecode(line) as Map<String, dynamic>,
                  ),
                );
                if (frames.length >= count) {
                  completed.complete(List.unmodifiable(frames));
                  unawaited(subscription.cancel());
                }
              } catch (exception, stackTrace) {
                completed.completeError(exception, stackTrace);
                unawaited(subscription.cancel());
              }
            },
            onError: (Object exception, StackTrace stackTrace) {
              if (!completed.isCompleted) {
                completed.completeError(exception, stackTrace);
              }
            },
            onDone: () {
              if (!completed.isCompleted) {
                if (frames.isEmpty) {
                  completed.completeError(const FormatException('实时接口未返回数据帧'));
                } else {
                  completed.complete(List.unmodifiable(frames));
                }
              }
            },
            cancelOnError: true,
          );
      return await completed.future.timeout(
        timeout + const Duration(seconds: 2),
      );
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

  Future<String> _patch(String path, {Map<String, dynamic>? body}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.patchUrl(_buildUri(path));
      _headers.forEach((k, v) => req.headers.add(k, v));
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      return await _readBody(await req.close());
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _delete(String path) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.deleteUrl(_buildUri(path));
      _headers.forEach((k, v) => req.headers.add(k, v));
      return await _readBody(await req.close());
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
        result[m.group(1)!] = m
            .group(2)!
            .replaceAll(RegExp(r"""^["']|["']$"""), '');
      }
    }
    return result;
  }

  /// 解析 external-controller: host:port 格式
  static ({String host, int port, String secret})? parseController(
    String yaml,
  ) {
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
