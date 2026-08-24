import 'dart:io';

import 'package:app/models/app_settings.dart';
import 'package:app/services/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings JSON round-trip preserves nested values', () {
    final source = AppSettings.defaults.copyWith(
      ipv6: true,
      stackMode: 'mixed',
      overrides: {'mixed-port': '17892'},
      meta: {'sniffing': 'true'},
    );
    final restored = AppSettings.fromJson(source.toJson());
    expect(restored.ipv6, isTrue);
    expect(restored.stackMode, 'mixed');
    expect(restored.overrides['mixed-port'], '17892');
    expect(restored.meta['sniffing'], 'true');
  });

  test('settings repository persists atomically', () async {
    final root = await Directory.systemTemp.createTemp('settings-test-');
    addTearDown(() => root.delete(recursive: true));
    final repository = SettingsRepository(root);
    final defaults = await repository.load();
    expect(defaults.autoRoute, isTrue);
    await repository.save(defaults.copyWith(hideRecents: true));
    expect((await repository.load()).hideRecents, isTrue);
  });
}
