import 'package:flutter/services.dart';

/// 桌面窗口位置控制（仅 macOS / Windows 实际生效，其他平台返回 null）。
class WindowPositionService {
  static const _channel = MethodChannel('com.proxyapp.app/desktop_window');
  static final WindowPositionService instance = WindowPositionService._();
  WindowPositionService._();

  /// 读取当前窗口左下角坐标。
  Future<({double x, double y})?> getPosition() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getPosition',
      );
      if (result == null) return null;
      final x = (result['x'] as num?)?.toDouble();
      final y = (result['y'] as num?)?.toDouble();
      if (x == null || y == null) return null;
      return (x: x, y: y);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 把窗口移动到指定位置（macOS 左下角坐标系）。
  Future<bool> setPosition(double x, double y) async {
    try {
      await _channel.invokeMethod<void>('setPosition', {'x': x, 'y': y});
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 把窗口居中到当前所在屏幕的可见区域中心（macOS 由 Swift 端计算）。
  Future<bool> recenter() async {
    try {
      await _channel.invokeMethod<void>('recenter');
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
