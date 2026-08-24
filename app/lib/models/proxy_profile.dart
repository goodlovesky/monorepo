import 'dart:convert';

class ProxyProfile {
  final String id;
  final String name;
  final String sourceType;
  final String? source;
  final String localYamlPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastCheckedAt;
  final int? autoUpdateIntervalMinutes;
  final int? usedTrafficBytes;
  final int? totalTrafficBytes;
  final DateTime? expiresAt;
  final bool active;

  const ProxyProfile({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.localYamlPath,
    required this.createdAt,
    required this.updatedAt,
    this.source,
    this.lastCheckedAt,
    this.autoUpdateIntervalMinutes,
    this.usedTrafficBytes,
    this.totalTrafficBytes,
    this.expiresAt,
    this.active = false,
  });

  ProxyProfile copyWith({
    String? name,
    String? sourceType,
    String? source,
    String? localYamlPath,
    DateTime? updatedAt,
    DateTime? lastCheckedAt,
    int? autoUpdateIntervalMinutes,
    int? usedTrafficBytes,
    int? totalTrafficBytes,
    DateTime? expiresAt,
    bool? active,
  }) => ProxyProfile(
    id: id,
    name: name ?? this.name,
    sourceType: sourceType ?? this.sourceType,
    source: source ?? this.source,
    localYamlPath: localYamlPath ?? this.localYamlPath,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    autoUpdateIntervalMinutes:
        autoUpdateIntervalMinutes ?? this.autoUpdateIntervalMinutes,
    usedTrafficBytes: usedTrafficBytes ?? this.usedTrafficBytes,
    totalTrafficBytes: totalTrafficBytes ?? this.totalTrafficBytes,
    expiresAt: expiresAt ?? this.expiresAt,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sourceType': sourceType,
    'source': source,
    'localYamlPath': localYamlPath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastCheckedAt': lastCheckedAt?.toIso8601String(),
    'autoUpdateIntervalMinutes': autoUpdateIntervalMinutes,
    'usedTrafficBytes': usedTrafficBytes,
    'totalTrafficBytes': totalTrafficBytes,
    'expiresAt': expiresAt?.toIso8601String(),
    'active': active,
  };

  factory ProxyProfile.fromJson(Map<String, dynamic> json) => ProxyProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    sourceType: json['sourceType'] as String? ?? 'file',
    source: json['source'] as String?,
    localYamlPath: json['localYamlPath'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    lastCheckedAt: _date(json['lastCheckedAt']),
    autoUpdateIntervalMinutes: (json['autoUpdateIntervalMinutes'] as num?)
        ?.toInt(),
    usedTrafficBytes: (json['usedTrafficBytes'] as num?)?.toInt(),
    totalTrafficBytes: (json['totalTrafficBytes'] as num?)?.toInt(),
    expiresAt: _date(json['expiresAt']),
    active: json['active'] == true,
  );

  static DateTime? _date(dynamic value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

  static String encodeList(List<ProxyProfile> profiles) =>
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'profiles': profiles.map((profile) => profile.toJson()).toList(),
      });

  static List<ProxyProfile> decodeList(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    return ((root['profiles'] as List?) ?? const [])
        .map((item) => ProxyProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
