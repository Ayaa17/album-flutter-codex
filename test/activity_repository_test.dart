import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_album_codex/data/models/target_face.dart';
import 'package:flutter_album_codex/data/repositories/activity_repository.dart';
import 'package:flutter_album_codex/data/services/storage_service.dart';

void main() {
  test('persists activity distance in meters', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'activity_repository_test',
    );
    addTearDown(() => tempDir.delete(recursive: true));

    final repository = ActivityRepository(
      storageService: StorageService(overrideRoot: tempDir),
    );

    final created = await repository.createActivity(
      'Distance test',
      targetFaceType: TargetFaceType.fullTenRing,
      distanceMeters: 18,
    );
    final loaded = await repository.loadActivities();

    expect(created.distanceMeters, 18);
    expect(loaded.single.distanceMeters, 18);
  });
}
