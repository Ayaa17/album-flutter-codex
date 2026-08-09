import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_album_codex/data/models/archery_models.dart';
import 'package:flutter_album_codex/data/models/target_face.dart';
import 'package:flutter_album_codex/data/repositories/archery_repository.dart';
import 'package:flutter_album_codex/data/services/storage_service.dart';

void main() {
  test('scores a line cutter as the higher ring', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'archery_repository_test',
    );
    addTearDown(() => tempDir.delete(recursive: true));

    final repository = ArcheryRepository(
      storageService: StorageService(overrideRoot: tempDir),
    );
    final round = ArcheryRound(id: 'round-1', createdAt: DateTime(2026, 8, 9));
    const targetSize = Size.square(300);
    const center = Offset(150, 150);
    const tenRingBoundary = 15.0;
    const halfPixelPastTolerance =
        tenRingBoundary +
        ArcheryRepository.arrowRenderRadius +
        (ArcheryRepository.lineCutterTolerance / 2);

    final updated = await repository.addArrow(
      activityId: 'activity-1',
      rounds: [round],
      roundId: round.id,
      localPosition: center + const Offset(halfPixelPastTolerance, 0),
      targetSize: targetSize,
      targetFaceType: TargetFaceType.fullTenRing,
    );

    expect(updated.single.arrows.single.score, 10);
  });

  test('does not promote a clear miss past the scoring line', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'archery_repository_test',
    );
    addTearDown(() => tempDir.delete(recursive: true));

    final repository = ArcheryRepository(
      storageService: StorageService(overrideRoot: tempDir),
    );
    final round = ArcheryRound(id: 'round-1', createdAt: DateTime(2026, 8, 9));
    const targetSize = Size.square(300);
    const center = Offset(150, 150);
    const tenRingBoundary = 15.0;
    const pastTolerance =
        tenRingBoundary +
        ArcheryRepository.arrowRenderRadius +
        ArcheryRepository.lineCutterTolerance +
        0.5;

    final updated = await repository.addArrow(
      activityId: 'activity-1',
      rounds: [round],
      roundId: round.id,
      localPosition: center + const Offset(pastTolerance, 0),
      targetSize: targetSize,
      targetFaceType: TargetFaceType.fullTenRing,
    );

    expect(updated.single.arrows.single.score, 9);
  });
}
