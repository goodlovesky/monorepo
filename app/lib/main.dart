import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_theme.dart';
import 'core/log/app_log.dart';
import 'l10n/generated/app_localizations.dart';
import 'features/desktop/desktop_app.dart';
import 'features/home/home_page.dart';
import 'services/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.darkBackground,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.darkBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }
  // 全局主题/语言控制器 — 让 MaterialApp 主题随设置实时切换。
  final themeController = ThemeController.instance;
  await themeController.load();
  // 启动时同步一次 AppLog locale（之后 ThemeController.setLanguage 也会更新）。
  AppLog.setLocale(themeController.language);
  runApp(ProxyApp(themeController: themeController));
}

class ProxyApp extends StatelessWidget {
  final ThemeController themeController;
  const ProxyApp({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: themeController,
    builder: (context, _) {
      final isDesktop =
          Platform.isMacOS || Platform.isWindows || Platform.isLinux;
      final locale = switch (themeController.language) {
        'zh-TW' => const Locale('zh', 'TW'),
        'en-US' => const Locale('en', 'US'),
        'ja-JP' => const Locale('ja', 'JP'),
        'ko-KR' => const Locale('ko', 'KR'),
        'fr-FR' => const Locale('fr', 'FR'),
        _ => const Locale('zh', 'CN'),
      };
      return MaterialApp(
        title: 'Clash RS',
        debugShowCheckedModeBanner: false,
        themeMode: themeController.themeMode,
        theme: buildAppTheme(brightness: Brightness.light),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: isDesktop ? const DesktopApp() : const HomePage(),
      );
    },
  );
}
