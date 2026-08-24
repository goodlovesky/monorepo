import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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

  /// 简单 i18n 字符串字典（key -> 中/英）。
  /// 起步支持 zh-CN / en-US，新增语言只需扩展 _strings。
  String _language = 'zh-CN';
  String get language => _language;
  bool get isChinese => _language.startsWith('zh');

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
      _language = (root['language'] as String?) ?? 'zh-CN';
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
    if (code == _language) return;
    _language = code;
    notifyListeners();
    await _persist();
  }

  /// i18n 翻译：传入中文 key，返回当前语言下的字符串。
  /// 找不到时回退到中文字面。
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
