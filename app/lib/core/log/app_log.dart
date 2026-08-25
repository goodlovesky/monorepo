/// 双语日志：按当前应用 locale 选择中英文。
///
/// - `localeCode == 'zh-CN'` → 返回 `zh` 段
/// - 其他 locale（en/ja/ko/fr/zh-TW）→ 返回 `en` 段
///
/// 设计原则：
/// 1. **写时双段**：所有日志点必须同时提供 zh + en，调用点不会随语言丢失语义。
///    —— 不能像 i18n 那样只翻译一份，log 文件得能直接看，不用反查。
/// 2. **运行时不读 arb**：避免日志系统依赖 MaterialApp Localizations 注入；
///    log 可能在 main() 之前 / 之后 / 测试环境里跑。
/// 3. **极简 API**：[AppLog.pick] 一行就能选；调用点不引入新概念。
class AppLog {
  AppLog._();

  /// 当前应用 locale。默认 zh-CN 以匹配 [ThemeController] 默认值。
  static String _localeCode = 'zh-CN';

  /// 当前 locale code。供调试 / 诊断用。
  static String get localeCode => _localeCode;

  /// 是否 Simplified Chinese。
  static bool get isChinese => _localeCode == 'zh-CN';

  /// 由 [ThemeController] / main 启动时调用，同步当前语言。
  static void setLocale(String code) {
    _localeCode = code;
  }

  /// 根据当前 locale 二选一。
  ///
  /// 典型用法：
  /// ```dart
  /// AppLog.pick('开始列出网络服务', 'start listing network services')
  /// ```
  static String pick(String zh, String en) => isChinese ? zh : en;
}
