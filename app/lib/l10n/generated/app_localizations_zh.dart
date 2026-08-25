// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Clash RS';

  @override
  String get navHome => '首页';

  @override
  String get navProxies => '代理';

  @override
  String get navSubscriptions => '订阅';

  @override
  String get navConnections => '连接';

  @override
  String get navRules => '规则';

  @override
  String get navLogs => '日志';

  @override
  String get navTests => '测试';

  @override
  String get navSettings => '设置';

  @override
  String get proxyGroups => '代理组';

  @override
  String get commonDone => '完成';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonSave => '保存';

  @override
  String get commonClose => '关闭';

  @override
  String get commonDelete => '删除';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonBrowse => '浏览';

  @override
  String get commonCopy => '复制';

  @override
  String get commonEnabled => '已启用';

  @override
  String get commonDisabled => '未启用';

  @override
  String get commonOn => '开启';

  @override
  String get commonOff => '关闭';

  @override
  String get commonLoading => '加载中…';

  @override
  String get commonNoData => '暂无数据';

  @override
  String get languageSetting => '语言设置';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageFrench => 'Français';

  @override
  String get settingsBasic => 'RS 基础设置';

  @override
  String get settingsAdvanced => 'RS 高级设置';

  @override
  String get settingsSystem => '系统设置';

  @override
  String get settingsClash => 'Clash 设置';

  @override
  String get settingsVersion => 'RS 版本';

  @override
  String get proxyCheck => '检测';

  @override
  String get proxyChecking => '检测中…';

  @override
  String get proxyError => '代理异常';

  @override
  String get proxyModeRule => '规则';

  @override
  String get proxyModeGlobal => '全局';

  @override
  String get proxyModeDirect => '直连';

  @override
  String get networkSystemProxy => '系统代理';

  @override
  String get networkTunMode => '虚拟网卡模式';

  @override
  String errorWithDetails(String message, String details) {
    return '$message：$details';
  }
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appName => 'Clash RS';

  @override
  String get navHome => '首頁';

  @override
  String get navProxies => '代理';

  @override
  String get navSubscriptions => '訂閱';

  @override
  String get navConnections => '連線';

  @override
  String get navRules => '規則';

  @override
  String get navLogs => '日誌';

  @override
  String get navTests => '測試';

  @override
  String get navSettings => '設定';

  @override
  String get proxyGroups => '代理群組';

  @override
  String get commonDone => '完成';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonSave => '儲存';

  @override
  String get commonClose => '關閉';

  @override
  String get commonDelete => '刪除';

  @override
  String get commonRefresh => '重新整理';

  @override
  String get commonBrowse => '瀏覽';

  @override
  String get commonCopy => '複製';

  @override
  String get commonEnabled => '已啟用';

  @override
  String get commonDisabled => '未啟用';

  @override
  String get commonOn => '開啟';

  @override
  String get commonOff => '關閉';

  @override
  String get commonLoading => '載入中…';

  @override
  String get commonNoData => '暫無資料';

  @override
  String get languageSetting => '語言設定';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageFrench => 'Français';

  @override
  String get settingsBasic => 'RS 基礎設定';

  @override
  String get settingsAdvanced => 'RS 進階設定';

  @override
  String get settingsSystem => '系統設定';

  @override
  String get settingsClash => 'Clash 設定';

  @override
  String get settingsVersion => 'RS 版本';

  @override
  String get proxyCheck => '檢測';

  @override
  String get proxyChecking => '檢測中…';

  @override
  String get proxyError => '代理異常';

  @override
  String get proxyModeRule => '規則';

  @override
  String get proxyModeGlobal => '全域';

  @override
  String get proxyModeDirect => '直連';

  @override
  String get networkSystemProxy => '系統代理';

  @override
  String get networkTunMode => '虛擬網卡模式';

  @override
  String errorWithDetails(String message, String details) {
    return '$message：$details';
  }
}
