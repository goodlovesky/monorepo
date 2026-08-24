import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop UI contains only RS branding', () async {
    final files = Directory('lib/features/desktop')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      final source = await file.readAsString();
      expect(
        source.toLowerCase().contains('verge'),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('settings are wired to desktop runtime and native lifecycle', () async {
    final desktop = await File('lib/features/desktop/desktop_app.dart')
        .readAsString();
    final settings = await File(
      'lib/features/desktop/pages/reference_settings_page.dart',
    ).readAsString();
    final controller = await File('lib/services/proxy_app_controller.dart')
        .readAsString();
    final macDelegate = await File('macos/Runner/AppDelegate.swift')
        .readAsString();
    final macWindow = await File('macos/Runner/MainFlutterWindow.swift')
        .readAsString();
    final windowsWindow = await File('windows/runner/flutter_window.cpp')
        .readAsString();

    expect(desktop, contains('onNetworkModeChange: onNetworkModeChange'));
    expect(desktop, contains("'subscriptions' => DesktopSection.subscription"));
    expect(settings, contains('widget.network.mode == DesktopNetworkMode.tun'));
    expect(settings, contains('DesktopNetworkMode.systemProxy'));
    expect(settings, contains('DesktopSection.connections'));
    expect(settings, contains('DesktopSection.subscription'));
    expect(controller, contains("'setTrayClickAction'"));
    expect(macDelegate, contains('setTrayClickAction'));
    expect(macWindow, contains('--silent'));
    expect(windowsWindow, contains('tray_click_action_'));
    expect(windowsWindow, contains('--silent'));
  });
}
