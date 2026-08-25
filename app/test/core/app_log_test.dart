import 'package:app/core/log/app_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // AppLog 是一个全局单例：测试间要重置 locale 以免互相污染。
  setUp(() {
    AppLog.setLocale('zh-CN');
  });

  group('AppLog.pick', () {
    test('locale == zh-CN → 返回 zh', () {
      AppLog.setLocale('zh-CN');
      expect(AppLog.isChinese, isTrue);
      expect(
        AppLog.pick('开始列出网络服务', 'start listing network services'),
        '开始列出网络服务',
      );
    });

    test('locale == en-US → 返回 en', () {
      AppLog.setLocale('en-US');
      expect(AppLog.isChinese, isFalse);
      expect(
        AppLog.pick('开始列出网络服务', 'start listing network services'),
        'start listing network services',
      );
    });

    test('locale == ja-JP → 返回 en (除 zh-CN 外都走英文)', () {
      AppLog.setLocale('ja-JP');
      expect(AppLog.isChinese, isFalse);
      expect(
        AppLog.pick('开始列出网络服务', 'start listing network services'),
        'start listing network services',
      );
    });

    test('locale == ko-KR / fr-FR / zh-TW → 返回 en', () {
      for (final code in const ['ko-KR', 'fr-FR', 'zh-TW']) {
        AppLog.setLocale(code);
        expect(AppLog.isChinese, isFalse, reason: code);
        expect(
          AppLog.pick('失败', 'failed'),
          'failed',
          reason: code,
        );
      }
    });
  });

  group('AppLog.isChinese', () {
    test('只有 zh-CN 算中文', () {
      AppLog.setLocale('zh-CN');
      expect(AppLog.isChinese, isTrue);
      AppLog.setLocale('zh-TW');
      expect(AppLog.isChinese, isFalse);
    });
  });
}
