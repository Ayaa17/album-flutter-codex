import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  StorageService({Directory? overrideRoot}) : _overrideRoot = overrideRoot;

  Directory? _overrideRoot;

  Future<Directory> ensureRootDirectory() async {
    if (_overrideRoot != null) {
      final root = _overrideRoot!;
      if (!await root.exists()) {
        await root.create(recursive: true);
      }
      return root;
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(appDocDir.path, 'event_albums'));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<void> overrideRootPath(String path) async {
    _overrideRoot = Directory(path);
    if (!await _overrideRoot!.exists()) {
      await _overrideRoot!.create(recursive: true);
    }
  }

  Future<Directory> ensureActivityDirectory(String activityId) async {
    final root = await ensureRootDirectory();
    final activityDir = Directory(p.join(root.path, activityId));
    if (!await activityDir.exists()) {
      await activityDir.create(recursive: true);
    }
    return activityDir;
  }

  Future<File> metadataFile(String activityId) async {
    final dir = await ensureActivityDirectory(activityId);
    return File(p.join(dir.path, 'metadata.json'));
  }
}
