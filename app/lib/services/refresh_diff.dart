import 'package:yaml/yaml.dart';

/// 配置刷新前后差异摘要。
class RefreshDiff {
  final int oldNodeCount;
  final int newNodeCount;
  final int oldGroupCount;
  final int newGroupCount;
  final int oldRuleCount;
  final int newRuleCount;
  final List<String> addedNodes;
  final List<String> removedNodes;
  final int? oldTrafficUsed;
  final int? newTrafficUsed;
  final int? oldTrafficTotal;
  final int? newTrafficTotal;
  final DateTime? oldExpiresAt;
  final DateTime? newExpiresAt;

  const RefreshDiff({
    this.oldNodeCount = 0,
    this.newNodeCount = 0,
    this.oldGroupCount = 0,
    this.newGroupCount = 0,
    this.oldRuleCount = 0,
    this.newRuleCount = 0,
    this.addedNodes = const [],
    this.removedNodes = const [],
    this.oldTrafficUsed,
    this.newTrafficUsed,
    this.oldTrafficTotal,
    this.newTrafficTotal,
    this.oldExpiresAt,
    this.newExpiresAt,
  });

  bool get hasChanges =>
      oldNodeCount != newNodeCount ||
      oldGroupCount != newGroupCount ||
      oldRuleCount != newRuleCount ||
      addedNodes.isNotEmpty ||
      removedNodes.isNotEmpty ||
      oldTrafficUsed != newTrafficUsed ||
      oldTrafficTotal != newTrafficTotal ||
      oldExpiresAt != newExpiresAt;

  /// 一行可读的摘要。
  String get summary {
    final parts = <String>[];
    final dN = newNodeCount - oldNodeCount;
    if (dN > 0) parts.add('+ $dN 节点');
    if (dN < 0) parts.add('$dN 节点');
    if (addedNodes.isNotEmpty) {
      parts.add(
        '新增 ${addedNodes.take(2).join('/')}${addedNodes.length > 2 ? '…' : ''}',
      );
    }
    if (removedNodes.isNotEmpty) {
      parts.add(
        '删除 ${removedNodes.take(2).join('/')}${removedNodes.length > 2 ? '…' : ''}',
      );
    }
    if (oldTrafficTotal != newTrafficTotal && newTrafficTotal != null) {
      final diff =
          (newTrafficTotal! - (oldTrafficTotal ?? 0)) / (1024 * 1024 * 1024);
      parts.add('${diff > 0 ? '+' : ''}${diff.toStringAsFixed(2)} GB 流量');
    }
    return parts.isEmpty ? '配置无明显变化' : parts.join(' · ');
  }

  /// 可直接呈现在审阅对话框中的完整结构化差异。
  List<String> get detailLines {
    String delta(int oldValue, int newValue) {
      final difference = newValue - oldValue;
      final suffix = difference == 0
          ? '无变化'
          : '${difference > 0 ? '+' : ''}$difference';
      return '$oldValue → $newValue（$suffix）';
    }

    String bytes(int? value) {
      if (value == null) return '未知';
      const units = ['B', 'KB', 'MB', 'GB', 'TB'];
      var amount = value.toDouble();
      var unit = 0;
      while (amount >= 1024 && unit < units.length - 1) {
        amount /= 1024;
        unit += 1;
      }
      return '${amount.toStringAsFixed(unit == 0 ? 0 : 2)} ${units[unit]}';
    }

    String date(DateTime? value) => value == null
        ? '未知'
        : '${value.year.toString().padLeft(4, '0')}-'
              '${value.month.toString().padLeft(2, '0')}-'
              '${value.day.toString().padLeft(2, '0')}';

    return [
      '节点：${delta(oldNodeCount, newNodeCount)}',
      '代理组：${delta(oldGroupCount, newGroupCount)}',
      '规则：${delta(oldRuleCount, newRuleCount)}',
      '新增节点：${addedNodes.isEmpty ? '无' : addedNodes.join('、')}',
      '删除节点：${removedNodes.isEmpty ? '无' : removedNodes.join('、')}',
      '已用流量：${bytes(oldTrafficUsed)} → ${bytes(newTrafficUsed)}',
      '总流量：${bytes(oldTrafficTotal)} → ${bytes(newTrafficTotal)}',
      '到期时间：${date(oldExpiresAt)} → ${date(newExpiresAt)}',
    ];
  }

