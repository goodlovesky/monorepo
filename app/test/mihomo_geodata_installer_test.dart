import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/mihomo_geodata_installer.dart';

void main() {
  late Directory root;
  late Directory resources;
  late Directory support;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mihomo-geodata-test-');
    resources = Directory('${root.path}/resources')..createSync();
    support = Directory('${root.path}/support');
    _writeFixtures(resources);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('installs all bundled geodata on first launch', () async {
    await _installer.ensureInstalled(
      bundledResourceDirectory: resources,
      supportDirectory: support,
    );

    expect(
      File('${support.path}/Country.mmdb').readAsStringSync(),
      contains('MaxMind.com'),
    );
    expect(File('${support.path}/geoip.dat').readAsStringSync(), 'geoip-data');
    expect(
      File('${support.path}/geosite.dat').readAsStringSync(),
      'geosite-data',
    );
  });

  test(
    'replaces a truncated MMDB instead of letting mihomo download it',
    () async {
      support.createSync();
      File('${support.path}/Country.mmdb').writeAsStringSync('broken');

      await _installer.ensureInstalled(
        bundledResourceDirectory: resources,
        supportDirectory: support,
      );

      expect(
        File('${support.path}/Country.mmdb').readAsStringSync(),
        contains('MaxMind.com'),
      );
      expect(
        File('${support.path}/Country.mmdb.installing').existsSync(),
        isFalse,
      );
    },
  );

  test('fails immediately when packaged geodata is missing', () async {
    File('${resources.path}/Country.mmdb').deleteSync();

    expect(
      () => _installer.ensureInstalled(
        bundledResourceDirectory: resources,
        supportDirectory: support,
      ),
      throwsA(isA<StateError>()),
    );
  });
}

const _installer = MihomoGeodataInstaller(
  minimumBytes: {'Country.mmdb': 8, 'geoip.dat': 4, 'geosite.dat': 4},
);

void _writeFixtures(Directory directory) {
  File('${directory.path}/Country.mmdb')
      .writeAsStringSync('fixture-prefix-MaxMind.com-fixture');
  File('${directory.path}/geoip.dat').writeAsStringSync('geoip-data');
  File('${directory.path}/geosite.dat').writeAsStringSync('geosite-data');
}
