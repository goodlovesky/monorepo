import 'dart:io';

import 'package:app/services/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migrates legacy config and preserves one active profile', () async {
    final root = await Directory.systemTemp.createTemp('proxy-profile-test-');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/config.yaml').writeAsString('mode: rule');
    final repository = ProfileRepository(root);

    final profiles = await repository.initialize();

    expect(profiles, hasLength(1));
    expect(profiles.single.active, isTrue);
    expect(profiles.single.sourceType, 'local');
    expect(profiles.single.source, isNull);
    expect(
      await File(profiles.single.localYamlPath).readAsString(),
      'mode: rule',
    );
  });

  test(
    'rewrites default profile when yaml is missing proxies/proxy-groups',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'proxy-profile-legacy-',
      );
      addTearDown(() => root.delete(recursive: true));
      final profilesDir = Directory('${root.path}/profiles')..createSync();
      final defaultDir = Directory('${profilesDir.path}/default')..createSync();
      final legacyYaml = 'port: 17890\nmode: rule\nrules:\n  - MATCH,DIRECT\n';
      await File('${defaultDir.path}/config.yaml').writeAsString(legacyYaml);
      // 根目录也必须有 config.yaml，否则首次 initialize 走不到迁移分支
      await File('${root.path}/config.yaml').writeAsString(legacyYaml);
      // 先走一遍 initialize，让它复制根 config.yaml 到 default profile
      final repository = ProfileRepository(root);
      await repository.initialize();
      // 再把 default profile 的 yaml 还原成"老版本默认"（无 proxies）
      await File('${defaultDir.path}/config.yaml').writeAsString(legacyYaml);
      // 重新调用 initialize，期望自动迁移
      final profiles = await repository.initialize();

      expect(profiles, hasLength(1));
      expect(profiles.single.id, 'default');
      final rewritten = await File(profiles.single.localYamlPath)
          .readAsString();
      expect(rewritten, contains('proxy-groups:'));
      expect(rewritten, contains('PROXY'));
      expect(rewritten, isNot(equals(legacyYaml)));
    },
  );

  test(
    'does not rewrite default profile when yaml has only proxies header',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'proxy-profile-proxies-only-',
      );
      addTearDown(() => root.delete(recursive: true));
      final profilesDir = Directory('${root.path}/profiles')..createSync();
      final defaultDir = Directory('${profilesDir.path}/default')..createSync();
      final partial =
          'port: 17890\n'
          'proxies:\n'
          '  - name: a\n'
          '    type: ss\n'
          '    server: 1.1.1.1\n'
          '    port: 1\n'
          '    cipher: aes-128-gcm\n'
          '    password: x\n';
      await File('${defaultDir.path}/config.yaml').writeAsString(partial);
      await File('${root.path}/config.yaml').writeAsString(partial);
      final repository = ProfileRepository(root);
      await repository.initialize();
      await File('${defaultDir.path}/config.yaml').writeAsString(partial);
      await repository.initialize();

      final kept = await File('${defaultDir.path}/config.yaml').readAsString();
      expect(kept, equals(partial));
    },
  );

  test('keeps default profile when yaml already has proxies', () async {
    final root = await Directory.systemTemp.createTemp(
      'proxy-profile-already-',
    );
    addTearDown(() => root.delete(recursive: true));
    final profilesDir = Directory('${root.path}/profiles')..createSync();
    final defaultDir = Directory('${profilesDir.path}/default')..createSync();
    final healthyYaml =
        'port: 17890\n'
        'proxies:\n'
        '  - name: a\n'
        '    type: ss\n'
        '    server: 1.1.1.1\n'
        '    port: 1\n'
        '    cipher: aes-128-gcm\n'
        '    password: x\n'
        'proxy-groups:\n'
        '  - name: PROXY\n'
        '    type: select\n'
        '    proxies:\n'
        '      - a\n'
        'rules:\n'
        '  - MATCH,PROXY\n';
    await File('${defaultDir.path}/config.yaml').writeAsString(healthyYaml);
    await File('${root.path}/config.yaml').writeAsString(healthyYaml);
    final repository = ProfileRepository(root);

    final profiles = await repository.initialize();

    expect(profiles, hasLength(1));
    final kept = await File(profiles.single.localYamlPath).readAsString();
    expect(kept, healthyYaml);
  });

  test('saves, activates and deletes profiles atomically', () async {
    final root = await Directory.systemTemp.createTemp('proxy-profile-test-');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/config.yaml').writeAsString('mode: rule');
    final repository = ProfileRepository(root);
    await repository.initialize();

    final added = await repository.saveProfile(
      name: '远程配置',
      sourceType: 'url',
      source: 'https://example.test/sub',
      yaml: 'mode: rule\n',
    );
    var profiles = await repository.activate(added.id);
    expect(profiles.singleWhere((item) => item.id == added.id).active, isTrue);

    profiles = await repository.delete('default');
    expect(profiles, hasLength(1));
    expect(profiles.single.id, added.id);
  });
}
