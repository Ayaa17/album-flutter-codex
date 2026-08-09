import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/activity_detail/activity_detail_cubit.dart';
import '../../blocs/activity_detail/activity_detail_state.dart';
import '../../data/models/activity.dart';
import '../../data/models/archery_models.dart';
import '../../data/models/target_face.dart';
import '../../data/repositories/archery_repository.dart';
import 'widgets/round_list.dart';
import 'widgets/target_canvas.dart';
import 'widgets/target_canvas_painters.dart';

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
  static const Offset _fingerPlacementOffset = Offset(0, -44);
  static const double _nudgeStep = 1.5;

  Offset? _crosshairPosition;
  Offset? _pendingArrowPosition;
  Size? _pendingTargetSize;
  String? _highlightedArrowId;
  bool _isTargetExpanded = false;
  bool _showAllRoundsOnTarget = true;
  Timer? _nudgeSaveTimer;
  bool _hasPendingNudgeSave = false;
  late ActivityDetailCubit _detailCubit;

  @override
  void initState() {
    super.initState();
    _showAllRoundsOnTarget = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _detailCubit = context.read<ActivityDetailCubit>();
  }

  @override
  void dispose() {
    _nudgeSaveTimer?.cancel();
    if (_hasPendingNudgeSave) {
      unawaited(_detailCubit.saveCurrentRounds());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActivityDetailCubit, ActivityDetailState>(
      listenWhen: (previous, current) => previous.message != current.message,
      listener: (context, state) {
        final message = state.message;
        if (message != null && message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(milliseconds: 300),
            ),
          );
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
        final latestArrowId = selectedRound?.arrows.isEmpty ?? true
            ? null
            : selectedRound!.arrows.first.id;
        final showNudgeControls =
            !_showAllRoundsOnTarget && highlightId == latestArrowId;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.activity.name),
                Text(
                  _activityMetaLabel(state.activity),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Undo last arrow',
                onPressed: selectedRound?.arrows.isEmpty ?? true
                    ? null
                    : _undoLastArrow,
                icon: const Icon(Icons.undo),
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
                        flex: 5,
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
                                                _showArrowActions(
                                                  context,
                                                  selectedRound,
                                                  arrow,
                                                ),
                                            onPreviousArrow: () =>
                                                _selectAdjacentArrow(
                                                  selectedRound,
                                                  -1,
                                                ),
                                            onNextArrow: () =>
                                                _selectAdjacentArrow(
                                                  selectedRound,
                                                  1,
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
                                      if (showNudgeControls) ...[
                                        const SizedBox(height: 8),
                                        _SelectedArrowControls(
                                          onRetract: _retractHighlightedArrow,
                                          onNudgeUp: () =>
                                              _nudgeHighlightedArrow(
                                                const Offset(0, -_nudgeStep),
                                              ),
                                          onNudgeDown: () =>
                                              _nudgeHighlightedArrow(
                                                const Offset(0, _nudgeStep),
                                              ),
                                          onNudgeLeft: () =>
                                              _nudgeHighlightedArrow(
                                                const Offset(-_nudgeStep, 0),
                                              ),
                                          onNudgeRight: () =>
                                              _nudgeHighlightedArrow(
                                                const Offset(_nudgeStep, 0),
                                              ),
                                        ),
                                      ],
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
                                          IconButton(
                                            onPressed: () => setState(
                                              () => _isTargetExpanded = true,
                                            ),
                                            icon: const Icon(
                                              Icons.open_in_full,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _addRoundAndFocus,
                                            icon: const Icon(
                                              Icons.my_location_outlined,
                                            ),
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
                        flex: 5,
                        child: RoundList(
                          showAllRoundsOnTarget: _showAllRoundsOnTarget,
                          onAllRoundsToggle: (value) {
                            setState(() {
                              _showAllRoundsOnTarget = value;
                              if (value) _highlightedArrowId = null;
                            });
                          },
                          onRoundSelected: () =>
                              setState(() => _showAllRoundsOnTarget = false),
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
                        child: Column(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Center(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final targetSize = _expandedTargetSize(
                                          state.activity.targetFaceType,
                                          constraints,
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
                                      onPressed: () => setState(
                                        () => _isTargetExpanded = false,
                                      ),
                                      child: const Icon(Icons.close_fullscreen),
                                    ),
                                  ),
                                  Positioned(
                                    right: 16,
                                    bottom: 16,
                                    child: FloatingActionButton.extended(
                                      onPressed: _addRoundAndFocus,
                                      icon: const Icon(
                                        Icons.my_location_outlined,
                                      ),
                                      label: const Text('Add Round'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (showNudgeControls)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: _SelectedArrowControls(
                                  onRetract: _retractHighlightedArrow,
                                  onNudgeUp: () => _nudgeHighlightedArrow(
                                    const Offset(0, -_nudgeStep),
                                  ),
                                  onNudgeDown: () => _nudgeHighlightedArrow(
                                    const Offset(0, _nudgeStep),
                                  ),
                                  onNudgeLeft: () => _nudgeHighlightedArrow(
                                    const Offset(-_nudgeStep, 0),
                                  ),
                                  onNudgeRight: () => _nudgeHighlightedArrow(
                                    const Offset(_nudgeStep, 0),
                                  ),
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

  String _activityMetaLabel(Activity activity) {
    final distance = activity.distanceMeters == null
        ? null
        : '${activity.distanceMeters}m';
    return [
      if (distance != null) distance,
      activity.targetFaceType.label,
    ].join(' - ');
  }

  Future<void> _addRoundAndFocus() async {
    await context.read<ActivityDetailCubit>().addRound();
    if (!mounted) return;
    setState(() {
      _showAllRoundsOnTarget = false;
      _highlightedArrowId = null;
      _crosshairPosition = null;
      _pendingArrowPosition = null;
      _pendingTargetSize = null;
    });
  }

  void _updateCrosshair(
    Offset rawPosition,
    Size targetSize, {
    bool offsetFromFinger = false,
  }) {
    final placementPosition = offsetFromFinger
        ? rawPosition + _fingerPlacementOffset
        : rawPosition;
    final position = _clampToTarget(placementPosition, targetSize);
    setState(() {
      _crosshairPosition = position;
      _pendingArrowPosition = position;
      _pendingTargetSize = targetSize;
    });
  }

  Future<void> _commitPendingArrow() async {
    final position = _pendingArrowPosition;
    final targetSize = _pendingTargetSize;
    if (position == null || targetSize == null) {
      _hideCrosshair();
      return;
    }
    _hideCrosshair();
    final cubit = context.read<ActivityDetailCubit>();
    final addedArrow = await cubit.addArrow(position, targetSize);
    if (!mounted || addedArrow == null) return;
    setState(() {
      _showAllRoundsOnTarget = false;
      _highlightedArrowId = addedArrow.id;
    });
  }

  Future<void> _nudgeHighlightedArrow(Offset delta) async {
    final round = context.read<ActivityDetailCubit>().state.selectedRound;
    final arrowId = _highlightedArrowId;
    if (round == null || arrowId == null) return;
    await context.read<ActivityDetailCubit>().nudgeArrow(
      roundId: round.id,
      arrowId: arrowId,
      delta: delta,
      persist: false,
    );
    _scheduleNudgeSave();
  }

  void _scheduleNudgeSave() {
    _hasPendingNudgeSave = true;
    _nudgeSaveTimer?.cancel();
    _nudgeSaveTimer = Timer(
      const Duration(milliseconds: 350),
      _flushPendingNudgeSave,
    );
  }

  void _flushPendingNudgeSave() {
    if (!_hasPendingNudgeSave) return;
    _hasPendingNudgeSave = false;
    _nudgeSaveTimer?.cancel();
    _nudgeSaveTimer = null;
    unawaited(_detailCubit.saveCurrentRounds());
  }

  Future<void> _retractHighlightedArrow() async {
    final round = context.read<ActivityDetailCubit>().state.selectedRound;
    final arrowId = _highlightedArrowId;
    if (round == null || arrowId == null) return;

    await context.read<ActivityDetailCubit>().removeArrow(round.id, arrowId);
    if (!mounted) return;
    setState(() {
      _highlightedArrowId = null;
      _crosshairPosition = null;
      _pendingArrowPosition = null;
      _pendingTargetSize = null;
    });
  }

  Future<void> _undoLastArrow() async {
    final removedArrow = await context
        .read<ActivityDetailCubit>()
        .undoLastArrow();
    if (!mounted || removedArrow == null) return;
    if (_highlightedArrowId == removedArrow.id) {
      setState(() => _highlightedArrowId = null);
    }
  }

  void _hideCrosshair() {
    if (_crosshairPosition == null && _pendingArrowPosition == null) {
      return;
    }
    setState(() {
      _crosshairPosition = null;
      _pendingArrowPosition = null;
      _pendingTargetSize = null;
    });
  }

  Offset _clampToTarget(Offset rawPosition, Size targetSize) {
    final dx = rawPosition.dx.clamp(0.0, targetSize.width);
    final dy = rawPosition.dy.clamp(0.0, targetSize.height);
    return Offset(dx, dy);
  }

  void _handleArrowTap(ArrowHit arrow) {
    setState(() {
      _highlightedArrowId = arrow.id;
    });
  }

  void _selectAdjacentArrow(ArcheryRound round, int direction) {
    if (round.arrows.isEmpty) return;
    final currentIndex = round.arrows.indexWhere(
      (arrow) => arrow.id == _highlightedArrowId,
    );
    final baseIndex = currentIndex == -1 ? 0 : currentIndex;
    final nextIndex = (baseIndex + direction) % round.arrows.length;
    final normalizedIndex = nextIndex < 0 ? round.arrows.length - 1 : nextIndex;
    setState(() {
      _highlightedArrowId = round.arrows[normalizedIndex].id;
    });
  }

  String _formatArrowScore(ArrowHit arrow) {
    return arrow.isX ? 'X (10)' : '${arrow.score}';
  }

  Future<void> _showArrowActions(
    BuildContext context,
    ArcheryRound round,
    ArrowHit arrow,
  ) async {
    _handleArrowTap(arrow);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text('Edit score (${_formatArrowScore(arrow)})'),
                onTap: () => Navigator.of(sheetContext).pop('score'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete arrow'),
                textColor: Colors.redAccent,
                iconColor: Colors.redAccent,
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
          ),
        );
      },
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'score':
        await _editArrowScore(context, round, arrow);
        break;
      case 'delete':
        await _deleteArrow(context, round, arrow);
        break;
    }
  }

  Future<void> _editArrowScore(
    BuildContext context,
    ArcheryRound round,
    ArrowHit arrow,
  ) async {
    final score = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Arrow score'),
          children: [
            for (final value in [10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0])
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(value),
                child: Text(value == 0 ? 'Miss (0)' : '$value pts'),
              ),
          ],
        );
      },
    );
    if (!context.mounted || score == null) return;
    await context.read<ActivityDetailCubit>().updateArrowScore(
      roundId: round.id,
      arrowId: arrow.id,
      newScore: score,
    );
  }

  Future<void> _deleteArrow(
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
              content: Text(
                'Remove the arrow scored ${_formatArrowScore(arrow)} pts?',
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
    if (!confirmed || !context.mounted) return;
    await context.read<ActivityDetailCubit>().removeArrow(round.id, arrow.id);
    if (!mounted) return;
    if (_highlightedArrowId == arrow.id) {
      setState(() {
        final remaining = round.arrows
            .where((candidate) => candidate.id != arrow.id)
            .toList();
        _highlightedArrowId = remaining.isEmpty ? null : remaining.first.id;
      });
    }
  }

  Widget _buildTargetCanvas(
    Size targetSize,
    ActivityDetailState state,
    String? highlightId,
    bool showAllRounds,
  ) {
    final selectedRoundId = state.selectedRoundId;
    final arrows = showAllRounds
        ? state.rounds
              .expand(
                (round) => round.arrows.map(
                  (arrow) => TargetCanvasArrow(
                    arrow: arrow,
                    isSelectedRound: round.id == selectedRoundId,
                  ),
                ),
              )
              .toList()
        : state.selectedRound?.arrows
                  .map(
                    (arrow) =>
                        TargetCanvasArrow(arrow: arrow, isSelectedRound: true),
                  )
                  .toList() ??
              const <TargetCanvasArrow>[];

    return TargetCanvas(
      targetSize: targetSize,
      arrows: arrows,
      targetFaceType: state.activity.targetFaceType,
      highlightedArrowId: highlightId,
      crosshairPosition: _crosshairPosition,
      onTapPreview: (position) => _updateCrosshair(position, targetSize),
      onTapCommit: (position) {
        _updateCrosshair(position, targetSize);
        _commitPendingArrow();
      },
      onDragPreview: (position) =>
          _updateCrosshair(position, targetSize, offsetFromFinger: true),
      onDragCommit: _commitPendingArrow,
      onCancel: _hideCrosshair,
    );
  }

  Size _expandedTargetSize(TargetFaceType type, BoxConstraints constraints) {
    final padding = type == TargetFaceType.triangularTripleSixRing ? 8.0 : 24.0;
    final maxWidth = math.max(0.0, constraints.maxWidth - padding);
    final maxHeight = math.max(0.0, constraints.maxHeight - padding);

    if (type == TargetFaceType.verticalTripleSixRing) {
      final width = math.min(maxWidth, maxHeight / 3);
      final height = width * 3;
      return Size(width, height);
    }

    if (type == TargetFaceType.triangularTripleSixRing) {
      const double widthFactor = 4.24;
      const double heightFactor = 3.72;
      final radius = math.min(maxWidth / widthFactor, maxHeight / heightFactor);
      return Size(radius * widthFactor, radius * heightFactor);
    }

    final size = math.min(maxWidth, maxHeight);
    return Size.square(size);
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
    required this.onPreviousArrow,
    required this.onNextArrow,
  });

  final ArcheryRound round;
  final int roundIndex;
  final String? highlightedArrowId;
  final void Function(ArrowHit arrow) onArrowTap;
  final void Function(ArrowHit arrow) onArrowLongPress;
  final VoidCallback onPreviousArrow;
  final VoidCallback onNextArrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedArrows = [...round.arrows]
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        if (a.isX == b.isX) return 0;
        return a.isX ? -1 : 1;
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Round $roundIndex - ${round.totalScore} pts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (round.arrows.isNotEmpty) ...[
              IconButton(
                tooltip: 'Previous arrow',
                visualDensity: VisualDensity.compact,
                onPressed: onPreviousArrow,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next arrow',
                visualDensity: VisualDensity.compact,
                onPressed: onNextArrow,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ],
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
                        isX: sortedArrows[i].isX,
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
            'Tap the target to add an arrow. Select an arrow to fine-tune.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
      ],
    );
  }
}

class _SelectedArrowControls extends StatelessWidget {
  const _SelectedArrowControls({
    required this.onRetract,
    required this.onNudgeUp,
    required this.onNudgeDown,
    required this.onNudgeLeft,
    required this.onNudgeRight,
  });

  final VoidCallback onRetract;
  final VoidCallback onNudgeUp;
  final VoidCallback onNudgeDown;
  final VoidCallback onNudgeLeft;
  final VoidCallback onNudgeRight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              tooltip: 'Retract arrow',
              onPressed: onRetract,
              style: IconButton.styleFrom(
                fixedSize: const Size(48, 48),
                foregroundColor: colorScheme.error,
                backgroundColor: colorScheme.errorContainer,
              ),
              icon: const Icon(Icons.close),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 84,
              child: VerticalDivider(
                width: 1,
                color: colorScheme.outlineVariant,
              ),
            ),
            const SizedBox(width: 10),
            _NudgePad(
              onUp: onNudgeUp,
              onDown: onNudgeDown,
              onLeft: onNudgeLeft,
              onRight: onNudgeRight,
            ),
          ],
        ),
      ),
    );
  }
}

