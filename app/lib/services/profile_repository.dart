import 'dart:io';

import '../models/proxy_profile.dart';

class ProfileRepository {
  /// 首次安装时默认写入的 Clash 配置。
  /// 不内置任何真实节点；只放一个 type: direct 的占位代理 + PROXY 代理组，
  /// 让代理页能正常显示分组。用户需走"订阅"页面导入或刷新真实节点。
  static const defaultConfig = '''port: 17890
socks-port: 17891
mixed-port: 17892
allow-lan: false
mode: rule
log-level: info
external-controller: 127.0.0.1:9090
secret: proxy_app_ffi_demo
proxies:
  - name: DIRECT
    type: direct
    udp: true
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - DIRECT
rules:
  - MATCH,PROXY
''';

  final Directory supportDirectory;

  ProfileRepository(this.supportDirectory);

  Directory get profilesDirectory =>
      Directory('${supportDirectory.path}/profiles');
  File get indexFile => File('${profilesDirectory.path}/index.json');

  Future<List<ProxyProfile>> initialize() async {
    await profilesDirectory.create(recursive: true);
    if (await indexFile.exists()) {
      final profiles = ProxyProfile.decodeList(await indexFile.readAsString());
      if (profiles.isNotEmpty) {
        final migrated = await _migrateLegacyDefaultConfig(profiles);
        return _ensureOneActive(migrated);
      }
    }

    final legacy = File('${supportDirectory.path}/config.yaml');
    if (!await legacy.exists()) {
      throw const FileSystemException('缺少默认 Clash 配置');
    }
    final now = DateTime.now();
    final id = 'default';
    final directory = Directory('${profilesDirectory.path}/$id');
    await directory.create(recursive: true);
    final target = File('${directory.path}/config.yaml');
    await target.writeAsString(await legacy.readAsString(), flush: true);
    final profiles = [
      ProxyProfile(
        id: id,
        name: '新配置',
        sourceType: 'local',
        localYamlPath: target.path,
        createdAt: now,
        updatedAt: now,
        active: true,
      ),
    ];
    await saveIndex(profiles);
    return profiles;
  }

  /// 一次性迁移：早期版本默认 config.yaml 只有 ports/dns/rules，缺少
  /// proxies/proxy-groups，导致代理页一片空白。这里检测到 default profile
  /// 没节点时，用最新 defaultConfig 重写一次，保留订阅 source/url 等元信息。
  Future<List<ProxyProfile>> _migrateLegacyDefaultConfig(
    List<ProxyProfile> profiles,
  ) async {
    final defaultIndex = profiles.indexWhere((p) => p.id == 'default');
    if (defaultIndex < 0) return profiles;
    final defaultProfile = profiles[defaultIndex];
    if (defaultProfile.localYamlPath.isEmpty) return profiles;
    final yamlFile = File(defaultProfile.localYamlPath);
    if (!await yamlFile.exists()) return profiles;
    final yaml = await yamlFile.readAsString();
    if (_hasProxyEntries(yaml)) return profiles;
    await yamlFile.writeAsString(defaultConfig, flush: true);
    final next = [...profiles];
    next[defaultIndex] = defaultProfile.copyWith(updatedAt: DateTime.now());
    return next;
  }

  /// 简单检测：顶层 key 中是否含 `proxies:` / `proxy-groups:`。
  bool _hasProxyEntries(String yaml) {
    return RegExp(r'^proxies\s*:', multiLine: true).hasMatch(yaml) ||
        RegExp(r'^proxy-groups\s*:', multiLine: true).hasMatch(yaml);
  }

  Future<List<ProxyProfile>> load() async =>
      _ensureOneActive(ProxyProfile.decodeList(await indexFile.readAsString()));

  Future<ProxyProfile> saveProfile({
    ProxyProfile? existing,
    required String name,
    required String sourceType,
    required String yaml,
    String? source,
    int? autoUpdateIntervalMinutes,
    int? usedTrafficBytes,
    int? totalTrafficBytes,
    DateTime? expiresAt,
  }) async {
    final profiles = await load();
    final now = DateTime.now();
    final id = existing?.id ?? 'profile-${now.microsecondsSinceEpoch}';
    final directory = Directory('${profilesDirectory.path}/$id');
    await directory.create(recursive: true);
    final yamlFile = File('${directory.path}/config.yaml');
    final previousYaml = await yamlFile.exists()
        ? await yamlFile.readAsBytes()
        : null;
    final profile = ProxyProfile(
      id: id,
      name: name.trim().isEmpty ? '新配置' : name.trim(),
      sourceType: sourceType,
      source: source,
      localYamlPath: yamlFile.path,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      lastCheckedAt: now,
      autoUpdateIntervalMinutes: autoUpdateIntervalMinutes,
      usedTrafficBytes: usedTrafficBytes,
      totalTrafficBytes: totalTrafficBytes,
      expiresAt: expiresAt,
      active: existing?.active ?? profiles.isEmpty,
    );
    final next = profiles.where((item) => item.id != id).toList()..add(profile);
    try {
      await _atomicWrite(yamlFile, yaml);
      await saveIndex(_ensureOneActive(next));
    } catch (_) {
      if (previousYaml == null) {
        if (await yamlFile.exists()) await yamlFile.delete();
      } else {
        await yamlFile.writeAsBytes(previousYaml, flush: true);
      }
      rethrow;
    }
    return profile;
  }

  Future<List<ProxyProfile>> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('配置名称不能为空');
    final profiles = await load();
    if (!profiles.any((item) => item.id == id)) {
      throw const FileSystemException('配置不存在');
    }
    final next = profiles
        .map((item) => item.id == id ? item.copyWith(name: trimmed) : item)
        .toList();
    await saveIndex(next);
    return next;
  }

  Future<List<ProxyProfile>> activate(String id) async {
    final profiles = await load();
    final next = profiles
        .map((item) => item.copyWith(active: item.id == id))
        .toList();
    await saveIndex(next);
    return next;
  }

  Future<List<ProxyProfile>> delete(String id) async {
    final profiles = await load();
    if (profiles.length <= 1) {
      throw const FileSystemException('至少保留一个配置');
    }
    final deleting = profiles.firstWhere((item) => item.id == id);
    final next = profiles.where((item) => item.id != id).toList();
    if (deleting.active) {
      next[0] = next[0].copyWith(active: true);
    }
    await saveIndex(next);
    final directory = Directory('${profilesDirectory.path}/$id');
    if (await directory.exists()) await directory.delete(recursive: true);
    return next;
  }

  Future<void> saveIndex(List<ProxyProfile> profiles) =>
      _atomicWrite(indexFile, ProxyProfile.encodeList(profiles));

  List<ProxyProfile> _ensureOneActive(List<ProxyProfile> profiles) {
    if (profiles.isEmpty || profiles.any((item) => item.active)) {
      return profiles;
    }
    final copy = [...profiles];
    copy[0] = copy[0].copyWith(active: true);
    return copy;
  }

  Future<void> _atomicWrite(File target, String contents) async {
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(target.path);
  }
}
