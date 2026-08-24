import 'dart:io';

import 'package:app/services/runtime_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late RuntimeStateRepository repo;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('clash-rs-runtime-test');
    repo = RuntimeStateRepository(directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('returns null when no state file exists', () async {
    expect(await repo.load(), isNull);
  });

  test('saves and loads a state', () async {
    await repo.save(
      const RuntimeState(
        mode: RuntimeRuntimeMode.tun,
        helperPid: 12345,
        controllerPort: 16170,
      ),
    );
    final loaded = await repo.load();
    expect(loaded, isNotNull);
    expect(loaded!.mode, RuntimeRuntimeMode.tun);
    expect(loaded.helperPid, 12345);
    expect(loaded.controllerPort, 16170);
  });

  test('saves with copyWith and clears fields', () async {
    await repo.save(
      const RuntimeState(
        mode: RuntimeRuntimeMode.systemProxy,
        helperPid: 1,
        engineStartedAt: null,
        controllerPort: 16170,
      ),
    );
    final loaded = await repo.load();
    expect(loaded, isNotNull);
    final cleared = loaded!.copyWith(
      mode: RuntimeRuntimeMode.off,
      clearHelperPid: true,
      clearControllerPort: true,
    );
    expect(cleared.mode, RuntimeRuntimeMode.off);
    expect(cleared.helperPid, isNull);
    expect(cleared.controllerPort, isNull);
  });

  test('clear() removes the file', () async {
    await repo.save(const RuntimeState(mode: RuntimeRuntimeMode.tun));
    expect(await File('${directory.path}/runtime-state.json').exists(), isTrue);
    await repo.clear();
    expect(
      await File('${directory.path}/runtime-state.json').exists(),
      isFalse,
    );
  });

  test('returns null and removes corrupt file', () async {
    final file = File('${directory.path}/runtime-state.json');
    await file.writeAsString('this is not json{{{');
    final loaded = await repo.load();
    expect(loaded, isNull);
    expect(await file.exists(), isFalse);
  });
}
