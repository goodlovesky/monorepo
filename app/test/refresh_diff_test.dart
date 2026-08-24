import 'package:app/services/refresh_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RefreshDiff.compute', () {
    test('counts added and removed nodes', () {
      const oldYaml = '''
proxies:
  - {name: A, type: ss}
  - {name: B, type: ss}
proxy-groups:
  - {name: G, type: select, proxies: [A, B]}
rules:
  - DOMAIN,example.com,A
''';
      const newYaml = '''
proxies:
  - {name: A, type: ss}
  - {name: C, type: ss}
proxy-groups:
  - {name: G, type: select, proxies: [A, C]}
rules:
  - DOMAIN,example.com,A
''';
      final diff = RefreshDiff.compute(oldYaml, newYaml);
      expect(diff.oldNodeCount, 2);
      expect(diff.newNodeCount, 2);
      expect(diff.addedNodes, contains('C'));
      expect(diff.removedNodes, contains('B'));
      expect(diff.hasChanges, isTrue);
    });

    test('exposes complete review lines', () {
      final diff = RefreshDiff.compute(
        'proxies:\n  - name: old\nproxy-groups: []\nrules: []\n',
        'proxies:\n  - name: new\nproxy-groups:\n  - name: GLOBAL\nrules:\n  - MATCH,DIRECT\n',
      );
      expect(diff.detailLines, hasLength(8));
      expect(diff.detailLines.join('\n'), contains('新增节点：new'));
      expect(diff.detailLines.join('\n'), contains('删除节点：old'));
      expect(diff.detailLines.join('\n'), contains('代理组：0 → 1'));
    });

    test('summary includes added node names', () {
      const oldYaml = 'proxies:\n  - {name: A, type: ss}';
      const newYaml =
          'proxies:\n  - {name: A, type: ss}\n  - {name: B, type: ss}';
      final diff = RefreshDiff.compute(oldYaml, newYaml);
      expect(diff.summary, contains('+'));
      expect(diff.summary, contains('节点'));
    });

    test('identical yaml reports no changes', () {
      const yaml = '''
proxies:
  - {name: A, type: ss}
proxy-groups:
  - {name: G, type: select, proxies: [A]}
rules: []
''';
      final diff = RefreshDiff.compute(yaml, yaml);
      expect(diff.hasChanges, isFalse);
      expect(diff.summary, equals('配置无明显变化'));
    });

    test('handles empty / invalid yaml gracefully', () {
      const oldYaml = 'this is: not: valid: yaml: [';
      const newYaml = 'proxies:\n  - {name: A, type: ss}';
      final diff = RefreshDiff.compute(oldYaml, newYaml);
      expect(diff.oldNodeCount, 0);
      expect(diff.newNodeCount, 1);
    });

    test('extracts traffic/expire from comments', () {
      const oldYaml = '''
# upload=100, total=1000, expire=2026-12-31
proxies:
  - {name: A, type: ss}
''';
      const newYaml = '''
# upload=200, total=2000, expire=2027-06-30
proxies:
  - {name: A, type: ss}
''';
      final diff = RefreshDiff.compute(oldYaml, newYaml);
      expect(diff.oldTrafficUsed, 100);
      expect(diff.newTrafficUsed, 200);
      expect(diff.oldTrafficTotal, 1000);
      expect(diff.newTrafficTotal, 2000);
      expect(diff.oldExpiresAt, isNotNull);
      expect(diff.newExpiresAt, isNotNull);
    });
  });
}
