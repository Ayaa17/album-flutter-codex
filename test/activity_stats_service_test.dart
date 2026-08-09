import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_album_codex/data/models/activity.dart';
import 'package:flutter_album_codex/data/models/archery_models.dart';
import 'package:flutter_album_codex/data/models/target_face.dart';
import 'package:flutter_album_codex/data/repositories/archery_repository.dart';
import 'package:flutter_album_codex/data/services/activity_stats_service.dart';
import 'package:flutter_album_codex/data/services/storage_service.dart';

void main() {
  test('computes latest, monthly, and overall activity stats', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'activity_stats_service_test',
    );
    addTearDown(() => tempDir.delete(recursive: true));

    final repository = ArcheryRepository(
      storageService: StorageService(overrideRoot: tempDir),
    );
    final service = ActivityStatsService(repository: repository);
    final now = DateTime(2026, 8, 9);
    final latestActivity = _activity(
      id: 'latest',
      name: 'Morning practice',
      createdAt: DateTime(2026, 8, 8),
    );
    final oldActivity = _activity(
      id: 'older',
      name: 'July practice',
      createdAt: DateTime(2026, 7, 31),
    );

    await repository.saveRounds(latestActivity.id, [
      _round(id: 'round-1', scores: [10, 9, 8]),
      _round(id: 'round-2', scores: [7, 7]),
    ]);
    await repository.saveRounds(oldActivity.id, [
      _round(id: 'round-3', scores: [6, 5, 4]),
    ]);

    final stats = await service.compute([
      latestActivity,
      oldActivity,
    ], now: now);

    expect(stats.latest?.subtitle, 'Morning practice');
    expect(stats.latest?.rounds, 2);
    expect(stats.latest?.arrows, 5);
    expect(stats.latest?.bestRoundScore, 27);
    expect(stats.latest?.averageRoundScore, 20.5);

    expect(stats.monthly.activities, 1);
    expect(stats.monthly.rounds, 2);
    expect(stats.monthly.bestRoundScore, 27);

    expect(stats.overall.activities, 2);
    expect(stats.overall.rounds, 3);
    expect(stats.overall.arrows, 8);
    expect(stats.overall.bestRoundScore, 27);
    expect(stats.overall.averageRoundScore, 18.666666666666668);
  });
}

Activity _activity({
  required String id,
  required String name,
  required DateTime createdAt,
}) {
  return Activity(
    id: id,
    name: name,
    createdAt: createdAt,
    directoryPath: '',
    photoCount: 0,
    coverPhotoPath: null,
    targetFaceType: TargetFaceType.fullTenRing,
  );
}

ArcheryRound _round({required String id, required List<int> scores}) {
  final createdAt = DateTime(2026, 8, 9, 12);
  return ArcheryRound(
    id: id,
    createdAt: createdAt,
    arrows: [
      for (var index = 0; index < scores.length; index++)
        ArrowHit(
          id: '$id-arrow-$index',
          position: Offset(index.toDouble(), 0),
          score: scores[index],
          createdAt: createdAt,
          targetIndex: 0,
        ),
    ],
  );
}
