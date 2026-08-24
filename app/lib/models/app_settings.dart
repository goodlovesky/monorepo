class AppSettings {
  final bool autoRestart;
  final String darkMode;
  final bool hideLauncher;
  final bool hideRecents;
  final bool showTraffic;
  final bool autoRoute;
  final bool bypassPrivate;
  final bool dnsHijack;
  final bool allowBypass;
  final bool ipv6;
  final bool systemProxy;
  final String stackMode;
  final String accessMode;
  final List<String> accessPackages;
  final Map<String, String> overrides;
  final Map<String, String> meta;
  final bool closeToTray;
  final bool launchAtStartup;
  final bool silentStart;
  final bool animations;
  final bool notifications;
  final bool allowLan;
  final bool dnsEnabled;
  final bool unifiedDelay;
  final String language;
  final String accentColor;
  final String homeSection;
  final String logLevel;

  const AppSettings({
    this.autoRestart = false,
    this.darkMode = 'system',
    this.hideLauncher = false,
    this.hideRecents = false,
    this.showTraffic = true,
    this.autoRoute = true,
    this.bypassPrivate = true,
    this.dnsHijack = true,
    this.allowBypass = true,
    this.ipv6 = false,
    this.systemProxy = true,
    this.stackMode = 'system',
    this.accessMode = 'all',
    this.accessPackages = const [],
    this.overrides = const {},
    this.meta = const {},
    this.closeToTray = true,
    this.launchAtStartup = false,
    this.silentStart = false,
    this.animations = true,
    this.notifications = true,
    this.allowLan = false,
    this.dnsEnabled = true,
    this.unifiedDelay = true,
    this.language = 'zh-CN',
    this.accentColor = 'blue',
    this.homeSection = 'home',
    this.logLevel = 'info',
  });

  static const defaults = AppSettings();

  AppSettings copyWith({
    bool? autoRestart,
    String? darkMode,
    bool? hideLauncher,
    bool? hideRecents,
    bool? showTraffic,
    bool? autoRoute,
    bool? bypassPrivate,
    bool? dnsHijack,
    bool? allowBypass,
    bool? ipv6,
    bool? systemProxy,
    String? stackMode,
    String? accessMode,
    List<String>? accessPackages,
    Map<String, String>? overrides,
    Map<String, String>? meta,
    bool? closeToTray,
    bool? launchAtStartup,
    bool? silentStart,
    bool? animations,
    bool? notifications,
    bool? allowLan,
    bool? dnsEnabled,
    bool? unifiedDelay,
    String? language,
    String? accentColor,
    String? homeSection,
    String? logLevel,
  }) => AppSettings(
    autoRestart: autoRestart ?? this.autoRestart,
    darkMode: darkMode ?? this.darkMode,
    hideLauncher: hideLauncher ?? this.hideLauncher,
    hideRecents: hideRecents ?? this.hideRecents,
    showTraffic: showTraffic ?? this.showTraffic,
    autoRoute: autoRoute ?? this.autoRoute,
    bypassPrivate: bypassPrivate ?? this.bypassPrivate,
    dnsHijack: dnsHijack ?? this.dnsHijack,
    allowBypass: allowBypass ?? this.allowBypass,
    ipv6: ipv6 ?? this.ipv6,
    systemProxy: systemProxy ?? this.systemProxy,
    stackMode: stackMode ?? this.stackMode,
    accessMode: accessMode ?? this.accessMode,
    accessPackages: accessPackages ?? this.accessPackages,
    overrides: overrides ?? this.overrides,
    meta: meta ?? this.meta,
    closeToTray: closeToTray ?? this.closeToTray,
    launchAtStartup: launchAtStartup ?? this.launchAtStartup,
    silentStart: silentStart ?? this.silentStart,
    animations: animations ?? this.animations,
    notifications: notifications ?? this.notifications,
    allowLan: allowLan ?? this.allowLan,
    dnsEnabled: dnsEnabled ?? this.dnsEnabled,
    unifiedDelay: unifiedDelay ?? this.unifiedDelay,
    language: language ?? this.language,
    accentColor: accentColor ?? this.accentColor,
    homeSection: homeSection ?? this.homeSection,
    logLevel: logLevel ?? this.logLevel,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'autoRestart': autoRestart,
    'darkMode': darkMode,
    'hideLauncher': hideLauncher,
    'hideRecents': hideRecents,
    'showTraffic': showTraffic,
    'autoRoute': autoRoute,
    'bypassPrivate': bypassPrivate,
    'dnsHijack': dnsHijack,
    'allowBypass': allowBypass,
    'ipv6': ipv6,
    'systemProxy': systemProxy,
    'stackMode': stackMode,
    'accessMode': accessMode,
    'accessPackages': accessPackages,
    'overrides': overrides,
    'meta': meta,
    'closeToTray': closeToTray,
    'launchAtStartup': launchAtStartup,
    'silentStart': silentStart,
    'animations': animations,
    'notifications': notifications,
    'allowLan': allowLan,
    'dnsEnabled': dnsEnabled,
    'unifiedDelay': unifiedDelay,
    'language': language,
    'accentColor': accentColor,
    'homeSection': homeSection,
    'logLevel': logLevel,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    autoRestart: json['autoRestart'] == true,
    darkMode: json['darkMode'] as String? ?? 'system',
    hideLauncher: json['hideLauncher'] == true,
    hideRecents: json['hideRecents'] == true,
    showTraffic: json['showTraffic'] != false,
    autoRoute: json['autoRoute'] != false,
    bypassPrivate: json['bypassPrivate'] != false,
    dnsHijack: json['dnsHijack'] != false,
    allowBypass: json['allowBypass'] != false,
    ipv6: json['ipv6'] == true,
    systemProxy: json['systemProxy'] != false,
    stackMode: json['stackMode'] as String? ?? 'system',
    accessMode: json['accessMode'] as String? ?? 'all',
    accessPackages: ((json['accessPackages'] as List?) ?? const [])
        .map((value) => value.toString())
        .toList(),
    overrides: _stringMap(json['overrides']),
    meta: _stringMap(json['meta']),
    closeToTray: json['closeToTray'] != false,
    launchAtStartup: json['launchAtStartup'] == true,
    silentStart: json['silentStart'] == true,
    animations: json['animations'] != false,
    notifications: json['notifications'] != false,
    allowLan: json['allowLan'] == true,
    dnsEnabled: json['dnsEnabled'] != false,
    unifiedDelay: json['unifiedDelay'] != false,
    language: json['language'] as String? ?? 'zh-CN',
    accentColor: json['accentColor'] as String? ?? 'blue',
    homeSection: json['homeSection'] as String? ?? 'home',
    logLevel: json['logLevel'] as String? ?? 'info',
  );

  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item.toString()));
  }
}
