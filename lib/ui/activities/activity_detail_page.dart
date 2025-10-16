import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/activity_detail/activity_detail_cubit.dart';
import '../../blocs/activity_detail/activity_detail_state.dart';
import '../../data/models/activity.dart';
import '../../data/models/archery_models.dart';
import '../../data/repositories/archery_repository.dart';
import '../../data/services/storage_service.dart';
import '../common/empty_state.dart';
import 'package:uuid/uuid.dart';

class ActivityDetailPage extends StatelessWidget {
  const ActivityDetailPage({super.key, required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ArcheryRepository>();
    return BlocProvider(
      create: (_) =>
          ActivityDetailCubit(activity: activity, repository: repository)
            ..loadInitial(),
      child: const _ActivityDetailView(),
    );
  }
}

class _ActivityDetailView extends StatelessWidget {
  const _ActivityDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActivityDetailCubit, ActivityDetailState>(
      listenWhen: (previous, current) => previous.message != current.message,
      listener: (context, state) {
        final message = state.message;
        if (message != null && message.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        final selectedRound = state.selectedRound;
        final isInitialLoading =
            state.status == ActivityDetailStatus.loading &&
            state.rounds.isEmpty;

        return Scaffold(
          appBar: AppBar(title: Text(state.activity.name)),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.read<ActivityDetailCubit>().addRound(),
            icon: const Icon(Icons.my_location_outlined),
            label: const Text('Add Round'),
          ),
          body: isInitialLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (selectedRound != null)
                                _RoundHeader(
                                  round: selectedRound,
                                  roundIndex:
                                      state.rounds.indexWhere(
                                        (round) => round.id == selectedRound.id,
                                      ) +
                                      1,
                                )
                              else
                                const EmptyState(
                                  icon: Icons.my_location_outlined,
                                  title: 'No rounds yet',
                                  message:
                                      'Add a round to start tracking your arrows.',
                                ),
                              const SizedBox(height: 12),
                              if (selectedRound != null)
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final available = math.min(
                                        constraints.maxWidth,
                                        constraints.maxHeight,
                                      );
                                      final diameter = math.min(
                                        ArcheryRepository.targetRadius * 2,
                                        available,
                                      );
                                      final targetSize = Size.square(diameter);
                                      final cubit = context
                                          .read<ActivityDetailCubit>();

                                      if (diameter <= 0) {
                                        return const SizedBox();
                                      }

                                      return Center(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapUp: (details) => cubit.addArrow(
                                            details.localPosition,
                                            targetSize,
                                          ),
                                          onLongPressStart: (details) =>
                                              _handleLongPress(
                                                context,
                                                details.localPosition,
                                                targetSize,
                                                selectedRound,
                                              ),
                                          child: SizedBox(
                                            width: targetSize.width,
                                            height: targetSize.height,
                                            child: CustomPaint(
                                              painter: ArcheryTargetPainter(
                                                arrows: selectedRound.arrows,
                                                drawRadius:
                                                    targetSize.width / 2,
                                                baseRadius: ArcheryRepository
                                                    .targetRadius,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(flex: 5, child: const _RoundList()),
                    ],
                  ),
                ),
        );
      },
    );
  }

  void _handleLongPress(
    BuildContext context,
    Offset localPosition,
    Size targetSize,
    ArcheryRound round,
  ) {
    final center = Offset(targetSize.width / 2, targetSize.height / 2);
    const threshold = 18.0;
    final renderRadius = targetSize.width / 2;
    if (renderRadius <= 0) return;
    final scale = renderRadius / ArcheryRepository.targetRadius;
    ArrowHit? target;

    for (final arrow in round.arrows) {
      final absolute = center + arrow.position * scale;
      if ((absolute - localPosition).distance <= threshold) {
        target = arrow;
        break;
      }
    }

    if (target == null) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove this arrow'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.read<ActivityDetailCubit>().removeArrow(
                    round.id,
                    target!.id,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundHeader extends StatelessWidget {
  const _RoundHeader({required this.round, required this.roundIndex});

  final ArcheryRound round;
  final int roundIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Round $roundIndex · ${round.totalScore} pts',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (round.arrows.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: round.arrows
                .map((arrow) => Chip(label: Text('${arrow.score}')))
                .toList(),
          )
        else
          Text(
            'Tap anywhere on the target to log an arrow (max 6).',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
      ],
    );
  }
}