class _NudgePad extends StatelessWidget {
  const _NudgePad({
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 152,
      height: 152,
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: [
          const SizedBox.shrink(),
          _NudgeButton(
            tooltip: 'Nudge up',
            icon: Icons.keyboard_arrow_up,
            onPressed: onUp,
          ),
          const SizedBox.shrink(),
          _NudgeButton(
            tooltip: 'Nudge left',
            icon: Icons.keyboard_arrow_left,
            onPressed: onLeft,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Icon(
              Icons.adjust,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          _NudgeButton(
            tooltip: 'Nudge right',
            icon: Icons.keyboard_arrow_right,
            onPressed: onRight,
          ),
          const SizedBox.shrink(),
          _NudgeButton(
            tooltip: 'Nudge down',
            icon: Icons.keyboard_arrow_down,
            onPressed: onDown,
          ),
          const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _NudgeButton extends StatefulWidget {
  const _NudgeButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_NudgeButton> createState() => _NudgeButtonState();
}

class _NudgeButtonState extends State<_NudgeButton> {
  Timer? _holdDelayTimer;
  Timer? _repeatTimer;
  bool _isPointerDown = false;

  void _nudge() {
    HapticFeedback.selectionClick();
    widget.onPressed();
  }

  void _handlePointerDown() {
    _isPointerDown = true;
    _holdDelayTimer?.cancel();
    _holdDelayTimer = Timer(const Duration(milliseconds: 260), () {
      if (!_isPointerDown) return;
      _nudge();
      _startRepeat();
    });
  }

  void _startRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => widget.onPressed(),
    );
  }

  void _handlePointerUp() {
    _isPointerDown = false;
    _stopRepeat();
  }

  void _stopRepeat() {
    _holdDelayTimer?.cancel();
    _holdDelayTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      child: Listener(
        onPointerDown: (_) => _handlePointerDown(),
        onPointerUp: (_) => _handlePointerUp(),
        onPointerCancel: (_) => _handlePointerUp(),
        child: Material(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _nudge,
            child: SizedBox.square(
              dimension: 48,
              child: Icon(
                widget.icon,
                size: 30,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ),
      ),
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
          '$totalRounds rounds - $totalArrows arrows',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }
}

class _ArrowScorePill extends StatelessWidget {
  const _ArrowScorePill({
    required this.score,
    required this.isX,
    this.isHighlighted = false,
    this.onTap,
    this.onLongPress,
  });

  final int score;
  final bool isX;
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
              : colorScheme.onPrimary.withValues(alpha: 0.18),
          width: isHighlighted ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.22),
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
                isX ? 'X' : '$score',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onPrimary,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.15),
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
