// 简单 widget smoke 测试。
//
// 验证 ProxyApp 构造时不抛错（不真正启动 native 服务）。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';
import 'package:app/services/theme_controller.dart';

void main() {
  test('app root can be constructed without starting native services', () {
    expect(ProxyApp(themeController: ThemeController.instance), isA<Widget>());
  });
}
