import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/profile_proxy_catalog.dart';

void main() {
  test('builds offline groups and GLOBAL node list from subscription yaml', () {
    const yaml = '''
proxies:
  - {name: 香港 01 | 1x HK, type: ss, udp: true}
  - {name: 香港家宽 03 | 1x HK, type: vless}
proxy-groups:
  - name: PROXY
    type: select
    proxies: [香港 01 | 1x HK, 香港家宽 03 | 1x HK, DIRECT]
''';
    final groups = const ProfileProxyCatalog().fromYaml(yaml);

    expect(groups['PROXY']!.all, hasLength(3));
    expect(groups['PROXY']!.nodeTypes['香港 01 | 1x HK'], 'Shadowsocks');
    expect(groups['PROXY']!.nodeTypes['香港家宽 03 | 1x HK'], 'Vless');
    expect(groups['GLOBAL']!.all, [
      'DIRECT',
      'REJECT',
      '香港 01 | 1x HK',
      '香港家宽 03 | 1x HK',
    ]);
  });

  test('ignores malformed entries without hiding valid nodes', () {
    const yaml = '''
proxies:
  - broken
  - {name: Tokyo, type: trojan, udp: false}
proxy-groups:
  - {name: Select, type: select, proxies: [Tokyo]}
''';
    final groups = const ProfileProxyCatalog().fromYaml(yaml);
    expect(groups['Select']!.all, ['Tokyo']);
    expect(groups['Select']!.nodeUdp['Tokyo'], isFalse);
  });
}
