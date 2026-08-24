import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test(
    'macOS TUN uses per-operation authorization without a setuid helper',
    () {
      final network = source('lib/platform/macos/mac_network_service.dart');
      final home = source('lib/features/desktop/pages/home_page.dart');
      final build = source('../tools/build_macos.sh');

      expect(network, contains('with administrator privileges'));
      expect(network, contains('_matchesProcessIdentity'));
      expect(network, contains('_verifyTunCleanup'));
      expect(home, contains('_isTunRuntimeReady'));
      expect(home, isNot(contains('_isHelperSetuid')));
      expect(build, isNot(contains('cargo build -p clash-rs-helper')));
      expect(build, isNot(contains('chmod 4755')));
    },
  );

  test('macOS lifecycle and external TUN watchdog are wired end to end', () {
    final native = source('macos/Runner/AppDelegate.swift');
    final app = source('lib/features/desktop/desktop_app.dart');
    final controller = source('lib/services/proxy_app_controller.dart');

    expect(native, contains('NSWorkspace.didWakeNotification'));
    expect(native, contains('NWPathMonitor'));
    expect(native, contains('networkAvailable'));
    expect(app, contains("call.method == 'systemDidWake'"));
    expect(app, contains('_recoverExternalTun'));
    expect(controller, contains('_externalEngineFailureCount >= 3'));
    expect(controller, contains('onExternalEngineLost'));
  });

  test(
    'LaunchAgent registration and notarization run in release-safe order',
    () {
      final controller = source('lib/services/proxy_app_controller.dart');
      final build = source('../tools/build_macos.sh');

      expect(controller, contains("'bootstrap'"));
      expect(controller, contains("'bootout'"));
      final appSubmit = build.indexOf('notarytool submit "\$APP_ZIP"');
      final appStaple = build.indexOf('stapler staple "\$APP"');
      final dmgCreate = build.indexOf('hdiutil create');
      final dmgSubmit = build.indexOf(
        'notarytool submit "\$DIST/Clash-RS-macOS.dmg"',
      );
      expect(appSubmit, greaterThanOrEqualTo(0));
      expect(appSubmit, lessThan(appStaple));
      expect(appStaple, lessThan(dmgCreate));
      expect(dmgCreate, lessThan(dmgSubmit));
    },
  );
}
