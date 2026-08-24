import 'package:app/features/desktop/desktop_app.dart';
import 'package:app/services/proxy_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reference shell uses 200px sidebar and 63px header', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ProxyAppController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDesktopTheme(),
        home: Scaffold(
          body: Row(
            children: [
              DesktopSidebar(
                selected: DesktopSection.home,
                controller: controller,
                onSelected: (_) {},
              ),
              Expanded(
                child: Column(
                  children: [
                    DesktopHeader(
                      title: '首页',
                      onHome: () {},
                      onSettings: () {},
                      onDiagnostics: () {},
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(DesktopSidebar)).width, 200);
    expect(tester.getSize(find.byType(DesktopHeader)).height, 63);
    expect(find.text('Clash RS'), findsOneWidget);
    expect(find.text('首页'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
