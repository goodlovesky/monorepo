import 'dart:convert';
import 'dart:io';

import 'package:app/core/ffi/clash_controller.dart';
import 'package:app/models/app_settings.dart';
import 'package:app/features/desktop/desktop_app.dart';
import 'package:app/services/proxy_app_controller.dart';
import 'package:app/services/update_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop light theme consumes configured accent color', () {
    final theme = buildDesktopTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF2AD364),
    );
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, const Color(0xFF2AD364));
    expect(theme.scaffoldBackgroundColor.computeLuminance(), greaterThan(.8));
  });

  test('IP payload parser accepts primary and fallback HTTPS providers', () {
    final primary = parseIpInfoPayload({
      'ip': '203.0.113.1',
      'country_code': 'HK',
      'country': 'Hong Kong',
      'connection': {'asn': 4760, 'isp': 'HKT', 'org': 'HKT Business'},
      'timezone': {'id': 'Asia/Hong_Kong'},
      'latitude': 22.28,
      'longitude': 114.17,
    });
    expect(primary.ip, '203.0.113.1');
    expect(primary.asn, 'AS4760');
    expect(primary.timezone, 'Asia/Hong_Kong');

    final fallback = parseIpInfoPayload({
      'ip': '198.51.100.2',
      'country_code': 'US',
      'country_name': 'United States',
      'asn': 'AS64500',
      'org': 'Example Network',
      'timezone': 'America/Los_Angeles',
      'latitude': 34,
      'longitude': -118,
    });
    expect(fallback.countryName, 'United States');
    expect(fallback.asn, 'AS64500');
  });

  test('settings restart classifier ignores UI-only settings', () {
    const previous = AppSettings();
    expect(
      ProxyAppController.settingsRequireCoreRestart(
        previous,
        previous.copyWith(language: 'en-US', accentColor: 'green'),
      ),
      isFalse,
    );
    expect(
      ProxyAppController.settingsRequireCoreRestart(
        previous,
        previous.copyWith(overrides: const {'controller-port': '19090'}),
      ),
      isTrue,
    );
  });

  test('update cache accepts recent past and rejects future timestamps', () {
    final now = DateTime(2026, 8, 24, 12);
    UpdateInfo value(DateTime checkedAt) => UpdateInfo(
      version: '1.0.0',
      available: false,
      url: '',
      notes: '',
      checkedAt: checkedAt,
    );
    expect(
      UpdateChecker.isCacheFresh(
        value(now.subtract(const Duration(hours: 2))),
        now,
      ),
      isTrue,
    );
    expect(
      UpdateChecker.isCacheFresh(value(now.add(const Duration(hours: 2))), now),
      isFalse,
    );
    expect(
      UpdateChecker.isCacheFresh(
        value(now.subtract(const Duration(hours: 13))),
        now,
      ),
      isFalse,
    );
  });

  test('mihomo log client consumes NDJSON stream', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      expect(request.uri.path, '/logs');
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        '${jsonEncode({'type': 'info', 'payload': 'one'})}\n',
      );
      request.response.write(
        '${jsonEncode({'type': 'warning', 'payload': 'two'})}\n',
      );
      await request.response.close();
    });
    final client = ClashController(baseUrl: 'http://127.0.0.1:${server.port}');
    final frames = await client.watchLogs().take(2).toList();
    expect(frames.map((item) => item['payload']), ['one', 'two']);
  });
}
