import 'dart:async';

import 'package:app/features/desktop/pages/test_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('proxy probe failures use one concise user-facing label', () {
    expect(
      proxyProbeFailureLabel(TimeoutException('after 0:00:06.000000')),
      '代理异常',
    );
    expect(proxyProbeFailureLabel(Exception('socket failed')), '代理异常');
  });
}
