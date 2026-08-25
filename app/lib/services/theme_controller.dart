import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../core/log/app_log.dart';

/// 全局主题 + 语言控制器。
///
/// 主题/语言偏好存到 application support 的 `preferences.json`，
/// 让 MaterialApp 主题/语言随设置实时切换。
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  /// 三种主题模式：跟随系统 / 深色 / 浅色。
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// 当前界面语言，由 Flutter ARB/gen_l10n 资源解析。
  String _language = 'zh-CN';
  String get language => _language;
  bool get isChinese => _language == 'zh-CN';

  static const supportedLanguages = <String>{
    'zh-CN',
    'zh-TW',
    'en-US',
    'ja-JP',
    'ko-KR',
    'fr-FR',
  };

  static String normalizeLanguage(String? code) =>
      supportedLanguages.contains(code) ? code! : 'zh-CN';

  File? _prefsFile;

  /// 应用启动时调用，读取本地偏好。
  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _prefsFile = File('${dir.path}/preferences.json');
      if (!await _prefsFile!.exists()) return;
      final root = jsonDecode(await _prefsFile!.readAsString());
      if (root is! Map) return;
      final mode = root['themeMode'] as String?;
      _themeMode = switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _language = normalizeLanguage(root['language'] as String?);
      notifyListeners();
    } catch (error) {
      debugPrint('ThemeController.load failed: $error');
    }
  }

  /// 修改主题模式（立即写盘 + 通知）。
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _persist();
  }

  /// 从 settings.darkMode 字符串转换为 ThemeMode 并应用。
  /// settings.darkMode 语义：'system' / 'dark' / 'light'。
  Future<void> applyDarkMode(String code) async {
    final mode = switch (code) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    await setThemeMode(mode);
  }

  /// 修改语言（立即写盘 + 通知）。
  Future<void> setLanguage(String code) async {
    final normalized = normalizeLanguage(code);
    if (normalized == _language) return;
    _language = normalized;
    AppLog.setLocale(normalized);
    notifyListeners();
    await _persist();
  }

  /// 旧调用兼容入口；新界面使用 AppLocalizations/RsText。
  String tr(String zh, [String? en]) {
    if (isChinese) return zh;
    return en ?? zh;
  }

  Future<void> _persist() async {
    final file = _prefsFile;
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert({'themeMode': _themeMode.name, 'language': _language}),
        flush: true,
      );
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    } catch (error) {
      debugPrint('ThemeController.persist failed: $error');
    }
  }
}
