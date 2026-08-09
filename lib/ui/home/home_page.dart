import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_album_codex/utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../blocs/activity/activity_bloc.dart';
import '../../blocs/activity/activity_event.dart';
import '../../blocs/activity/activity_state.dart';
import '../../blocs/navigation/navigation_cubit.dart';
import '../../blocs/settings/settings_cubit.dart';
import '../../data/models/activity.dart';
import '../../data/models/target_face.dart';
import '../../data/repositories/archery_repository.dart';
import '../../data/services/activity_stats_service.dart';
import '../activities/activity_detail_page.dart';
import '../common/activity_card.dart';
import '../common/activity_setup_dialog.dart';
import '../common/empty_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _statsReloadTick = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<ActivityBloc, ActivityState>(
          listenWhen: (previous, current) =>
              previous.message != current.message,
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
            if (state.status == ActivityStatus.loading &&
                state.activities.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.activities.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => _refreshActivities(context),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 48,
                  ),
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.photo_album_outlined,
                      title: 'No sessions yet',
                      message:
                          'Capture your first archery practice using the button below.',
                    ),
                  ],
                ),
              );
            }

            final recent = state.activities.take(5).toList();
            return RefreshIndicator(
              onRefresh: () => _refreshActivities(context),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                children: [
                  const SizedBox(height: 12),
                  _StatsSection(
                    key: ValueKey(_statsReloadTick),
                    activities: state.activities,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Recent sessions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...recent.map(
                    (activity) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ActivityCard(
                        activity: activity,
                        onTap: () => _openActivity(context, activity),
                      ),
                    ),
                  ),
                  if (state.activities.length > recent.length)
                    Align(
                      child: TextButton(
                        onPressed: () => _openActivitiesTab(context),
                        child: const Text('View all activities'),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add / Capture'),
      ),
    );
  }

  void _openActivitiesTab(BuildContext context) {
    context.read<NavigationCubit>().selectIndex(1);
  }

  void _openActivity(BuildContext context, Activity activity) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActivityDetailPage(activity: activity)),
    );
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final activityBloc = context.read<ActivityBloc>();
    final settingsCubit = context.read<SettingsCubit>();
    final settings = settingsCubit.state.settings;
    final defaultName = Utils.formatActivityName(
      settings.defaultActivityNameFormat,
    );

    await showModalBottomSheet<String>(
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
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('Create new activity'),
                subtitle: Text(defaultName),
                onTap: () async {
                  Navigator.of(sheetContext).pop('create');
                  final setup = await showActivitySetupDialog(
                    context,
                    defaultName: defaultName,
                    defaultDistanceMeters: settings.defaultDistanceMeters,
                    confirmLabel: 'Create',
                  );
                  if (!context.mounted || setup == null) return;
                  await settingsCubit.rememberDefaultDistance(
                    setup.distanceMeters,
                  );
                  activityBloc.add(
                    ActivityCreated(
                      setup.name,
                      setup.targetFaceType,
                      distanceMeters: setup.distanceMeters,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bolt_outlined),
                title: const Text('Quick capture'),
                subtitle: const Text(
                  "Auto-create today's activity and open the camera",
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop('quick');
                  final setup = await showActivitySetupDialog(
                    context,
                    defaultName: defaultName,
                    defaultDistanceMeters: settings.defaultDistanceMeters,
                    confirmLabel: 'Start capture',
                  );
                  if (!context.mounted || setup == null) return;
                  await settingsCubit.rememberDefaultDistance(
                    setup.distanceMeters,
                  );
                  activityBloc.add(
                    ActivityQuickCaptured(
                      setup.name,
                      setup.targetFaceType,
                      distanceMeters: setup.distanceMeters,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Add photo to existing'),
                onTap: () {
                  Navigator.of(sheetContext).pop('existing');
                  _showActivityPicker(context);
                },
              ),
            ],
          ),
        );
      },
    );

    // No additional handling required; actions run inside the sheet.
  }

  Future<void> _showActivityPicker(BuildContext context) async {
    final activityBloc = context.read<ActivityBloc>();
    final activities = activityBloc.state.activities;
    if (activities.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No activities available yet.'),
          duration: Duration(milliseconds: 300),
        ),
      );
      return;
    }

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return ListTile(
                leading: const Icon(Icons.photo_album_outlined),
                title: Text(activity.name),
                subtitle: Text('${activity.photoCount} photos'),
                onTap: () => Navigator.of(sheetContext).pop(activity.id),
              );
            },
          ),
        );
      },
    );

    if (!context.mounted || selectedId == null) return;
    activityBloc.add(
      ActivityPhotoAdded(id: selectedId, source: ImageSource.camera),
    );
  }

  Future<void> _refreshActivities(BuildContext context) async {
    final bloc = context.read<ActivityBloc>();
    final nextState = bloc.stream
        .firstWhere(
          (state) =>
              state.status == ActivityStatus.success ||
              state.status == ActivityStatus.failure,
        )
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            if (mounted && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refresh timed out. Please try again.'),
                  duration: Duration(milliseconds: 300),
                ),
              );
            }
            return bloc.state;
          },
        );
    bloc.add(const ActivityRefreshed());
    try {
      await nextState;
    } finally {
      if (mounted) {
        setState(() => _statsReloadTick++);
      }
    }
  }
}

