// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'Clash RS';

  @override
  String get navHome => 'ホーム';

  @override
  String get navProxies => 'プロキシ';

  @override
  String get navSubscriptions => '購読';

  @override
  String get navConnections => '接続';

  @override
  String get navRules => 'ルール';

  @override
  String get navLogs => 'ログ';

  @override
  String get navTests => 'テスト';

  @override
  String get navSettings => '設定';

  @override
  String get proxyGroups => 'プロキシグループ';

  @override
  String get commonDone => '完了';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonSave => '保存';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonDelete => '削除';

  @override
  String get commonRefresh => '更新';

  @override
  String get commonBrowse => '参照';

  @override
  String get commonCopy => 'コピー';

  @override
  String get commonEnabled => '有効';

  @override
  String get commonDisabled => '無効';

  @override
  String get commonOn => 'オン';

  @override
  String get commonOff => 'オフ';

  @override
  String get commonLoading => '読み込み中…';

  @override
  String get commonNoData => 'データがありません';

  @override
  String get languageSetting => '言語設定';

  @override
  String get languageSimplifiedChinese => '簡体中国語';

  @override
  String get languageTraditionalChinese => '繁体中国語';

  @override
  String get languageEnglish => '英語';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageKorean => '韓国語';

  @override
  String get languageFrench => 'フランス語';

  @override
  String get settingsBasic => 'RS 基本設定';

  @override
  String get settingsAdvanced => 'RS 詳細設定';

  @override
  String get settingsSystem => 'システム設定';

  @override
  String get settingsClash => 'Clash 設定';

  @override
  String get settingsVersion => 'RS バージョン';

  @override
  String get proxyCheck => '確認';

  @override
  String get proxyChecking => '確認中…';

  @override
  String get proxyError => 'プロキシ異常';

  @override
  String get proxyModeRule => 'ルール';

  @override
  String get proxyModeGlobal => 'グローバル';

  @override
  String get proxyModeDirect => '直接接続';

  @override
  String get networkSystemProxy => 'システムプロキシ';

  @override
  String get networkTunMode => 'TUN モード';

  @override
  String errorWithDetails(String message, String details) {
    return '$message：$details';
  }
}
