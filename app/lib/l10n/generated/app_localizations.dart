import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'Clash RS'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navProxies.
  ///
  /// In zh, this message translates to:
  /// **'代理'**
  String get navProxies;

  /// No description provided for @navSubscriptions.
  ///
  /// In zh, this message translates to:
  /// **'订阅'**
  String get navSubscriptions;

  /// No description provided for @navConnections.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get navConnections;

  /// No description provided for @navRules.
  ///
  /// In zh, this message translates to:
  /// **'规则'**
  String get navRules;

  /// No description provided for @navLogs.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get navLogs;

  /// No description provided for @navTests.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get navTests;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @proxyGroups.
  ///
  /// In zh, this message translates to:
  /// **'代理组'**
  String get proxyGroups;

  /// No description provided for @commonDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get commonDone;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get commonConfirm;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonClose;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get commonRefresh;

  /// No description provided for @commonBrowse.
  ///
  /// In zh, this message translates to:
  /// **'浏览'**
  String get commonBrowse;

  /// No description provided for @commonCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get commonCopy;

  /// No description provided for @commonEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get commonEnabled;

  /// No description provided for @commonDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未启用'**
  String get commonDisabled;

  /// No description provided for @commonOn.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonOff;

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get commonLoading;

  /// No description provided for @commonNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get commonNoData;

  /// No description provided for @languageSetting.
  ///
  /// In zh, this message translates to:
  /// **'语言设置'**
  String get languageSetting;

  /// No description provided for @languageSimplifiedChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageSimplifiedChinese;

  /// No description provided for @languageTraditionalChinese.
  ///
  /// In zh, this message translates to:
  /// **'繁體中文'**
  String get languageTraditionalChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageJapanese.
  ///
  /// In zh, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// No description provided for @languageKorean.
  ///
  /// In zh, this message translates to:
  /// **'한국어'**
  String get languageKorean;

  /// No description provided for @languageFrench.
  ///
  /// In zh, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @settingsBasic.
  ///
  /// In zh, this message translates to:
  /// **'RS 基础设置'**
  String get settingsBasic;

  /// No description provided for @settingsAdvanced.
  ///
  /// In zh, this message translates to:
  /// **'RS 高级设置'**
  String get settingsAdvanced;

  /// No description provided for @settingsSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统设置'**
  String get settingsSystem;

  /// No description provided for @settingsClash.
  ///
  /// In zh, this message translates to:
  /// **'Clash 设置'**
  String get settingsClash;

  /// No description provided for @settingsVersion.
  ///
  /// In zh, this message translates to:
  /// **'RS 版本'**
  String get settingsVersion;

  /// No description provided for @proxyCheck.
  ///
  /// In zh, this message translates to:
  /// **'检测'**
  String get proxyCheck;

  /// No description provided for @proxyChecking.
  ///
  /// In zh, this message translates to:
  /// **'检测中…'**
  String get proxyChecking;

  /// No description provided for @proxyError.
  ///
  /// In zh, this message translates to:
  /// **'代理异常'**
  String get proxyError;

  /// No description provided for @proxyModeRule.
  ///
  /// In zh, this message translates to:
  /// **'规则'**
  String get proxyModeRule;

  /// No description provided for @proxyModeGlobal.
  ///
  /// In zh, this message translates to:
  /// **'全局'**
  String get proxyModeGlobal;

  /// No description provided for @proxyModeDirect.
  ///
  /// In zh, this message translates to:
  /// **'直连'**
  String get proxyModeDirect;

  /// No description provided for @networkSystemProxy.
  ///
  /// In zh, this message translates to:
  /// **'系统代理'**
  String get networkSystemProxy;

  /// No description provided for @networkTunMode.
  ///
  /// In zh, this message translates to:
  /// **'虚拟网卡模式'**
  String get networkTunMode;

  /// No description provided for @errorWithDetails.
  ///
  /// In zh, this message translates to:
  /// **'{message}：{details}'**
  String errorWithDetails(String message, String details);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
