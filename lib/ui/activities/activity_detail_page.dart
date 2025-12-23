import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/activity_detail/activity_detail_cubit.dart';
import '../../blocs/activity_detail/activity_detail_state.dart';
import '../../data/models/activity.dart';
import '../../data/models/archery_models.dart';
import '../../data/models/target_face.dart';
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

class _ActivityDetailView extends StatefulWidget {
  const _ActivityDetailView();

  @override
  State<_ActivityDetailView> createState() => _ActivityDetailViewState();
}

class _ActivityDetailViewState extends State<_ActivityDetailView> {
  Offset? _crosshairPosition;
  Offset? _pendingArrowPosition;
  String? _highlightedArrowId;

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
        final highlightId = selectedRound == null ||
                !(selectedRound.arrows
                    .any((arrow) => arrow.id == _highlightedArrowId))
            ? null
            : _highlightedArrowId;
        return Scaffold(
          appBar: AppBar(title: Text(state.activity.name)),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                onPressed: () =>
                    context.read<ActivityDetailCubit>().addRoundWithPhoto(),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Add Picture'),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                onPressed: () => context.read<ActivityDetailCubit>().addRound(),
                icon: const Icon(Icons.my_location_outlined),
                label: const Text('Add Round'),
              ),
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const headerSpacing = 6.0;
                              const minHeaderHeight = 96.0;
                              const maxHeaderHeight = 96.0;

                              final headerContent = selectedRound != null
                                  ? _RoundHeader(
                                      round: selectedRound,
                                      roundIndex:
                                          state.rounds.indexWhere(
                                            (round) =>
                                                round.id == selectedRound.id,
                                          ) +
                                          1,
                                      highlightedArrowId: highlightId,
                                      onArrowTap: _handleArrowTap,
                                      onArrowLongPress: (arrow) =>
                                          _handleArrowLongPress(
                                            context,
                                            selectedRound,
                                            arrow,
                                          ),
                                    )
                                  : const _NoRoundHeader();

                              final maxHeaderExtent = math.max(
                                0.0,
                                constraints.maxHeight - headerSpacing,
                              );
                              var headerHeight = math.min(
                                maxHeaderExtent,
                                maxHeaderHeight,
                              );
                              if (headerHeight < minHeaderHeight) {
                                headerHeight = math.min(
                                  maxHeaderExtent,
                                  minHeaderHeight,
                                );
                              }

