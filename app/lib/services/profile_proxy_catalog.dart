import 'dart:io';

import 'package:yaml/yaml.dart';

import '../core/ffi/clash_controller.dart';

/// 从已保存的订阅 YAML 构建离线节点目录。
///
/// mihomo 未启动时 external-controller 没有 `/proxies` 可读，但订阅文件本身
/// 已经包含节点与代理组。代理页使用这份目录显示节点；核心启动后再由实时 API
/// 数据覆盖它。
class ProfileProxyCatalog {
  const ProfileProxyCatalog();

  Future<Map<String, ProxyGroup>> fromFile(String path) async =>
      fromYaml(await File(path).readAsString());

  Map<String, ProxyGroup> fromYaml(String source) {
    final document = loadYaml(source);
    if (document is! YamlMap) return const {};

    final nodeTypes = <String, String>{'DIRECT': 'Direct', 'REJECT': 'Reject'};
    final nodeUdp = <String, bool>{'DIRECT': true, 'REJECT': true};
    final nodeNames = <String>[];
    final rawNodes = document['proxies'];
    if (rawNodes is YamlList) {
      for (final raw in rawNodes) {
        if (raw is! YamlMap) continue;
        final name = raw['name']?.toString().trim() ?? '';
        if (name.isEmpty || nodeTypes.containsKey(name)) continue;
        nodeNames.add(name);
        nodeTypes[name] = _displayType(raw['type']?.toString());
        nodeUdp[name] = raw['udp'] != false;
      }
    }

    final result = <String, ProxyGroup>{};
    final rawGroups = document['proxy-groups'];
    if (rawGroups is YamlList) {
      for (final raw in rawGroups) {
        if (raw is! YamlMap) continue;
        final name = raw['name']?.toString().trim() ?? '';
        final members = _strings(raw['proxies']);
        if (name.isEmpty || members.isEmpty) continue;
        result[name] = ProxyGroup(
          name: name,
          type: raw['type']?.toString() ?? 'select',
          all: members,
          now: members.first,
          nodeTypes: {
            for (final member in members) member: nodeTypes[member] ?? 'Proxy',
          },
          nodeUdp: {
            for (final member in members) member: nodeUdp[member] ?? true,
          },
        );
      }
    }

    // Mihomo 运行时会提供 GLOBAL；离线时补出同等的全节点视图，确保已导入
    // 的订阅即使核心停止也能像原版一样浏览 DIRECT、REJECT 与全部节点。
    final allNodes = <String>['DIRECT', 'REJECT', ...nodeNames];
    if (allNodes.length > 2 && !result.containsKey('GLOBAL')) {
      result['GLOBAL'] = ProxyGroup(
        name: 'GLOBAL',
        type: 'select',
        all: allNodes,
        now: nodeNames.first,
        nodeTypes: {
          for (final node in allNodes) node: nodeTypes[node] ?? 'Proxy',
        },
        nodeUdp: {for (final node in allNodes) node: nodeUdp[node] ?? true},
      );
    }
    return result;
  }

  List<String> _strings(dynamic value) => value is YamlList
      ? value
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList()
      : const [];

  String _displayType(String? type) => switch (type?.toLowerCase()) {
    'ss' => 'Shadowsocks',
    'ssr' => 'ShadowsocksR',
    'vmess' => 'Vmess',
    'vless' => 'Vless',
    'trojan' => 'Trojan',
    'hysteria2' || 'hy2' => 'Hysteria2',
    'tuic' => 'TUIC',
    'wireguard' => 'WireGuard',
    final value when value != null && value.isNotEmpty => value,
    _ => 'Proxy',
  };
}
