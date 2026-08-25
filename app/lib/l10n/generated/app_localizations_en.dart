// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Clash RS';

  @override
  String get navHome => 'Home';

  @override
  String get navProxies => 'Proxies';

  @override
  String get navSubscriptions => 'Subscriptions';

  @override
  String get navConnections => 'Connections';

  @override
  String get navRules => 'Rules';

  @override
  String get navLogs => 'Logs';

  @override
  String get navTests => 'Tests';

  @override
  String get navSettings => 'Settings';

  @override
  String get proxyGroups => 'Proxy Groups';

  @override
  String get commonDone => 'Done';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSave => 'Save';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonBrowse => 'Browse';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonEnabled => 'Enabled';

  @override
  String get commonDisabled => 'Disabled';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonNoData => 'No data';

  @override
  String get languageSetting => 'Language';

  @override
  String get languageSimplifiedChinese => 'Simplified Chinese';

  @override
  String get languageTraditionalChinese => 'Traditional Chinese';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageKorean => 'Korean';

  @override
  String get languageFrench => 'French';

  @override
  String get settingsBasic => 'RS Basic Settings';

  @override
  String get settingsAdvanced => 'RS Advanced Settings';

  @override
  String get settingsSystem => 'System Settings';

  @override
  String get settingsClash => 'Clash Settings';

  @override
  String get settingsVersion => 'RS Version';

  @override
  String get proxyCheck => 'Check';

  @override
  String get proxyChecking => 'Checking…';

  @override
  String get proxyError => 'Proxy unavailable';

  @override
  String get proxyModeRule => 'Rule';

  @override
  String get proxyModeGlobal => 'Global';

  @override
  String get proxyModeDirect => 'Direct';

  @override
  String get networkSystemProxy => 'System Proxy';

  @override
  String get networkTunMode => 'TUN Mode';

  @override
  String errorWithDetails(String message, String details) {
    return '$message: $details';
  }
}