                              return Column(
                                children: [
                                  SizedBox(
                                    height: headerHeight,
                                    child: SingleChildScrollView(
                                      physics: const ClampingScrollPhysics(),
                                      child: Align(
                                        alignment: Alignment.topLeft,
                                        child: headerContent,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: headerSpacing / 2),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, targetConstraints) {
                                        final available = math.min(
                                          targetConstraints.maxWidth,
                                          targetConstraints.maxHeight,
                                        );
                                        final diameter = available;
                                        final targetSize = Size.square(
                                          diameter,
                                        );
                                        final cubit = context
                                            .read<ActivityDetailCubit>();
                                        final arrows =
                                            selectedRound?.arrows ??
                                            const <ArrowHit>[];

                                        if (diameter <= 0) {
                                          return const SizedBox();
                                        }

                                        return Center(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTapDown: (details) =>
                                                _updateCrosshair(
                                                  details.localPosition,
                                                  targetSize,
                                                ),
                                            onTapUp: (details) {
                                              _updateCrosshair(
                                                details.localPosition,
                                                targetSize,
                                              );
                                              _commitArrow(cubit, targetSize);
                                            },
                                            onTapCancel: _hideCrosshair,
                                            onPanStart: (details) =>
                                                _updateCrosshair(
                                                  details.localPosition,
                                                  targetSize,
                                                ),
                                            onPanUpdate: (details) =>
                                                _updateCrosshair(
                                                  details.localPosition,
                                                  targetSize,
                                                ),
                                            onPanEnd: (_) =>
                                                _commitArrow(cubit, targetSize),
                                            onPanCancel: _hideCrosshair,
                                            child: SizedBox(
                                              width: targetSize.width,
                                              height: targetSize.height,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  CustomPaint(
                                                    painter:
                                                        ArcheryTargetPainter(
                                                          arrows: arrows,
                                                          drawRadius:
                                                              targetSize.width /
                                                              2,
                                                          baseRadius:
                                                              ArcheryRepository
                                                                  .targetRadius,
                                                          highlightedArrowId:
                                                              highlightId,
                                                          targetFaceType: state
                                                              .activity
                                                              .targetFaceType,
                                                        ),
                                                  ),
                                                  if (_crosshairPosition !=
                                                      null)
                                                    CustomPaint(
                                                      painter: _CrosshairPainter(
                                                        position:
                                                            _crosshairPosition!,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      const Expanded(flex: 4, child: _RoundList()),
                    ],
                  ),
                ),
                if (state.status == ActivityDetailStatus.loading &&
                    state.rounds.isNotEmpty)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Color(0x14000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateCrosshair(Offset rawPosition, Size targetSize) {
    final position = _clampToTarget(rawPosition, targetSize);
    setState(() {
      _crosshairPosition = position;
      _pendingArrowPosition = position;
    });
  }

  void _commitArrow(ActivityDetailCubit cubit, Size targetSize) {
    final position = _pendingArrowPosition;
    if (position == null) {
      _hideCrosshair();
      return;
    }
    _hideCrosshair();
    cubit.addArrow(position, targetSize);
  }

  void _hideCrosshair() {
    if (_crosshairPosition == null && _pendingArrowPosition == null) {
      return;
    }
    setState(() {
      _crosshairPosition = null;
      _pendingArrowPosition = null;
    });
  }

  Offset _clampToTarget(Offset rawPosition, Size targetSize) {
    final dx = rawPosition.dx.clamp(0.0, targetSize.width) as double;
    final dy = rawPosition.dy.clamp(0.0, targetSize.height) as double;
    return Offset(dx, dy);
  }

  void _handleArrowTap(ArrowHit arrow) {
    setState(() {
      _highlightedArrowId = arrow.id;
    });
  }

  Future<void> _handleArrowLongPress(
    BuildContext context,
    ArcheryRound round,
    ArrowHit arrow,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete arrow?'),
              content: Text(
                'Remove the arrow scored ${arrow.score} pts?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) return;
    await context
        .read<ActivityDetailCubit>()
        .removeArrow(round.id, arrow.id);
    if (!mounted) return;
    if (_highlightedArrowId == arrow.id) {
      setState(() {
        _highlightedArrowId = null;
      });
    }
  }
}

class _NoRoundHeader extends StatelessWidget {
  const _NoRoundHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No round selected',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the target after adding a round to log your arrows.',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }
}

class _RoundHeader extends StatelessWidget {
  const _RoundHeader({
    required this.round,
    required this.roundIndex,
    required this.highlightedArrowId,
    required this.onArrowTap,
    required this.onArrowLongPress,
  });

  final ArcheryRound round;
  final int roundIndex;
  final String? highlightedArrowId;
  final void Function(ArrowHit arrow) onArrowTap;
  final void Function(ArrowHit arrow) onArrowLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedArrows = [...round.arrows]
      ..sort((a, b) => b.score.compareTo(a.score));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Round $roundIndex · ${round.totalScore} pts',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        if (sortedArrows.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final count = sortedArrows.length;
              final availableWidth = constraints.maxWidth;
              final totalSpacing = spacing * (count - 1);
              final usable = availableWidth - totalSpacing;
              final maxPerItem = usable > 0 ? usable / count : availableWidth;
              final pillWidth = math.min(
                _ArrowScorePill.fixedWidth,
                maxPerItem,
              );

              return Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  for (var i = 0; i < count; i++) ...[
                    SizedBox(
                      width: pillWidth,
                      child: _ArrowScorePill(
                        score: sortedArrows[i].score,
                        isHighlighted:
                            highlightedArrowId == sortedArrows[i].id,
                        onTap: () => onArrowTap(sortedArrows[i]),
                        onLongPress: () => onArrowLongPress(sortedArrows[i]),
                      ),
                    ),
                    if (i != count - 1) const SizedBox(width: spacing),
                  ],
                ],
              );
            },
          )
        else
          Text(
            'Tap anywhere on the target to log an arrow (max 6).',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
      ],
    );
  }
}

