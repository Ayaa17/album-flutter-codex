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
  bool _isTargetExpanded = false;
  bool _showAllRoundsOnTarget = false;

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
        final highlightId =
            selectedRound == null ||
                !(selectedRound.arrows.any(
                  (arrow) => arrow.id == _highlightedArrowId,
                ))
            ? null
            : _highlightedArrowId;
        return Scaffold(
          appBar: AppBar(title: Text(state.activity.name)),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // FloatingActionButton.extended(
              //   onPressed: () =>
              //       context.read<ActivityDetailCubit>().addRoundWithPhoto(),
              //   icon: const Icon(Icons.camera_alt_outlined),
              //   label: const Text('Add Picture'),
              // ),
              // const SizedBox(height: 12),
              // FloatingActionButton.extended(
              //   onPressed: () => context.read<ActivityDetailCubit>().addRound(),
              //   icon: const Icon(Icons.my_location_outlined),
              //   label: const Text('Add Round'),
              // ),
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

                              final headerContent = _showAllRoundsOnTarget
                                  ? _AllRoundsHeader(
                                      totalRounds: state.rounds.length,
                                      totalArrows: state.rounds.fold<int>(
                                        0,
                                        (sum, round) =>
                                            sum + round.arrows.length,
                                      ),
                                    )
                                  : (selectedRound != null
                                      ? _RoundHeader(
                                          round: selectedRound,
                                          roundIndex:
                                              state.rounds.indexWhere(
                                                    (round) =>
                                                        round.id ==
                                                        selectedRound.id,
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
                                      : const _NoRoundHeader());

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

                              return Stack(
                                children: [
                                  Column(
                                    children: [
                                      SizedBox(
                                        height: headerHeight,
                                        child: SingleChildScrollView(
                                          physics:
                                              const ClampingScrollPhysics(),
                                          child: Align(
                                            alignment: Alignment.topLeft,
                                            child: headerContent,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: headerSpacing / 2),
                                      Expanded(
                                        child: LayoutBuilder(
                                          builder:
                                              (context, targetConstraints) {
                                                final available = math.min(
                                                  targetConstraints.maxWidth,
                                                  targetConstraints.maxHeight,
                                                );
                                                if (available <= 0) {
                                                  return const SizedBox();
                                                }
                                                final targetSize = Size.square(
                                                  available,
                                                );
                                                return Center(
                                                  child: _buildTargetCanvas(
                                                    targetSize,
                                                    state,
                                                    highlightId,
                                                    _showAllRoundsOnTarget,
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: headerHeight,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => setState(
                                              () => _isTargetExpanded = true,
                                            ),
                                            icon: const Icon(
                                              Icons.open_in_full,
                                            ),
                                            label: const Text('Expand target'),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => context
                                                .read<ActivityDetailCubit>()
                                                .addRound(),
                                            icon: const Icon(
                                              Icons.my_location_outlined,
                                            ),
                                            label: const Text('Add Round'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        flex: 4,
                        child: _RoundList(
                          showAllRoundsOnTarget: _showAllRoundsOnTarget,
                          onAllRoundsToggle: (value) {
                            setState(() {
                              _showAllRoundsOnTarget = value;
                              if (value) _highlightedArrowId = null;
                            });
                          },
                          onRoundSelected: () => setState(
                            () => _showAllRoundsOnTarget = false,
                          ),
                        ),
                      ),
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
                if (_isTargetExpanded)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: SafeArea(
                        child: Stack(
                          children: [
                            Center(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final size = math.min(
                                    constraints.maxWidth - 24,
                                    constraints.maxHeight - 24,
                                  );
                                  final targetSize = Size.square(
                                    math.max(size, 0),
                                  );
                                  return _buildTargetCanvas(
                                    targetSize,
                                    state,
                                    highlightId,
                                    _showAllRoundsOnTarget,
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: FloatingActionButton.small(
                                heroTag: 'close_target',
                                onPressed: () =>
                                    setState(() => _isTargetExpanded = false),
                                child: const Icon(Icons.close_fullscreen),
                              ),
                            ),

                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: FloatingActionButton.extended(
                                onPressed: () => context
                                    .read<ActivityDetailCubit>()
                                    .addRound(),
                                icon: const Icon(Icons.my_location_outlined),
                                label: const Text('Add Round'),
                              ),
                            ),
                          ],
                        ),
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
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete arrow?'),
              content: Text('Remove the arrow scored ${arrow.score} pts?'),
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
    await context.read<ActivityDetailCubit>().removeArrow(round.id, arrow.id);
    if (!mounted) return;
    if (_highlightedArrowId == arrow.id) {
      setState(() {
        _highlightedArrowId = null;
      });
    }
  }

  Widget _buildTargetCanvas(
    Size targetSize,
    ActivityDetailState state,
    String? highlightId,
    bool showAllRounds,
  ) {
    final cubit = context.read<ActivityDetailCubit>();
    final selectedRoundId = state.selectedRoundId;
    final arrows = showAllRounds
        ? state.rounds
            .expand(
              (round) => round.arrows.map(
                (arrow) => _TargetArrow(
                  arrow: arrow,
                  isSelectedRound: round.id == selectedRoundId,
                ),
              ),
            )
            .toList()
        : state.selectedRound?.arrows
                .map(
                  (arrow) => _TargetArrow(
                    arrow: arrow,
                    isSelectedRound: true,
                  ),
                )
                .toList() ??
            const <_TargetArrow>[];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) =>
          _updateCrosshair(details.localPosition, targetSize),
      onTapUp: (details) {
        _updateCrosshair(details.localPosition, targetSize);
        _commitArrow(cubit, targetSize);
      },
      onTapCancel: _hideCrosshair,
      onPanStart: (details) =>
          _updateCrosshair(details.localPosition, targetSize),
      onPanUpdate: (details) =>
          _updateCrosshair(details.localPosition, targetSize),
      onPanEnd: (_) => _commitArrow(cubit, targetSize),
      onPanCancel: _hideCrosshair,
      child: SizedBox(
        width: targetSize.width,
        height: targetSize.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: ArcheryTargetPainter(
                arrows: arrows,
                highlightedArrowId: highlightId,
                targetFaceType: state.activity.targetFaceType,
              ),
            ),
            if (_crosshairPosition != null)
              CustomPaint(
                painter: _CrosshairPainter(position: _crosshairPosition!),
              ),
          ],
        ),
      ),
    );
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
                        isHighlighted: highlightedArrowId == sortedArrows[i].id,
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

class _AllRoundsHeader extends StatelessWidget {
  const _AllRoundsHeader({
    required this.totalRounds,
    required this.totalArrows,
  });

  final int totalRounds;
  final int totalArrows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All rounds view',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$totalRounds rounds · $totalArrows arrows',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.black54,
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

class _RoundList extends StatefulWidget {
  const _RoundList({
    required this.showAllRoundsOnTarget,
    required this.onAllRoundsToggle,
    required this.onRoundSelected,
  });

  final bool showAllRoundsOnTarget;
  final ValueChanged<bool> onAllRoundsToggle;
  final VoidCallback onRoundSelected;

  @override
  State<_RoundList> createState() => _RoundListState();
}

class _RoundListState extends State<_RoundList> {
  bool _isSummaryExpanded = false;

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
        final rounds = state.rounds;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rounds.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _AllRoundsSummaryCard(
                rounds: rounds,
                isExpanded: _isSummaryExpanded,
                onToggle: () {
                  final next = !_isSummaryExpanded;
                  setState(() => _isSummaryExpanded = next);
                  widget.onAllRoundsToggle(next);
                },
              );
            }
            final round = rounds[index - 1];
            final isSelected = round.id == state.selectedRoundId;
            final roundNumber = index;

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
                  onTap: () {
                    setState(() => _isSummaryExpanded = false);
                    widget.onAllRoundsToggle(false);
                    widget.onRoundSelected();
                    cubit.selectRound(round.id);
                  },
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
                      : CircleAvatar(child: Text('$roundNumber')),
                  title: Text('Round $roundNumber'),
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

class _AllRoundsSummaryCard extends StatelessWidget {
  const _AllRoundsSummaryCard({
    required this.rounds,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<ArcheryRound> rounds;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final totalRounds = rounds.length;
    final totalScore = rounds.fold<int>(
      0,
      (sum, round) => sum + round.totalScore,
    );
    final arrowCount = rounds.fold<int>(
      0,
      (sum, round) => sum + round.arrows.length,
    );
    final tenCount = rounds.fold<int>(
      0,
      (sum, round) => sum + round.arrows.where((a) => a.score == 10).length,
    );

    var bestScore = 0;
    var bestRoundIndex = 0;
    var worstScore = rounds.first.totalScore;
    var worstRoundIndex = 0;

    for (var i = 0; i < rounds.length; i++) {
      final roundScore = rounds[i].totalScore;
      if (roundScore >= bestScore) {
        bestScore = roundScore;
        bestRoundIndex = i;
      }
      if (roundScore <= worstScore) {
        worstScore = roundScore;
        worstRoundIndex = i;
      }
    }

    final averageRound =
        totalRounds == 0 ? 0.0 : totalScore.toDouble() / totalRounds;
    final averageArrow =
        arrowCount == 0 ? 0.0 : totalScore.toDouble() / arrowCount;
    final tenRate =
        arrowCount == 0 ? 0.0 : (tenCount * 100.0) / arrowCount.toDouble();

    return Card(
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_outlined),
                  const SizedBox(width: 8),
                  Text(
                    'All rounds summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SummaryStatChip(
                    label: 'Total score',
                    value: '$totalScore pts',
                  ),
                  _SummaryStatChip(
                    label: 'Avg / round',
                    value: averageRound.toStringAsFixed(1),
                  ),
                  _SummaryStatChip(
                    label: 'Arrows',
                    value: '$arrowCount',
                  ),
                  _SummaryStatChip(
                    label: '10s',
                    value: '$tenCount',
                  ),
                  _SummaryStatChip(
                    label: 'Best',
                    value: 'R${bestRoundIndex + 1} · $bestScore pts',
                  ),
                  _SummaryStatChip(
                    label: 'Lowest',
                    value: 'R${worstRoundIndex + 1} · $worstScore pts',
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Rounds logged',
                  value: '$totalRounds',
                ),
                _DetailRow(
                  label: 'Average / arrow',
                  value: averageArrow.toStringAsFixed(2),
                ),
                _DetailRow(
                  label: '10s hit rate',
                  value:
                      '${tenRate.toStringAsFixed(1)}% ($tenCount / $arrowCount)',
                ),
                _DetailRow(
                  label: 'Score spread',
                  value: '${bestScore - worstScore} pts',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStatChip extends StatelessWidget {
  const _SummaryStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetArrow {
  const _TargetArrow({
    required this.arrow,
    required this.isSelectedRound,
  });

  final ArrowHit arrow;
  final bool isSelectedRound;
}

class ArcheryTargetPainter extends CustomPainter {
  ArcheryTargetPainter({
    required this.arrows,
    this.highlightedArrowId,
    required this.targetFaceType,
  });

  final List<_TargetArrow> arrows;
  final String? highlightedArrowId;
  final TargetFaceType targetFaceType;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final spots = targetFaceType.layoutSpots(size);
    if (spots.isEmpty) return;

    final rings = _ringsFor(targetFaceType);
    final ringCount = rings.length;

    for (final spot in spots) {
      paint
        ..style = PaintingStyle.fill
        ..strokeWidth = 1.0;
      for (var i = ringCount; i >= 1; i--) {
        final ringRadius = spot.radius * (i / ringCount);
        paint.color = rings[i - 1];
        canvas.drawCircle(spot.center, ringRadius, paint);
      }

      paint
        ..color = Colors.black54
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(spot.center, spot.radius, paint);
    }

    for (final targetArrow in arrows) {
      final arrow = targetArrow.arrow;
      final isHighlighted = arrow.id == highlightedArrowId;
      final spotIndex = arrow.targetIndex.clamp(0, spots.length - 1);
      final spot = spots[spotIndex];
      final scale = spot.radius / ArcheryRepository.targetRadius;
      final arrowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isHighlighted
            ? Colors.orange
            : targetArrow.isSelectedRound
                ? Colors.deepPurple
                : Colors.deepPurple.withOpacity(0.55);
      final absolute = spot.center + arrow.position * scale;
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
      case TargetFaceType.verticalTripleSixRing:
        return [
          Colors.yellow,
          Colors.yellow.shade700,
          Colors.red,
          Colors.red.shade900,
          Colors.blue,
        ];
      case TargetFaceType.triangularTripleSixRing:
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
