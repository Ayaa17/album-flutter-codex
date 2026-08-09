import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/activity.dart';
import '../../data/models/target_face.dart';
import '../../data/repositories/archery_repository.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
    this.onMorePressed,
  });

  final Activity activity;
  final VoidCallback onTap;
  final VoidCallback? onMorePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activity.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (onMorePressed != null)
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: onMorePressed,
                            splashRadius: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _TargetBadge(type: activity.targetFaceType),
                        if (activity.distanceMeters != null)
                          _DistanceBadge(
                            distanceMeters: activity.distanceMeters!,
                          ),
                        _ActivityStatsRow(activityId: activity.id),
                        Text(
                          'Created ${_formatDate(activity.createdAt)} - ${activity.photoCount} photos',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: activity.coverPhotoPath == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.08),
                          ),
                          child: Icon(
                            Icons.photo_library_outlined,
                            color: colorScheme.primary,
                            size: 36,
                          ),
                        )
                      : Hero(
                          tag: 'activity_cover_${activity.id}',
                          child: Image.file(
                            File(activity.coverPhotoPath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.distanceMeters});

  final int distanceMeters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.straighten_outlined, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '${distanceMeters}m',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TargetBadge extends StatelessWidget {
  const _TargetBadge({required this.type});

  final TargetFaceType type;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.track_changes_outlined,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            type.label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ActivityStatsRow extends StatefulWidget {
  const _ActivityStatsRow({required this.activityId});

  final String activityId;

  @override
  State<_ActivityStatsRow> createState() => _ActivityStatsRowState();
}

class _ActivityStatsRowState extends State<_ActivityStatsRow> {
  ArcheryRepository? _repository;
  Future<_ActivityQuickStats>? _statsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = context.read<ArcheryRepository>();
    if (!identical(_repository, repository)) {
      _repository = repository;
      _statsFuture = _load(repository, widget.activityId);
    }
  }

  @override
  void didUpdateWidget(covariant _ActivityStatsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityId != widget.activityId && _repository != null) {
      _statsFuture = _load(_repository!, widget.activityId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ActivityQuickStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final stats = snapshot.data;
        if (stats == null) return const SizedBox.shrink();

        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _pill(
              context,
              Icons.sports_score_outlined,
              '${stats.averageScore.toStringAsFixed(1)} avg',
            ),
            _pill(
              context,
              Icons.arrow_circle_up_outlined,
              '${stats.totalArrows} arrows',
            ),
          ],
        );
      },
    );
  }

  Future<_ActivityQuickStats> _load(
    ArcheryRepository repository,
    String activityId,
  ) async {
    final rounds = await repository.loadRounds(activityId);
    if (rounds.isEmpty) {
      return const _ActivityQuickStats(totalArrows: 0, averageScore: 0);
    }
    final totalArrows = rounds.fold<int>(
      0,
      (sum, round) => sum + round.arrows.length,
    );
    final totalScore = rounds.fold<int>(
      0,
      (sum, round) => sum + round.totalScore,
    );
    final average = totalArrows == 0
        ? 0.0
        : totalScore / totalArrows.toDouble();
    return _ActivityQuickStats(totalArrows: totalArrows, averageScore: average);
  }

  Widget _pill(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ActivityQuickStats {
  const _ActivityQuickStats({
    required this.totalArrows,
    required this.averageScore,
  });

  final int totalArrows;
  final double averageScore;
}