class _ArrowScorePill extends StatelessWidget {
  const _ArrowScorePill({
    required this.score,
    this.isHighlighted = false,
    this.onTap,
    this.onLongPress,
  });

  final int score;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  static const double fixedWidth = 55.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final base = colorScheme.primary;
    final hslBase = HSLColor.fromColor(base);
    final lighter = hslBase
        .withLightness(math.min(hslBase.lightness + 0.18, 1.0))
        .toColor();
    final darker = hslBase
        .withLightness(math.max(hslBase.lightness - 0.10, 0.0))
        .toColor();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHighlighted ? [darker, lighter] : [lighter, darker],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlighted
              ? Colors.orangeAccent
              : colorScheme.onPrimary.withOpacity(0.18),
          width: isHighlighted ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: base.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Center(
              child: Text(
                '$score',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onPrimary,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundList extends StatelessWidget {
  const _RoundList();

  Future<void> _handlePhotoAction(
    BuildContext context,
    ActivityDetailCubit cubit,
    ArcheryRound round,
  ) async {
    final photoPath = round.photoPath;
    if (photoPath == null) {
      await cubit.attachPhoto(round.id);
      return;
    }

    final file = File(photoPath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo not found. Please capture a new one.'),
        ),
      );
      await cubit.attachPhoto(round.id);
      return;
    }

    final shouldReplace =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Round photo'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 360,
                  maxHeight: 480,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Replace photo'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldReplace) {
      await cubit.attachPhoto(round.id);
    }
  }

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
                        tooltip: round.photoPath == null
                            ? 'Attach photo'
                            : 'View photo',
                        onPressed: () =>
                            _handlePhotoAction(context, cubit, round),
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
    this.highlightedArrowId,
    required this.targetFaceType,
  });

  final List<ArrowHit> arrows;
  final double drawRadius;
  final double baseRadius;
  final String? highlightedArrowId;
  final TargetFaceType targetFaceType;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    final scale = drawRadius / baseRadius;

    final rings = _ringsFor(targetFaceType);
    final ringCount = rings.length;

    for (var i = ringCount; i >= 1; i--) {
      final ringRadius = drawRadius * (i / ringCount);
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
      final isHighlighted = arrow.id == highlightedArrowId;
      final arrowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isHighlighted ? Colors.orange : Colors.deepPurple;
      final absolute = center + arrow.position * scale;
      canvas.drawCircle(absolute, isHighlighted ? 8 : 6, arrowPaint);
      if (isHighlighted) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.orangeAccent.withOpacity(0.9);
        canvas.drawCircle(absolute, 14, ring);
      }
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
        oldDelegate.baseRadius != baseRadius ||
        oldDelegate.highlightedArrowId != highlightedArrowId ||
        oldDelegate.targetFaceType != targetFaceType;
  }

  List<Color> _ringsFor(TargetFaceType type) {
    switch (type) {
      case TargetFaceType.half80cmSixRing:
        return [
          Colors.yellow,
          Colors.yellow.shade700,
          Colors.red,
          Colors.red.shade900,
          Colors.blue,
        ];
      case TargetFaceType.fullTenRing:
        return [
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
    }
  }
}

class _CrosshairPainter extends CustomPainter {
  const _CrosshairPainter({required this.position});

  final Offset position;

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = Colors.orangeAccent.withOpacity(0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(position.dx, 0),
      Offset(position.dx, size.height),
      guidePaint,
    );
    canvas.drawLine(
      Offset(0, position.dy),
      Offset(size.width, position.dy),
      guidePaint,
    );

    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.orangeAccent;
    canvas.drawCircle(position, 12, circlePaint);

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.orangeAccent;
    canvas.drawCircle(position, 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) {
    return oldDelegate.position != position;
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
      targetFaceType: TargetFaceType.fullTenRing,
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