class _RoundList extends StatelessWidget {
  const _RoundList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityDetailCubit, ActivityDetailState>(
      builder: (context, state) {
        if (state.rounds.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: Icons.flag_outlined,
              title: 'No rounds yet',
              message: 'Tap the Add Round button to start a new set.',
            ),
          );
        }

        final cubit = context.read<ActivityDetailCubit>();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.rounds.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final round = state.rounds[index];
            final isSelected = round.id == state.selectedRoundId;

            return AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isSelected ? 1.02 : 1.0,
              child: Card(
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.45)
                    : null,
                child: ListTile(
                  onTap: () => cubit.selectRound(round.id),
                  leading: round.photoPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(round.photoPath!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CircleAvatar(child: Text('${index + 1}')),
                  title: Text('Round ${index + 1}'),
                  subtitle: Text(
                    'Score: ${round.totalScore} · Arrows: ${round.arrows.length}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: 'Attach photo',
                        onPressed: () => cubit.attachPhoto(round.id),
                        icon: const Icon(Icons.camera_alt_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete round',
                        onPressed: () => cubit.deleteRound(round.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ArcheryTargetPainter extends CustomPainter {
  ArcheryTargetPainter({
    required this.arrows,
    required this.drawRadius,
    required this.baseRadius,
  });

  final List<ArrowHit> arrows;
  final double drawRadius;
  final double baseRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    final scale = drawRadius / baseRadius;

    final rings = [
      Colors.yellow,
      Colors.yellow.shade700,
      Colors.red,
      Colors.red.shade900,
      Colors.blue,
      Colors.blue.shade900,
      Colors.black,
      Colors.black87,
      Colors.white,
      Colors.white,
    ];

    for (var i = rings.length; i >= 1; i--) {
      final ringRadius = drawRadius * (i / rings.length);
      paint.color = rings[i - 1];
      canvas.drawCircle(center, ringRadius, paint);
    }

    paint
      ..color = Colors.black54
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, drawRadius, paint);
    canvas.drawLine(
      Offset(center.dx - drawRadius, center.dy),
      Offset(center.dx + drawRadius, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - drawRadius),
      Offset(center.dx, center.dy + drawRadius),
      paint,
    );

    for (final arrow in arrows) {
      final arrowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.deepPurple;
      final absolute = center + arrow.position * scale;
      canvas.drawCircle(absolute, 6, arrowPaint);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${arrow.score}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: 24);
      textPainter.paint(
        canvas,
        absolute.translate(-textPainter.width / 2, -textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ArcheryTargetPainter oldDelegate) {
    return oldDelegate.arrows != arrows ||
        oldDelegate.drawRadius != drawRadius ||
        oldDelegate.baseRadius != baseRadius;
  }
}

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
      ArrowHit(id: uuid.v4(), position: Offset.zero, score: 10, createdAt: now),
      ArrowHit(
        id: uuid.v4(),
        position: const Offset(24, -12),
        score: 9,
        createdAt: now,
      ),
      ArrowHit(
        id: uuid.v4(),
        position: const Offset(-48, 30),
        score: 7,
        createdAt: now,
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
      ),
      ArrowHit(
        id: uuid.v4(),
        position: const Offset(-90, -20),
        score: 4,
        createdAt: now,
      ),
      ArrowHit(
        id: uuid.v4(),
        position: const Offset(140, 30),
        score: 1,
        createdAt: now,
      ),
    ],
  );

  await repository.saveRounds(activityId, [roundA, roundB]);
}