  /// 对比两份 yaml 文本，返回结构化差异。
  static RefreshDiff compute(String oldYaml, String newYaml) {
    int oldNodes = 0, newNodes = 0, oldGroups = 0, newGroups = 0;
    int oldRules = 0, newRules = 0;
    Set<String> oldNodeNames = {}, newNodeNames = {};
    int? oldUsed, newUsed, oldTotal, newTotal;
    DateTime? oldExpire, newExpire;

    try {
      final old = loadYaml(oldYaml) as YamlMap?;
      if (old != null) {
        final proxies = old['proxies'];
        if (proxies is YamlList) {
          oldNodes = proxies.length;
          for (final p in proxies) {
            if (p is YamlMap) {
              final n = p['name']?.toString();
              if (n != null) oldNodeNames.add(n);
            }
          }
        }
        final groups = old['proxy-groups'];
        if (groups is YamlList) oldGroups = groups.length;
        final rules = old['rules'];
        if (rules is YamlList) oldRules = rules.length;
      }
    } catch (_) {}

    try {
      final n = loadYaml(newYaml) as YamlMap?;
      if (n != null) {
        final proxies = n['proxies'];
        if (proxies is YamlList) {
          newNodes = proxies.length;
          for (final p in proxies) {
            if (p is YamlMap) {
              final name = p['name']?.toString();
              if (name != null) newNodeNames.add(name);
            }
          }
        }
        final groups = n['proxy-groups'];
        if (groups is YamlList) newGroups = groups.length;
        final rules = n['rules'];
        if (rules is YamlList) newRules = rules.length;
      }
    } catch (_) {}

    // 元信息：mihomo/clash 习惯在 yaml 顶部用注释写流量/到期
    // 我们的 importer 已经把 expires/total 写到 profile，这里从注释行兜底解析
    final oldMeta = _parseMetaText(oldYaml);
    final newMeta = _parseMetaText(newYaml);
    oldUsed = oldMeta.used;
    newUsed = newMeta.used;
    oldTotal = oldMeta.total;
    newTotal = newMeta.total;
    oldExpire = oldMeta.expire;
    newExpire = newMeta.expire;

    return RefreshDiff(
      oldNodeCount: oldNodes,
      newNodeCount: newNodes,
      oldGroupCount: oldGroups,
      newGroupCount: newGroups,
      oldRuleCount: oldRules,
      newRuleCount: newRules,
      addedNodes: newNodeNames.difference(oldNodeNames).toList(),
      removedNodes: oldNodeNames.difference(newNodeNames).toList(),
      oldTrafficUsed: oldUsed,
      newTrafficUsed: newUsed,
      oldTrafficTotal: oldTotal,
      newTrafficTotal: newTotal,
      oldExpiresAt: oldExpire,
      newExpiresAt: newExpire,
    );
  }

  /// 从 yaml 文本里抽 `# upload=NN, total=NN, expire=YYYY-MM-DD` 风格的注释行。
  static _MetaInfo _parseMetaText(String yaml) {
    int? used, total;
    DateTime? expire;
    for (final line in yaml.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('#')) continue;
      final body = trimmed.substring(1).toLowerCase();
      final upMatch = RegExp(r'upload\s*[:=]\s*(\d+)').firstMatch(body);
      if (upMatch != null) used = int.tryParse(upMatch.group(1)!);
      final totalMatch = RegExp(r'total\s*[:=]\s*(\d+)').firstMatch(body);
      if (totalMatch != null) total = int.tryParse(totalMatch.group(1)!);
      final expMatch = RegExp(r'expire\w*\s*[:=]\s*(\d{4}-\d{2}-\d{2})')
          .firstMatch(body);
      if (expMatch != null) {
        expire = DateTime.tryParse(expMatch.group(1)!);
      }
      if (used != null && total != null && expire != null) break;
    }
    return _MetaInfo(used: used, total: total, expire: expire);
  }
}

class _MetaInfo {
  final int? used;
  final int? total;
  final DateTime? expire;
  const _MetaInfo({this.used, this.total, this.expire});
}