class _StatsSection extends StatefulWidget {
  const _StatsSection({super.key, required this.activities});

  final List<Activity> activities;

  @override
  State<_StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends State<_StatsSection> {
  ArcheryRepository? _repository;
  Future<ActivityStats>? _statsFuture;
  String? _activitySignature;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = context.read<ArcheryRepository>();
    final signature = _signatureFor(widget.activities);
    if (!identical(_repository, repository) ||
        _activitySignature != signature) {
      _repository = repository;
      _activitySignature = signature;
      _statsFuture = ActivityStatsService(
        repository: repository,
      ).compute(widget.activities);
    }
  }

  @override
  void didUpdateWidget(covariant _StatsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _signatureFor(widget.activities);
    if (_activitySignature != signature && _repository != null) {
      _activitySignature = signature;
      _statsFuture = ActivityStatsService(
        repository: _repository!,
      ).compute(widget.activities);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<ActivityStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        if (stats == null && !isLoading) {
          return const SizedBox.shrink();
        }

        final cards = stats?.snapshots ?? const <ActivityStatsSnapshot>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance snapshot',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (stats != null) ...[
              _DashboardOverview(stats: stats),
              const SizedBox(height: 12),
              _ScoreDistributionCard(entries: stats.scoreDistribution),
              const SizedBox(height: 12),
              _TrendCard(points: stats.recentTrend),
              const SizedBox(height: 16),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                const double targetWidth = 320;
                const double spacing = 12;
                const double targetHeight = 280;

                final crossAxisCount = math.max(
                  1,
                  ((constraints.maxWidth + spacing) / (targetWidth + spacing))
                      .floor(),
                );
                final actualWidth =
                    (constraints.maxWidth - (crossAxisCount - 1) * spacing) /
                    crossAxisCount;
                final childAspectRatio = actualWidth / targetHeight;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: cards.isNotEmpty ? cards.length : 3,
                  itemBuilder: (context, index) {
                    if (stats == null) return const _StatPlaceholder();
                    final snapshot = cards[index];
                    return _StatCard(
                      title: snapshot.title,
                      subtitle: snapshot.subtitle,
                      icon: _iconFor(snapshot.kind),
                      entries: [
                        _StatEntry(label: 'Rounds', value: snapshot.rounds),
                        _StatEntry(label: 'Arrows', value: snapshot.arrows),
                        _StatEntry(
                          label: 'Avg / round',
                          value: snapshot.averageRoundScore.toStringAsFixed(1),
                        ),
                        _StatEntry(
                          label: 'Best round',
                          value: '${snapshot.bestRoundScore} pts',
                        ),
                        if (snapshot.activities > 1)
                          _StatEntry(
                            label: 'Activities',
                            value: snapshot.activities,
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _signatureFor(List<Activity> activities) {
    return activities
        .map(
          (activity) => [
            activity.id,
            activity.createdAt.toIso8601String(),
            activity.name,
            activity.targetFaceType.storageKey,
          ].join(':'),
        )
        .join('|');
  }

  IconData _iconFor(ActivityStatsSnapshotKind kind) {
    return switch (kind) {
      ActivityStatsSnapshotKind.latest => Icons.flag_outlined,
      ActivityStatsSnapshotKind.monthly => Icons.calendar_today_outlined,
      ActivityStatsSnapshotKind.overall => Icons.all_inclusive,
    };
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({required this.stats});

  final ActivityStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final isWide = constraints.maxWidth >= 720;
        final children = [
          _HeroMetricCard(
            icon: Icons.emoji_events_outlined,
            label: 'Best round',
            value: '${stats.bestRoundScore}',
            suffix: 'pts',
          ),
          _HeroMetricCard(
            icon: Icons.speed_outlined,
            label: 'Avg / arrow',
            value: stats.averageArrowScore.toStringAsFixed(1),
            suffix: 'pts',
          ),
          _HeroMetricCard(
            icon: Icons.center_focus_strong_outlined,
            label: 'X+10 rate',
            value: '${stats.xTenRate.toStringAsFixed(0)}%',
            suffix: 'hits',
          ),
        ];

        if (!isWide) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: spacing),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _HeroMetricCard extends StatelessWidget {
  const _HeroMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
  });

  final IconData icon;
  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(suffix, style: theme.textTheme.labelMedium),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreDistributionCard extends StatelessWidget {
  const _ScoreDistributionCard({required this.entries});

  final List<ScoreDistributionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxCount = entries.fold<int>(
      0,
      (maxValue, entry) => math.max(maxValue, entry.count),
    );
    final totalArrows = entries.fold<int>(0, (sum, entry) => sum + entry.count);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_outlined),
              const SizedBox(width: 8),
              Text(
                'Arrows by score',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$totalArrows arrows',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Count of every recorded arrow grouped by final score.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 14),
          for (final entry in entries) ...[
            _DistributionBar(entry: entry, maxCount: maxCount),
            if (entry != entries.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({required this.entry, required this.maxCount});

  final ScoreDistributionEntry entry;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ratio = maxCount == 0 ? 0.0 : entry.count / maxCount;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            entry.label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: ratio,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          child: Text(
            '${entry.count} arrows',
            textAlign: TextAlign.right,
            style: theme.textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points});

  final List<ActivityTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final values = points.map((point) => point.averageArrowScore).toList();
    final minValue = values.isEmpty ? 0.0 : values.reduce(math.min);
    final maxValue = values.isEmpty ? 0.0 : values.reduce(math.max);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_outlined),
              const SizedBox(width: 8),
              Text(
                'Avg arrow score trend',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${points.length} sessions',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Average points per arrow by session, oldest to latest.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 164,
            child: points.length < 2
                ? Center(
                    child: Text(
                      'Add more scored sessions to show a trend.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 42,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              maxValue.toStringAsFixed(1),
                              style: theme.textTheme.labelSmall,
                            ),
                            Text(
                              'avg pts',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.56,
                                ),
                              ),
                            ),
                            Text(
                              minValue.toStringAsFixed(1),
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: CustomPaint(
                                painter: _TrendPainter(
                                  points: points,
                                  lineColor: colorScheme.primary,
                                  fillColor: colorScheme.primary.withValues(
                                    alpha: 0.10,
                                  ),
                                  gridColor: colorScheme.outlineVariant,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'Oldest',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.58,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Latest',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.58,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  final List<ActivityTrendPoint> points;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final values = points.map((point) => point.averageArrowScore).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(1.0, maxValue - minValue);
    final chartRect = Rect.fromLTWH(2, 8, size.width - 4, size.height - 18);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = chartRect.top + chartRect.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = chartRect.left + chartRect.width * (i / (values.length - 1));
      final y =
          chartRect.bottom -
          ((values[i] - minValue) / range) * chartRect.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(chartRect.right, chartRect.bottom)
      ..lineTo(chartRect.left, chartRect.bottom)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dotPaint = Paint()..color = lineColor;
    for (var i = 0; i < values.length; i++) {
      final x = chartRect.left + chartRect.width * (i / (values.length - 1));
      final y =
          chartRect.bottom -
          ((values[i] - minValue) / range) * chartRect.height;
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.entries,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<_StatEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    final headline = entries.length >= 2 ? entries.sublist(0, 2) : entries;
    final details = entries.length > 2 ? entries.sublist(2) : <_StatEntry>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary.withValues(alpha: 0.10), colorScheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: colorScheme.shadow.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primary, size: 20),
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          if (headline.isNotEmpty)
            Row(
              children: headline
                  .map(
                    (entry) => Expanded(
                      child: _StatFigure(
                        label: entry.label,
                        value: entry.value.toString(),
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: details
                  .map(
                    (entry) => _StatPill(
                      label: entry.label,
                      value: entry.value.toString(),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatEntry {
  const _StatEntry({required this.label, required this.value});

  final String label;
  final Object value;
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatFigure extends StatelessWidget {
  const _StatFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}

class _StatPlaceholder extends StatelessWidget {
  const _StatPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 18,
            width: 90,
            decoration: BoxDecoration(
              color: colorScheme.surfaceTint.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: 140,
            decoration: BoxDecoration(
              color: colorScheme.surfaceTint.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}
