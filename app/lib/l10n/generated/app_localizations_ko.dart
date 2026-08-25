// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => 'Clash RS';

  @override
  String get navHome => '홈';

  @override
  String get navProxies => '프록시';

  @override
  String get navSubscriptions => '구독';

  @override
  String get navConnections => '연결';

  @override
  String get navRules => '규칙';

  @override
  String get navLogs => '로그';

  @override
  String get navTests => '테스트';

  @override
  String get navSettings => '설정';

  @override
  String get proxyGroups => '프록시 그룹';

  @override
  String get commonDone => '완료';

  @override
  String get commonCancel => '취소';

  @override
  String get commonConfirm => '확인';

  @override
  String get commonSave => '저장';

  @override
  String get commonClose => '닫기';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonRefresh => '새로고침';

  @override
  String get commonBrowse => '찾아보기';

  @override
  String get commonCopy => '복사';

  @override
  String get commonEnabled => '사용';

  @override
  String get commonDisabled => '사용 안 함';

  @override
  String get commonOn => '켜기';

  @override
  String get commonOff => '끄기';

  @override
  String get commonLoading => '불러오는 중…';

  @override
  String get commonNoData => '데이터 없음';

  @override
  String get languageSetting => '언어 설정';

  @override
  String get languageSimplifiedChinese => '간체 중국어';

  @override
  String get languageTraditionalChinese => '번체 중국어';

  @override
  String get languageEnglish => '영어';

  @override
  String get languageJapanese => '일본어';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageFrench => '프랑스어';

  @override
  String get settingsBasic => 'RS 기본 설정';

  @override
  String get settingsAdvanced => 'RS 고급 설정';

  @override
  String get settingsSystem => '시스템 설정';

  @override
  String get settingsClash => 'Clash 설정';

  @override
  String get settingsVersion => 'RS 버전';

  @override
  String get proxyCheck => '검사';

  @override
  String get proxyChecking => '검사 중…';

  @override
  String get proxyError => '프록시 오류';

  @override
  String get proxyModeRule => '규칙';

  @override
  String get proxyModeGlobal => '전체';

  @override
  String get proxyModeDirect => '직접 연결';

  @override
  String get networkSystemProxy => '시스템 프록시';

  @override
  String get networkTunMode => 'TUN 모드';

  @override
  String errorWithDetails(String message, String details) {
    return '$message: $details';
  }
}
