import 'dart:io';

import 'package:flutter/foundation.dart' show Listenable;

import '../macos/mac_network_service.dart';
import '../linux/linux_network_service.dart';
import '../windows/windows_network_service.dart';

enum DesktopNetworkMode { off, systemProxy, tun }

/// 桌面端网络服务接口,implements [Listenable] 让 UI 能监听 mode/lastError 变化。
abstract interface class DesktopNetworkService implements Listenable {
  DesktopNetworkMode get mode;
  String? get lastError;

  Future<void> recover();
  Future<void> enableSystemProxy({int httpPort = 17890, int socksPort = 17891});
  Future<void> enableTun({
    required String baseConfigPath,
    required String supportPath,
    bool ipv6 = false,
    String stackMode = 'system',
    bool dnsHijack = true,
    bool autoRoute = true,
    int controllerPort = 9090,
    String merge = '',
    String script = '',
  });
  Future<void> disableTun();
  Future<void> restore();
  Future<bool> isHealthy({int controllerPort = 9090});
}

DesktopNetworkService createDesktopNetworkService() {
  if (Platform.isWindows) return WindowsNetworkService();
  if (Platform.isLinux) return LinuxNetworkService();
  return MacNetworkService();
}
