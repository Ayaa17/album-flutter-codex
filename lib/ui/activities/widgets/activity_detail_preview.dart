import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/activity.dart';
import '../../../data/models/archery_models.dart';
import '../../../data/models/target_face.dart';
import '../../../data/repositories/archery_repository.dart';
import '../../../data/services/storage_service.dart';
import '../activity_detail_page.dart';

class ActivityDetailPreview extends StatelessWidget {
  const ActivityDetailPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final tempDir = Directory.systemTemp.createTempSync('archery_preview_');
    final storageService = StorageService(overrideRoot: tempDir);
    final archeryRepository = ArcheryRepository(storageService: storageService);
    final mockActivity = Activity(
      id: 'mock',
      name: 'Mock Archery Session',
      createdAt: DateTime.now(),
      directoryPath: '.',
      photoCount: 0,
      coverPhotoPath: null,
      targetFaceType: TargetFaceType.fullTenRing,
      distanceMeters: 70,
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: storageService),
        RepositoryProvider.value(value: archeryRepository),
      ],
      child: FutureBuilder<void>(
        future: _seedMockData(
          storageService,
          archeryRepository,
          mockActivity.id,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ActivityDetailPage(activity: mockActivity);
        },
      ),
    );
  }
}

Future<void> _seedMockData(
  StorageService storageService,
  ArcheryRepository repository,
  String activityId,
) async {
  await storageService.ensureActivityDirectory(activityId);
  final existing = await repository.loadRounds(activityId);
  if (existing.isNotEmpty) return;

  final now = DateTime.now();
  final uuid = const Uuid();

  final roundA = ArcheryRound.create().copyWith(
    arrows: [
      ArrowHit(
        id: uuid.v4(),
        position: Offset.zero,
        score: 10,
        createdAt: now,
        targetIndex: 0,
      ),
      ArrowHit(
        id: uuid.v4(),
        position: const Offset(24, -12),
        score: 9,
        createdAt: now,
        targetIndex: 0,
      ),
      ArrowHit(
        id: uuid.v4(),
        position: const Offset(-48, 30),
        score: 7,
        createdAt: now,
        targetIndex: 0,
      ),
    ],
  );

  final roundB = ArcheryRound.create().copyWith(
    arrows: [
      ArrowHit(
        id: uuid.v4(),
        position: const Offset(65, -40),
        score: 5,
        createdAt: now,
        targetIndex: 0,
      ),
      ArrowHit(
        id: uuid.v4(),
        position: const Offset(-90, -20),
        score: 4,
        createdAt: now,
        targetIndex: 0,
      ),
      ArrowHit(
        id: uuid.v4(),
        position: const Offset(140, 30),
        score: 1,
        createdAt: now,
        targetIndex: 0,
      ),
    ],
  );

  await repository.saveRounds(activityId, [roundA, roundB]);
}
