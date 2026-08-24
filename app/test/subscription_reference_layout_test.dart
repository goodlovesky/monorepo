import 'package:app/features/desktop/desktop_app.dart';
import 'package:app/features/desktop/pages/subscription_page.dart';
import 'package:app/models/proxy_profile.dart';
import 'package:app/services/proxy_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('subscription page follows the compact 1:1 reference geometry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(760, 692));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final controller = ProxyAppController()
      ..profiles = [
        ProxyProfile(
          id: 'explorer',
          name: '探索者',
          sourceType: 'url',
          source: 'https://198.51.100.20/subscription',
          localYamlPath: '/tmp/explorer.yaml',
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(days: 1)),
          usedTrafficBytes: 1073741824,
          totalTrafficBytes: 60 * 1073741824,
          expiresAt: DateTime(2026, 12, 13),
        ),
        ProxyProfile(
          id: 'tagmeta',
          name: 'TAGMeta',
          sourceType: 'url',
          source: 'https://applications.temporary-subscription.example/data',
          localYamlPath: '/tmp/tagmeta.yaml',
          createdAt: now.subtract(const Duration(minutes: 23)),
          updatedAt: now.subtract(const Duration(minutes: 23)),
          usedTrafficBytes: 0,
          totalTrafficBytes: 500 * 1073741824,
          expiresAt: DateTime(2026, 11, 19),
          active: true,
        ),
      ];
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildDesktopTheme(),
        home: Scaffold(
          body: Column(
            children: [
              DesktopHeader(
                title: '订阅',
                trailing: SubscriptionHeaderActions(controller: controller),
                onHome: () {},
                onSettings: () {},
                onDiagnostics: () {},
              ),
              Expanded(child: SubscriptionPage(controller: controller)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final input = tester.getRect(
      find.byKey(const Key('subscription-url-field')),
    );
    expect(input.size, const Size(588, 34));
    expect(input.top, 73);

    final explorer = tester.getRect(
      find.byKey(const ValueKey('subscription-profile-explorer')),
    );
    final tagMeta = tester.getRect(
      find.byKey(const ValueKey('subscription-profile-tagmeta')),
    );
    expect(explorer.size, const Size(242, 102));
    expect(tagMeta.size, const Size(242, 102));
    expect(explorer.left, 12);
    expect(tagMeta.left - explorer.right, 6);
    expect(explorer.top, 113);

    final merge = tester.getRect(
      find.byKey(const Key('subscription-extension-merge')),
    );
    final script = tester.getRect(
      find.byKey(const Key('subscription-extension-script')),
    );
    expect(merge.height, 80);
    expect(script.height, 80);
    expect(merge.top, 240);
    expect(script.left - merge.right, 8);

    expect(find.text('198.51.100.20'), findsOneWidget);
    expect(
      find.text('applications.temporary-subscription.example'),
      findsOneWidget,
    );
    expect(find.text('1GB / 60GB'), findsOneWidget);
    expect(find.text('0.00B / 500GB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
