import 'package:flutter_test/flutter_test.dart';
import 'package:app/platform/macos/mac_network_service.dart';

void main() {
  test('parses an enabled macOS proxy endpoint', () {
    final endpoint = parseMacProxyEndpoint('''
Enabled: Yes
Server: 127.0.0.1
Port: 7897
Authenticated Proxy Enabled: 0
''');

    expect(endpoint.enabled, isTrue);
    expect(endpoint.server, '127.0.0.1');
    expect(endpoint.port, 7897);
  });

  test('parses a disabled empty macOS proxy endpoint', () {
    final endpoint = parseMacProxyEndpoint('''
Enabled: No
Server:
Port: 0
Authenticated Proxy Enabled: 0
''');

    expect(endpoint.enabled, isFalse);
    expect(endpoint.server, isEmpty);
    expect(endpoint.port, 0);
  });

  test('round-trips a macOS process identity used for PID reuse defense', () {
    const identity = MacProcessIdentity(
      pid: 1234,
      executable: '/Applications/Clash RS.app/Contents/Resources/mihomo',
      startToken: 'Mon Aug 24 15:20:00 2026',
    );

    final restored = MacProcessIdentity.fromJson(identity.toJson());

    expect(restored.pid, 1234);
    expect(restored.executable, identity.executable);
    expect(restored.startToken, identity.startToken);
  });
}
