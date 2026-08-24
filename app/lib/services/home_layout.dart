import 'dart:convert';

/// 首页布局（卡片顺序 + 隐藏项），存到 AppSettings.meta。
///
/// 序列化键：key=`home.layout`，value=JSON 字符串。
class HomeLayout {
  /// 用户定义的卡片顺序。缺失的卡片会按默认顺序补在后面。
  final List<String> order;

  /// 被用户隐藏的卡片 id 集合。
  final Set<String> hidden;

  const HomeLayout({this.order = const [], this.hidden = const {}});

  static const defaultOrder = <String>[
    'subscription',
    'currentNode',
    'network',
    'proxyMode',
    'traffic',
    'metrics',
    'siteTest',
    'ipInfo',
    'clashInfo',
    'systemInfo',
  ];

  HomeLayout copyWith({List<String>? order, Set<String>? hidden}) =>
      HomeLayout(order: order ?? this.order, hidden: hidden ?? this.hidden);

  /// 计算最终渲染顺序：先按用户 order 排，再把默认顺序里没出现的补上。
  List<String> resolvedOrder() {
    final seen = <String>{};
    final out = <String>[];
    for (final id in order) {
      if (defaultOrder.contains(id) && seen.add(id)) {
        out.add(id);
      }
    }
    for (final id in defaultOrder) {
      if (seen.add(id)) out.add(id);
    }
    return out;
  }

  bool isHidden(String id) => hidden.contains(id);

  Map<String, dynamic> toJson() => {'order': order, 'hidden': hidden.toList()};

  factory HomeLayout.fromJson(Map<String, dynamic> json) => HomeLayout(
    order: ((json['order'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    hidden: ((json['hidden'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet(),
  );

  static HomeLayout fromMetaString(String? raw) {
    if (raw == null || raw.isEmpty) return const HomeLayout();
    try {
      final map = json.decode(raw);
      if (map is Map<String, dynamic>) return HomeLayout.fromJson(map);
    } catch (_) {}
    return const HomeLayout();
  }

  String encode() => json.encode(toJson());
}

/// 卡片元数据：id → 中文标题 + 图标。
class HomeCardMeta {
  final String id;
  final String title;
  final String icon; // Material icon codepoint as string for portability
  const HomeCardMeta(this.id, this.title, this.icon);
}

const homeCardMetas = <String, HomeCardMeta>{
  'subscription': HomeCardMeta('subscription', '订阅概览', 'cloud'),
  'currentNode': HomeCardMeta('currentNode', '当前节点', 'router'),
  'network': HomeCardMeta('network', '网络模式', 'wifi'),
  'proxyMode': HomeCardMeta('proxyMode', '代理模式', 'shuffle'),
  'traffic': HomeCardMeta('traffic', '实时流量', 'speed'),
  'metrics': HomeCardMeta('metrics', '关键指标', 'insights'),
  'siteTest': HomeCardMeta('siteTest', '站点测试', 'public'),
  'ipInfo': HomeCardMeta('ipInfo', 'IP 信息', 'language'),
  'clashInfo': HomeCardMeta('clashInfo', '内核信息', 'memory'),
  'systemInfo': HomeCardMeta('systemInfo', '系统信息', 'computer'),
};
