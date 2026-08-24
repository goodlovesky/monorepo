import 'dart:io';
import 'dart:typed_data';

/// Installs the geodata shipped with the desktop application before mihomo is
/// started. This keeps the first launch deterministic and avoids mihomo
/// blocking on a network download while its controller port is still closed.
class MihomoGeodataInstaller {
  const MihomoGeodataInstaller({
    this.minimumBytes = const {
      'Country.mmdb': 1024 * 1024,
      'geoip.dat': 1024 * 1024,
      'geosite.dat': 256 * 1024,
    },
  });

  final Map<String, int> minimumBytes;

  Future<void> ensureInstalled({
    required Directory bundledResourceDirectory,
    required Directory supportDirectory,
  }) async {
    await supportDirectory.create(recursive: true);
    for (final entry in minimumBytes.entries) {
      final bundled = File('${bundledResourceDirectory.path}/${entry.key}');
      if (!await _isValid(bundled, entry.key, entry.value)) {
        throw StateError('应用资源缺少有效的 ${entry.key}：${bundled.path}');
      }

      final installed = File('${supportDirectory.path}/${entry.key}');
      if (await _isValid(installed, entry.key, entry.value)) continue;

      final temporary = File('${installed.path}.installing');
      if (await temporary.exists()) await temporary.delete();
      await bundled.copy(temporary.path);
      if (!await _isValid(temporary, entry.key, entry.value)) {
        if (await temporary.exists()) await temporary.delete();
        throw StateError('${entry.key} 安装校验失败');
      }
      if (await installed.exists()) await installed.delete();
      await temporary.rename(installed.path);
    }
  }

  Future<bool> _isValid(File file, String name, int minimumLength) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length < minimumLength) return false;
    if (name != 'Country.mmdb') return true;

    // MaxMind databases keep this metadata marker near the end of the file.
    const marker = <int>[77, 97, 120, 77, 105, 110, 100, 46, 99, 111, 109];
    final tailLength = length < 131072 ? length : 131072;
    final handle = await file.open();
    try {
      await handle.setPosition(length - tailLength);
      final tail = await handle.read(tailLength);
      return _contains(tail, marker);
    } finally {
      await handle.close();
    }
  }

  bool _contains(Uint8List bytes, List<int> marker) {
    if (marker.isEmpty || bytes.length < marker.length) return false;
    for (var index = 0; index <= bytes.length - marker.length; index++) {
      var matches = true;
      for (var offset = 0; offset < marker.length; offset++) {
        if (bytes[index + offset] != marker[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }
}
