import 'package:app/core/vpn/vpn_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  const base = '''
mode: rule
dns:
  enable: true
rules:
  - MATCH,PROXY
''';

  test('merge extension deep-merges and prepends/appends rules', () {
    final result = applyConfigExtensions(
      base,
      merge: '''
dns:
  ipv6: true
prepend-rules:
  - DOMAIN,example.com,DIRECT
append-rules:
  - MATCH,DIRECT
''',
    );
    final root = loadYaml(result) as YamlMap;
    expect((root['dns'] as YamlMap)['enable'], isTrue);
    expect((root['dns'] as YamlMap)['ipv6'], isTrue);
    expect(root['rules'], [
      'DOMAIN,example.com,DIRECT',
      'MATCH,PROXY',
      'MATCH,DIRECT',
    ]);
  });

  test('script extension applies restricted deterministic commands', () {
    final result = applyConfigExtensions(
      base,
      script: '''
set dns.enable = false
set mode = global
prepend-rule DOMAIN-SUFFIX,example.org,DIRECT
delete dns.ipv6
''',
    );
    final root = loadYaml(result) as YamlMap;
    expect((root['dns'] as YamlMap)['enable'], isFalse);
    expect(root['mode'], 'global');
    expect(
      (root['rules'] as YamlList).first,
      'DOMAIN-SUFFIX,example.org,DIRECT',
    );
  });

  test('script extension rejects unknown commands with line number', () {
    expect(
      () => applyConfigExtensions(base, script: 'eval dangerous()'),
      throwsA(isA<FormatException>()),
    );
  });
}
