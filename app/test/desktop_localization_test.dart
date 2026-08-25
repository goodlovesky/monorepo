import 'dart:convert';
import 'dart:io';

import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/l10n/generated/app_localizations_en.dart';
import 'package:app/l10n/rs_text.dart';
import 'package:app/services/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const localeCases = <({Locale locale, String expected})>[
    (locale: Locale('zh', 'CN'), expected: '设置'),
    (locale: Locale('zh', 'TW'), expected: '設定'),
    (locale: Locale('en', 'US'), expected: 'Settings'),
    (locale: Locale('ja', 'JP'), expected: '設定'),
    (locale: Locale('ko', 'KR'), expected: '설정'),
    (locale: Locale('fr', 'FR'), expected: 'Paramètres'),
  ];

  testWidgets('all six desktop locales load and render translated UI', (
    tester,
  ) async {
    for (final entry in localeCases) {
      await tester.pumpWidget(
        MaterialApp(
          locale: entry.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: const Scaffold(body: RsText('设置')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(entry.expected),
        findsOneWidget,
        reason: '${entry.locale}',
      );
    }
  });

  test('all ARB locales expose the same message keys', () {
    final files = <String>[
      'lib/l10n/app_zh.arb',
      'lib/l10n/app_zh_TW.arb',
      'lib/l10n/app_en.arb',
      'lib/l10n/app_ja.arb',
      'lib/l10n/app_ko.arb',
      'lib/l10n/app_fr.arb',
    ];
    Set<String>? expected;
    for (final path in files) {
      final root = jsonDecode(File(path).readAsStringSync()) as Map;
      final keys = root.keys
          .map((key) => key.toString())
          .where((key) => !key.startsWith('@'))
          .toSet();
      expected ??= keys;
      expect(keys, expected, reason: path);
      expect(root.values.join('\n').toLowerCase(), isNot(contains('verge')));
    }
  });

  test('language codes normalize to the supported offline locale set', () {
    for (final code in const [
      'zh-CN',
      'zh-TW',
      'en-US',
      'ja-JP',
      'ko-KR',
      'fr-FR',
    ]) {
      expect(ThemeController.normalizeLanguage(code), code);
    }
    expect(ThemeController.normalizeLanguage('unknown'), 'zh-CN');
    expect(ThemeController.normalizeLanguage(null), 'zh-CN');
  });

  test(
    'desktop source contains no Verge branding or raw Chinese Text literal',
    () {
      final desktop = Directory('lib/features/desktop');
      final rawText = RegExp(
        r'''\bText\(\s*['"][^'"]*[\u3400-\u9fff][^'"]*['"]''',
        multiLine: true,
      );
      for (final entity in desktop.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        expect(
          source.toLowerCase(),
          isNot(contains('verge')),
          reason: entity.path,
        );
        expect(rawText.hasMatch(source), isFalse, reason: entity.path);
      }
    },
  );

  test('English catalog covers every static desktop UI label', () {
    final expression = RegExp(
      r'''(?:RsText\(\s*|(?:label|title|subtitle|blueLabel|trailingText)\s*:\s*)['"]([^'"]*[\u3400-\u9fff][^'"]*)['"]''',
      multiLine: true,
    );
    final translator = AppLocalizationsEn();
    final missing = <String>[];
    for (final entity in Directory(
      'lib/features/desktop',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in expression.allMatches(entity.readAsStringSync())) {
        final source = match.group(1)!;
        final translated = RsUiText.translate(translator, source);
        if (!RsUiText.isCatalogCovered(translator, source)) {
          missing.add('${entity.path}: $source -> $translated');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('the active settings page exposes every language choice', () {
    final source = File('lib/features/desktop/pages/reference_settings_page.dart')
        .readAsStringSync();
    for (final code in ThemeController.supportedLanguages) {
      expect(source, contains("'$code'"), reason: code);
    }
  });
}
