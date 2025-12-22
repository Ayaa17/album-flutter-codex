import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/archery_models.dart';
import '../services/storage_service.dart';

class ArcheryRepository {
  ArcheryRepository({
    required StorageService storageService,
    ImagePicker? picker,
  }) : _storageService = storageService,
       _picker = picker ?? ImagePicker();

  final StorageService _storageService;
  final ImagePicker _picker;
  final Uuid _uuid = const Uuid();

  static const double targetRadius = 150.0;
  static const String _roundsFileName = 'rounds.json';

  Future<List<ArcheryRound>> loadRounds(String activityId) async {
    final file = await _roundsFile(activityId);
    if (!await file.exists()) {
      return <ArcheryRound>[];
    }
    try {
      final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
      return raw
          .map(
            (item) =>
                ArcheryRound.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (_) {
      return <ArcheryRound>[];
    }
  }

  Future<void> saveRounds(String activityId, List<ArcheryRound> rounds) async {
    final file = await _roundsFile(activityId);
    await file.writeAsString(
      jsonEncode(rounds.map((round) => round.toMap()).toList()),
      flush: true,
    );
  }

  Future<List<ArcheryRound>> addRound(
    String activityId,
    List<ArcheryRound> rounds,
  ) async {
    final newRound = ArcheryRound.create();
    final updated = <ArcheryRound>[...rounds, newRound];
    await saveRounds(activityId, updated);
    return updated;
  }

  Future<List<ArcheryRound>> addRoundWithPhoto(
    String activityId,
    List<ArcheryRound> rounds,
  ) async {
    final newRound = ArcheryRound.create();
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      imageQuality: 88,
    );
    if (picked == null) {
      return rounds;
    }

    final directory = await _storageService.ensureActivityDirectory(activityId);
    final extension = p.extension(picked.path).isEmpty
        ? '.jpg'
        : p.extension(picked.path);
    final fileName = 'round_${newRound.id}$extension';
    final targetPath = p.join(directory.path, fileName);

    if (Platform.isIOS || Platform.isAndroid) {
      await picked.saveTo(targetPath);
    } else {
      await File(picked.path).copy(targetPath);
    }

    final roundWithPhoto = newRound.copyWith(photoPath: targetPath);
    final updated = <ArcheryRound>[...rounds, roundWithPhoto];
    await saveRounds(activityId, updated);
    return updated;
  }

  Future<List<ArcheryRound>> attachPhoto(
    String activityId,
    List<ArcheryRound> rounds,
    String roundId,
  ) async {
    String? previousPhotoPath;
    for (final round in rounds) {
      if (round.id == roundId) {
        previousPhotoPath = round.photoPath;
        break;
      }
    }
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      imageQuality: 88,
    );
    if (picked == null) return rounds;

    final directory = await _storageService.ensureActivityDirectory(activityId);
    final extension = p.extension(picked.path).isEmpty
        ? '.jpg'
        : p.extension(picked.path);
    final uniqueSuffix = _uuid.v4();
    final fileName = 'round_${roundId}_$uniqueSuffix$extension';
    final targetPath = p.join(directory.path, fileName);

    if (Platform.isIOS || Platform.isAndroid) {
      await picked.saveTo(targetPath);
    } else {
      await File(picked.path).copy(targetPath);
    }

    final updated = rounds
        .map(
          (round) => round.id == roundId
              ? round.copyWith(photoPath: targetPath)
              : round,
        )
        .toList();
    await saveRounds(activityId, updated);

    if (previousPhotoPath != null && previousPhotoPath != targetPath) {
      final previousFile = File(previousPhotoPath);
      if (await previousFile.exists()) {
        try {
          await previousFile.delete();
        } catch (_) {}
      }
    }

    return updated;
  }

  Future<List<ArcheryRound>> deleteRound(
    String activityId,
    List<ArcheryRound> rounds,
    String roundId,
  ) async {
    final updated = rounds.where((round) => round.id != roundId).toList();
    await saveRounds(activityId, updated);
    return updated;
  }

  Future<List<ArcheryRound>> addArrow({
    required String activityId,
    required List<ArcheryRound> rounds,
    required String roundId,
    required Offset localPosition,
    required Size targetSize,
  }) async {
    final center = Offset(targetSize.width / 2, targetSize.height / 2);
    final relative = localPosition - center;
    final renderRadius = math.min(targetSize.width, targetSize.height) / 2;
    if (renderRadius <= 0) return rounds;

    final ratio = relative.distance / renderRadius;
    final score = _scoreFromRatio(ratio);
    final scale = targetRadius / renderRadius;
    final storedOffset = relative * scale;

    final newArrow = ArrowHit(
      id: _uuid.v4(),
      position: storedOffset,
      score: score,
      createdAt: DateTime.now(),
    );

    final updated = rounds.map((round) {
      if (round.id != roundId) return round;
      if (round.arrows.length >= 6) return round;
      return round.copyWith(arrows: [newArrow, ...round.arrows]);
    }).toList();

    await saveRounds(activityId, updated);
    return updated;
  }

  Future<List<ArcheryRound>> removeArrow({
    required String activityId,
    required List<ArcheryRound> rounds,
    required String roundId,
    required String arrowId,
  }) async {
    final updated = rounds.map((round) {
      if (round.id != roundId) return round;
      return round.copyWith(
        arrows: round.arrows.where((arrow) => arrow.id != arrowId).toList(),
      );
    }).toList();
    await saveRounds(activityId, updated);
    return updated;
  }

  Future<List<ArcheryRound>> updateArrowScore({
    required String activityId,
    required List<ArcheryRound> rounds,
    required String roundId,
    required String arrowId,
    required int newScore,
  }) async {
    final clampedScore = newScore.clamp(0, 10).toInt();
    final updated = rounds.map((round) {
      if (round.id != roundId) return round;
      final updatedArrows = round.arrows.map((arrow) {
        if (arrow.id != arrowId) return arrow;
        return arrow.createCopy(score: clampedScore);
      }).toList();
      return round.copyWith(arrows: updatedArrows);
    }).toList();
    await saveRounds(activityId, updated);
    return updated;
  }

  int _scoreFromRatio(double ratio) {
    if (ratio <= 0.10) return 10;
    if (ratio <= 0.20) return 9;
    if (ratio <= 0.30) return 8;
    if (ratio <= 0.40) return 7;
    if (ratio <= 0.50) return 6;
    if (ratio <= 0.60) return 5;
    if (ratio <= 0.70) return 4;
    if (ratio <= 0.80) return 3;
    if (ratio <= 0.90) return 2;
    if (ratio <= 1.00) return 1;
    return 0;
  }

  Future<File> _roundsFile(String activityId) async {
    final directory = await _storageService.ensureActivityDirectory(activityId);
    return File(p.join(directory.path, _roundsFileName));
  }
}
