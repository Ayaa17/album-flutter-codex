import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_album_codex/data/models/archery_models.dart';
import 'package:flutter_album_codex/data/models/app_settings.dart';
import 'package:flutter_album_codex/data/models/target_face.dart';

void main() {
  group('ArrowHit', () {
    test('round-trips stored fields', () {
      final createdAt = DateTime(2026, 8, 9, 10, 30);
      final arrow = ArrowHit(
        id: 'arrow-1',
        position: const Offset(12.5, -4.25),
        score: 10,
        isX: true,
        createdAt: createdAt,
        targetIndex: 2,
      );

      final restored = ArrowHit.fromMap(arrow.toMap());

      expect(restored, arrow);
      expect(restored.position, const Offset(12.5, -4.25));
      expect(restored.isX, isTrue);
      expect(restored.targetIndex, 2);
    });
  });

  group('ArcheryRound', () {
    test('computes totals and preserves equality after serialization', () {
      final createdAt = DateTime(2026, 8, 9, 11);
      final round = ArcheryRound(
        id: 'round-1',
        createdAt: createdAt,
        arrows: [
          ArrowHit(
            id: 'arrow-1',
            position: Offset.zero,
            score: 10,
            isX: true,
            createdAt: createdAt,
            targetIndex: 0,
          ),
          ArrowHit(
            id: 'arrow-2',
            position: const Offset(20, 4),
            score: 8,
            createdAt: createdAt,
            targetIndex: 1,
          ),
        ],
      );

      final restored = ArcheryRound.fromMap(round.toMap());

      expect(restored, round);
      expect(restored.totalScore, 18);
      expect(restored.averageScore, 9);
    });
  });

  group('TargetFaceType', () {
    test('maps storage keys and falls back safely', () {
      expect(
        TargetFaceTypeX.fromStorage('vertical_triple_6ring'),
        TargetFaceType.verticalTripleSixRing,
      );
      expect(
        TargetFaceTypeX.fromStorage('unknown'),
        TargetFaceType.fullTenRing,
      );
    });

    test('lays out triangular triple target within bounds', () {
      const size = Size(360, 420);
      final spots = TargetFaceType.triangularTripleSixRing.layoutSpots(size);
      const epsilon = 0.000001;

      expect(spots, hasLength(3));
      for (final spot in spots) {
        expect(spot.center.dx - spot.radius, greaterThanOrEqualTo(-epsilon));
        expect(
          spot.center.dx + spot.radius,
          lessThanOrEqualTo(size.width + epsilon),
        );
        expect(spot.center.dy - spot.radius, greaterThanOrEqualTo(-epsilon));
        expect(
          spot.center.dy + spot.radius,
          lessThanOrEqualTo(size.height + epsilon),
        );
      }
    });
  });

  group('AppSettings', () {
    test('preserves and updates default distance', () {
      const settings = AppSettings(
        themeMode: ThemeMode.system,
        defaultActivityNameFormat: 'Event {date}',
        defaultDistanceMeters: 70,
        storagePath: '',
        version: '1.0.0',
      );

      final updated = settings.copyWith(defaultDistanceMeters: 18);

      expect(updated.defaultDistanceMeters, 18);
      expect(
        updated.defaultActivityNameFormat,
        settings.defaultActivityNameFormat,
      );
      expect(settings.defaultDistanceMeters, 70);
    });
  });
}
