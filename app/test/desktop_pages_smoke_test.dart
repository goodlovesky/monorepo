import 'package:app/features/desktop/desktop_app.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/platform/desktop/desktop_network_service.dart';
import 'package:app/services/proxy_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNetwork extends ChangeNotifier implements DesktopNetworkService {
  @override
  Future<bool> isHealthy({int controllerPort = 9090}) async => true;
  @override
  String? lastError;
  @override
  DesktopNetworkMode mode = DesktopNetworkMode.off;
  @override
  Future<void> disableTun() async => mode = DesktopNetworkMode.off;
  @override
  Future<void> enableSystemProxy({
    int httpPort = 17890,
    int socksPort = 17891,
  }) async => mode = DesktopNetworkMode.systemProxy;
  @override
  Future<void> enableTun({
    required String baseConfigPath,
    required String supportPath,
    bool ipv6 = false,
    String stackMode = 'system',
    bool dnsHijack = true,
    bool autoRoute = true,
    int controllerPort = 9090,
    String merge = '',
    String script = '',
  }) async => mode = DesktopNetworkMode.tun;
  @override
  Future<void> recover() async {}
  @override
  Future<void> restore() async => mode = DesktopNetworkMode.off;
}

void main() {
  testWidgets('all eight desktop pages render at fixed 960x720', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ProxyAppController();
    final network = _FakeNetwork();
    for (final locale in const [
      Locale('zh', 'CN'),
      Locale('zh', 'TW'),
      Locale('en', 'US'),
      Locale('ja', 'JP'),
      Locale('ko', 'KR'),
      Locale('fr', 'FR'),
    ]) {
      for (final section in DesktopSection.values) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            theme: buildDesktopTheme(),
            home: Scaffold(
              body: DesktopPageHost(
                section: section,
                controller: controller,
                network: network,
                onNavigate: (_) {},
                onNetworkModeChange: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${locale.toLanguageTag()} ${section.name}',
        );
        if (locale == const Locale('zh', 'CN') &&
            section == DesktopSection.settings) {
          expect(find.text('RS 高级设置'), findsOneWidget);
          expect(find.text('基础设置'), findsNothing);
          expect(find.text('系统设置'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'reference settings');
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    network.dispose();
  });
}
