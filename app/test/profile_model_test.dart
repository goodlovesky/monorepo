import 'package:app/models/proxy_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ProxyProfile JSON round-trip preserves metadata', () {
    final now = DateTime.utc(2026, 8, 18, 12, 30);
    final original = ProxyProfile(
      id: 'profile-1',
      name: '测试配置',
      sourceType: 'url',
      source: 'https://example.test/sub',
      localYamlPath: '/tmp/profile/config.yaml',
      createdAt: now,
      updatedAt: now,
      lastCheckedAt: now,
      autoUpdateIntervalMinutes: 60,
      usedTrafficBytes: 1024,
      totalTrafficBytes: 4096,
      expiresAt: now.add(const Duration(days: 30)),
      active: true,
    );

    final decoded = ProxyProfile.decodeList(ProxyProfile.encodeList([original]))
        .single;
    expect(decoded.id, original.id);
    expect(decoded.name, original.name);
    expect(decoded.source, original.source);
    expect(decoded.autoUpdateIntervalMinutes, 60);
    expect(decoded.usedTrafficBytes, 1024);
    expect(decoded.active, isTrue);
  });
}
