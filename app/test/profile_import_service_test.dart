import 'package:app/services/profile_import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final importer = ProfileImportService();

  test('normalizes Clash YAML controller without losing proxies', () {
    final result = importer.convertText('''
external-controller: 0.0.0.0:9090
secret: old
proxies:
  - name: A
    type: direct
proxy-groups:
  - name: PROXY
    type: select
    proxies: [A]
rules:
  - MATCH,PROXY
''');
    expect(result, contains('external-controller: 127.0.0.1:9090'));
    expect(result, contains('secret: proxy_app_ffi_demo'));
    expect(result, isNot(contains('0.0.0.0:9090')));
    expect(loadYaml(result), isA<YamlMap>());
  });

  test('converts a VLESS Reality link into a complete Clash profile', () {
    final result = importer.convertText(
      'vless://00000000-0000-4000-8000-000000000001@203.0.113.10:22853'
      '?security=reality&type=tcp&sni=www.amazon.com&fp=chrome'
      '&pbk=test_public_key&sid=f770aad8ee7c9303#US-Test',
    );
    final yaml = loadYaml(result) as YamlMap;
    expect(result, contains('type: "vless"'));
    expect(result, contains('public-key: "test_public_key"'));
    expect((yaml['proxies'] as YamlList).length, 1);
    expect((yaml['rules'] as YamlList).single, 'MATCH,PROXY');
  });

  test('rejects YAML without proxy groups', () {
    expect(
      () => importer.convertText('proxies: []\nrules: []'),
      throwsA(isA<ProfileImportException>()),
    );
  });

  test('rejects YAML with empty proxies list', () {
    expect(
      () => importer.convertText('''
proxies: []
proxy-groups:
  - name: PROXY
    type: select
    proxies: [DIRECT]
rules:
  - MATCH,DIRECT
'''),
      throwsA(
        isA<ProfileImportException>().having(
          (e) => e.message,
          'message',
          contains('proxies 列表为空'),
        ),
      ),
    );
  });

  test('rejects YAML with missing proxy name', () {
    expect(
      () => importer.convertText('''
proxies:
  - type: ss
    server: 1.2.3.4
    port: 8388
    cipher: aes-128-gcm
    password: p
proxy-groups:
  - name: PROXY
    type: select
    proxies: [DIRECT]
rules:
  - MATCH,DIRECT
'''),
      throwsA(
        isA<ProfileImportException>().having(
          (e) => e.message,
          'message',
          contains('缺少 name'),
        ),
      ),
    );
  });

  test('rejects YAML with duplicate proxy names', () {
    expect(
      () => importer.convertText('''
proxies:
  - name: same
    type: ss
    server: 1.2.3.4
    port: 8388
    cipher: aes-128-gcm
    password: p
  - name: same
    type: ss
    server: 1.2.3.4
    port: 8388
    cipher: aes-128-gcm
    password: p
proxy-groups:
  - name: PROXY
    type: select
    proxies: [DIRECT]
rules:
  - MATCH,DIRECT
'''),
      throwsA(
        isA<ProfileImportException>().having(
          (e) => e.message,
          'message',
          contains('重复的节点名'),
        ),
      ),
    );
  });

  test('rejects proxy group that references itself', () {
    expect(
      () => importer.convertText('''
proxies:
  - name: A
    type: ss
    server: 1.2.3.4
    port: 8388
    cipher: aes-128-gcm
    password: p
proxy-groups:
  - name: LOOP
    type: select
    proxies: [LOOP]
rules:
  - MATCH,LOOP
'''),
      throwsA(
        isA<ProfileImportException>().having(
          (e) => e.message,
          'message',
          contains('不能引用自身'),
        ),
      ),
    );
  });
}
