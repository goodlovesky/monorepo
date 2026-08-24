import 'package:app/features/desktop/pages/connections_page.dart';
import 'package:app/services/proxy_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('connection page renders mihomo totals host and proxy chain', (
    tester,
  ) async {
    final controller = ProxyAppController()
      ..connectionDownloadTotal = 4096
      ..connectionUploadTotal = 2048
      ..connections = [
        {
          'id': 'connection-1',
          'metadata': {
            'host': 'example.com',
            'destinationPort': '443',
            'sourceIP': '127.0.0.1',
            'sourcePort': '50000',
            'destinationIP': '203.0.113.1',
          },
          'upload': 2048,
          'download': 4096,
          'chains': ['香港家宽 02｜1x HK', 'GLOBAL'],
          'rule': '',
          'rulePayload': '',
        },
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectionsPage(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.text('活跃 1'), findsOneWidget);
    expect(find.text('下载量：4.00 KB'), findsOneWidget);
    expect(find.text('上传量：2.00 KB'), findsOneWidget);
    expect(find.text('example.com:443'), findsOneWidget);
    expect(find.text('GLOBAL / 香港家宽 02｜1x HK'), findsOneWidget);
  });
}
