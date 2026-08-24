import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';

class SettingsRepository {
  final Directory supportDirectory;
  SettingsRepository(this.supportDirectory);

  File get settingsFile => File('${supportDirectory.path}/settings.json');
  Directory get geoDirectory => Directory('${supportDirectory.path}/geo');

  Future<AppSettings> load() async {
    if (!await settingsFile.exists()) {
      await save(AppSettings.defaults);
      return AppSettings.defaults;
    }
    try {
      final root = jsonDecode(await settingsFile.readAsString());
      return AppSettings.fromJson(root as Map<String, dynamic>);
    } catch (_) {
      final broken = File('${settingsFile.path}.broken');
      await settingsFile.copy(broken.path);
      await save(AppSettings.defaults);
      return AppSettings.defaults;
    }
  }

  Future<void> save(AppSettings settings) async {
    await supportDirectory.create(recursive: true);
    final temporary = File('${settingsFile.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
      flush: true,
    );
    if (await settingsFile.exists()) await settingsFile.delete();
    await temporary.rename(settingsFile.path);
  }

  Future<String> importGeoFile(String kind, String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw const FileSystemException('所选文件不存在');
    if (await source.length() > 256 * 1024 * 1024) {
      throw const FileSystemException('Geo 文件超过 256 MiB');
    }
    await geoDirectory.create(recursive: true);
    final extension = source.path.contains('.')
        ? source.path.substring(source.path.lastIndexOf('.'))
        : '.dat';
    final target = File('${geoDirectory.path}/${kind.toLowerCase()}$extension');
    await source.copy(target.path);
    return target.path;
  }
}
