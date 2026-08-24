import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String repo(String path) => File('../$path').readAsStringSync();

void main() {
  test('root cmd exposes four platform package entrypoints', () {
    for (final path in const [
      'cmd/build-android.sh',
      'cmd/build-macos.sh',
      'cmd/build-windows.ps1',
      'cmd/build-linux.sh',
      'cmd/build-all.sh',
    ]) {
      expect(File('../$path').existsSync(), isTrue, reason: path);
    }
    expect(repo('cmd/build-all.sh'), contains('case "\$(uname -s)"'));
    expect(
      repo('cmd/build-all.sh'),
      isNot(contains('"\$ROOT/cmd/build-windows.ps1" "\$@"')),
    );
  });

  test('Linux runtime is version and hash pinned', () {
    final download = repo('tools/download_mihomo_linux.sh');
    expect(download, contains('VERSION="v1.19.30"'));
    expect(
      download,
      contains(
        'cf06ce2c7d1421bdbda14ee4a5b6046672dc35ebf8eecd8e77504ec3c0ed9a84',
      ),
    );
    expect(download, contains('SHA256 mismatch'));
    expect(download, isNot(contains('releases/latest')));
  });

  test('Linux package contract produces deb tar manifest and checksums', () {
    final script = repo('tools/build_linux.sh');
    expect(script, contains('flutter build linux --release'));
    expect(script, contains('ClashRS-\$version-linux-x64.tar.gz'));
    expect(script, contains('clash-rs_\${version}_amd64.deb'));
    expect(script, contains('BUILD-MANIFEST.json'));
    expect(script, contains('SHA256.txt'));
    expect(script, contains('cap_net_admin,cap_net_raw+ep'));
    final workflow = repo('.github/workflows/desktop-linux.yml');
    expect(workflow, contains('Desktop Linux x64'));
    expect(workflow, contains('Install Linux packaging dependencies'));
    expect(workflow, contains('sha256sum --check SHA256.txt'));
  });

  test('Flutter Linux runner and network integration exist', () {
    expect(File('../app/linux/CMakeLists.txt').existsSync(), isTrue);
    expect(
      repo('app/linux/CMakeLists.txt'),
      contains('BINARY_NAME "clash_rs"'),
    );
    expect(
      repo('app/lib/platform/desktop/desktop_network_service.dart'),
      contains('Platform.isLinux'),
    );
    expect(repo('app/lib/main.dart'), contains('Platform.isLinux'));
  });
}
