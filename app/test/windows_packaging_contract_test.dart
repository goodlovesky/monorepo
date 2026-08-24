import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readFromRepository(String path) => File('../$path').readAsStringSync();

void main() {
  test('Windows runtime dependencies are pinned and hash verified', () {
    final script = _readFromRepository('tools/download_mihomo_windows.ps1');
    expect(script, contains("[string]\$Version = 'v1.19.30'"));
    expect(
      script,
      contains(
        '289fde5e29d37a5b3326480590d8b3551c5bf7f8737290355c19bce74d57a563',
      ),
    );
    expect(script, contains("[string]\$WintunVersion = '0.14.1'"));
    expect(script, contains('Get-FileHash'));
    expect(script, contains('SHA256 mismatch'));
    expect(script, isNot(contains('releases/latest')));
  });

  test('Windows build produces versioned portable and installer artifacts', () {
    final script = _readFromRepository('tools/build_windows.ps1');
    expect(
      script,
      contains('ClashRS-\$AppVersion-windows-\$Architecture-portable.zip'),
    );
    expect(script, contains('ClashRS-Setup-\$AppVersion-\$Architecture.exe'));
    expect(script, contains('BUILD-MANIFEST.json'));
    expect(script, contains('SHA256.txt'));
    expect(script, contains("'data\\icudtl.dat'"));
    expect(script, contains("'data\\flutter_assets\\AssetManifest.bin'"));
  });

  test('Windows installer supports upgrade and graceful application exit', () {
    final installer = _readFromRepository('tools/windows-installer.iss');
    final runner = _readFromRepository('app/windows/runner/flutter_window.cpp');
    expect(
      installer,
      contains('AppId={{8D20EA4D-92E7-4D70-935F-F9F55FD52AE7}'),
    );
    expect(installer, contains('SetupMutex=ClashRS.Setup.Singleton'));
    expect(installer, contains('PrepareToInstall'));
    expect(installer, contains('InitializeUninstall'));
    expect(installer, contains('CLASH_RS_QUIT = 40002'));
    expect(runner, contains('BeginQuit();'));
    expect(runner, contains('"prepareForQuit"'));
    expect(runner, contains('SetTimer(GetHandle(), kQuitTimer, 8000'));
  });

  test('Windows CI performs package install and uninstall smoke test', () {
    final workflow = _readFromRepository(
      '.github/workflows/desktop-windows.yml',
    );
    expect(workflow, contains('Install and uninstall smoke test'));
    expect(workflow, contains('/VERYSILENT'));
    expect(workflow, contains('BUILD-MANIFEST.json'));
    expect(workflow, contains('if-no-files-found: error'));
  });

  test('Windows executable metadata uses Clash RS branding', () {
    final resource = _readFromRepository('app/windows/runner/Runner.rc');
    expect(resource, contains('VALUE "ProductName", "Clash RS"'));
    expect(resource, contains('VALUE "OriginalFilename", "clash_rs.exe"'));
    expect(resource, isNot(contains('VALUE "ProductName", "app"')));
  });
}
