import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// GitHub releases 检查器：调用 releases API 判断是否有新版本。
class UpdateChecker {
  UpdateChecker({
    this.owner = 'goodlovesky',
    this.repo = 'monorepo',
    this.currentVersion = '1.0.0',
  });

  final String owner;
  final String repo;
  final String currentVersion;

  /// 上次检查结果（持久化到 preferences.json）。
  UpdateInfo? _lastResult;
  UpdateInfo? get lastResult => _lastResult;

  /// 检查更新（异步网络请求，超时 10s）。
  Future<UpdateInfo> check({bool force = false}) async {
    if (!force && isCacheFresh(_lastResult, DateTime.now())) {
      return _lastResult!;
    }
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/releases/latest',
    );
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(url);
      req.headers.set('User-Agent', 'ClashRS/$currentVersion');
      final resp = await req.close().timeout(const Duration(seconds: 10));
      final body = await resp.transform(utf8.decoder).join();
      client.close(force: true);
      if (resp.statusCode != 200) {
        _lastResult = UpdateInfo(
          version: currentVersion,
          available: false,
          url: '',
          notes: '',
          checkedAt: DateTime.now(),
          error: 'HTTP ${resp.statusCode}',
        );
        return _lastResult!;
      }
      final root = jsonDecode(body) as Map<String, dynamic>;
      final tag = (root['tag_name'] as String? ?? '').replaceFirst('v', '');
      final htmlUrl = root['html_url'] as String? ?? '';
      final notes = root['body'] as String? ?? '';
      _lastResult = UpdateInfo(
        version: tag.isEmpty ? currentVersion : tag,
        available: _isNewer(tag, currentVersion),
        url: htmlUrl,
        notes: notes,
        checkedAt: DateTime.now(),
      );
      await _persist();
      return _lastResult!;
    } catch (e) {
      debugPrint('UpdateChecker.check failed: $e');
      _lastResult = UpdateInfo(
        version: currentVersion,
        available: false,
        url: '',
        notes: '',
        checkedAt: DateTime.now(),
        error: e.toString(),
      );
      return _lastResult!;
    }
  }

  static bool isCacheFresh(UpdateInfo? info, DateTime now) =>
      info != null &&
      !info.checkedAt.isAfter(now) &&
      now.difference(info.checkedAt) < const Duration(hours: 12);

  /// 简单 semver 比较：v1.1.0 > v1.0.0
  bool _isNewer(String remote, String local) {
    if (remote.isEmpty) return false;
    final r = _parse(remote);
    final l = _parse(local);
    if (r.$1 > l.$1) return true;
    if (r.$1 == l.$1 && r.$2 > l.$2) return true;
    if (r.$1 == l.$1 && r.$2 == l.$2 && r.$3 > l.$3) return true;
    return false;
  }

  (int, int, int) _parse(String v) {
    final parts = v
        .split(RegExp(r'[^0-9]'))
        .where((s) => s.isNotEmpty)
        .toList();
    return (
      parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    );
  }

  Future<void> _persist() async {
    final info = _lastResult;
    if (info == null) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/update-info.json');
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(info.toJson()),
        flush: true,
      );
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('UpdateChecker.persist failed: $e');
    }
  }

  /// 启动时加载上次检查结果。
  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/update-info.json');
      if (!await file.exists()) return;
      final root =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _lastResult = UpdateInfo.fromJson(root);
    } catch (_) {}
  }
}

class UpdateInfo {
  final String version;
  final bool available;
  final String url;
  final String notes;
  final DateTime checkedAt;
  final String? error;

  const UpdateInfo({
    required this.version,
    required this.available,
    required this.url,
    required this.notes,
    required this.checkedAt,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'available': available,
    'url': url,
    'notes': notes,
    'checkedAt': checkedAt.toIso8601String(),
    if (error != null) 'error': error,
  };

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
    version: json['version'] as String? ?? '',
    available: json['available'] as bool? ?? false,
    url: json['url'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    checkedAt: json['checkedAt'] is String
        ? DateTime.tryParse(json['checkedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    error: json['error'] as String?,
  );
}
