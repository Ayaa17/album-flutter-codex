import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
import '../activities/activity_detail_page.dart';
import '../common/activity_card.dart';
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
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
    final settings = context.read<SettingsCubit>().state.settings;
    final defaultName = _formatActivityName(settings.defaultActivityNameFormat);

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
                  final setup = await _promptActivitySetup(
                    context,
                    defaultName: defaultName,
                    confirmLabel: 'Create',
                  );
                  if (!context.mounted || setup == null) return;
                  activityBloc.add(
                    ActivityCreated(setup.name, setup.targetFaceType),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bolt_outlined),
                title: const Text('Quick capture'),
                subtitle: const Text(
                  'Auto-create today’s activity and open the camera',
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop('quick');
                  final setup = await _promptActivitySetup(
                    context,
                    defaultName: defaultName,
                    confirmLabel: 'Start capture',
                  );
                  if (!context.mounted || setup == null) return;
                  activityBloc.add(
                    ActivityQuickCaptured(defaultName, setup.targetFaceType),
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
        const SnackBar(content: Text('No activities available yet.')),
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

  Future<_ActivitySetup?> _promptActivitySetup(
    BuildContext context, {
    required String defaultName,
    required String confirmLabel,
  }) {
    final controller = TextEditingController(text: defaultName);
    TargetFaceType selected = TargetFaceType.fullTenRing;
    return showDialog<_ActivitySetup>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final bottomInset = MediaQuery.of(dialogContext).viewInsets.bottom;
            return AlertDialog(
              title: const Text('New activity'),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              content: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Activity name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Target face',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    ...TargetFaceType.values.map(
                      (type) => RadioListTile<TargetFaceType>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: type,
                        groupValue: selected,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => selected = value);
                        },
                        title: Text(type.label),
                        subtitle: Text(type.description),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = controller.text.trim().isEmpty
                        ? defaultName
                        : controller.text.trim();
                    Navigator.of(dialogContext).pop(
                      _ActivitySetup(
                        name: name,
                        targetFaceType: selected,
                      ),
                    );
                  },
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatActivityName(String template) {
    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}';
    return template.replaceAll('{date}', formattedDate);
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  Future<void> _refreshActivities(BuildContext context) async {
    final bloc = context.read<ActivityBloc>();
    final nextState = bloc.stream.firstWhere(
      (state) =>
          state.status == ActivityStatus.success ||
          state.status == ActivityStatus.failure,
    ).timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refresh timed out. Please try again.')),
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

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    super.key,
    required this.activities,
  });

  final List<Activity> activities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_ActivityStats>(
      future: _computeStats(context, activities),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        if (stats == null && !isLoading) {
          return const SizedBox.shrink();
        }

        final cards = stats?.snapshots ?? const <_Snapshot>[];

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
            LayoutBuilder(
              builder: (context, constraints) {
                const double targetWidth = 320;
                const double spacing = 12;
                const double targetHeight = 280;

                final crossAxisCount = math.max(
                  1,
                  ((constraints.maxWidth + spacing) /
                          (targetWidth + spacing))
                      .floor(),
                );
                final actualWidth = (constraints.maxWidth -
                        (crossAxisCount - 1) * spacing) /
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
                      icon: snapshot.icon,
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

  Future<_ActivityStats> _computeStats(
    BuildContext context,
    List<Activity> activities,
  ) async {
    final repository = context.read<ArcheryRepository>();

    final now = DateTime.now();
    final latestActivity = activities.isEmpty ? null : activities.first;

    var totalRounds = 0;
    var totalArrows = 0;
    var totalScore = 0;
    var bestRoundScore = 0;

    var monthRounds = 0;
    var monthArrows = 0;
    var monthScore = 0;
    var monthBest = 0;
    var monthActivities = 0;

    var latestRounds = 0;
    var latestArrows = 0;
    var latestScore = 0;
    var latestBest = 0;

    for (final activity in activities) {
      final rounds = await repository.loadRounds(activity.id);
      final roundCount = rounds.length;
      final arrowsCount = rounds.fold<int>(
        0,
        (sum, round) => sum + round.arrows.length,
      );
      final scoreSum = rounds.fold<int>(0, (sum, round) => sum + round.totalScore);
      final bestRound =
          rounds.fold<int>(0, (best, round) => math.max(best, round.totalScore));

      totalRounds += rounds.length;
      totalArrows += arrowsCount;
      totalScore += scoreSum;
      bestRoundScore = math.max(bestRoundScore, bestRound);

      final isThisMonth =
          activity.createdAt.year == now.year && activity.createdAt.month == now.month;
      if (isThisMonth) {
        monthActivities += 1;
        monthRounds += roundCount;
        monthArrows += arrowsCount;
        monthScore += scoreSum;
        monthBest = math.max(monthBest, bestRound);
      }

      if (latestActivity != null && activity.id == latestActivity.id) {
        latestRounds = roundCount;
        latestArrows = arrowsCount;
        latestScore = scoreSum;
        latestBest = bestRound;
      }
    }

    final double averageRoundScore =
        totalRounds == 0 ? 0.0 : totalScore.toDouble() / totalRounds;
    final double monthAverage =
        monthRounds == 0 ? 0.0 : monthScore.toDouble() / monthRounds;
    final double latestAverage =
        latestRounds == 0 ? 0.0 : latestScore.toDouble() / latestRounds;

    return _ActivityStats(
      latest: latestActivity == null
          ? null
          : _Snapshot(
              title: 'Latest session',
              subtitle: latestActivity.name,
              icon: Icons.flag_outlined,
              activities: 1,
              rounds: latestRounds,
              arrows: latestArrows,
              bestRoundScore: latestBest,
              averageRoundScore: latestAverage,
            ),
      monthly: _Snapshot(
        title: 'This month',
        subtitle: '${monthActivities} activities',
        icon: Icons.calendar_today_outlined,
        activities: monthActivities,
        rounds: monthRounds,
        arrows: monthArrows,
        bestRoundScore: monthBest,
        averageRoundScore: monthAverage,
      ),
      overall: _Snapshot(
        title: 'All time',
        subtitle: '${activities.length} activities',
        icon: Icons.all_inclusive,
        activities: activities.length,
        rounds: totalRounds,
        arrows: totalArrows,
        bestRoundScore: bestRoundScore,
        averageRoundScore: averageRoundScore,
      ),
    );
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
          colors: [
            primary.withValues(alpha: 0.10),
            colorScheme.surface,
          ],
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
        color: colorScheme.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor,
            ),
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
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.hintColor,
          ),
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
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
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

class _ActivityStats {
  const _ActivityStats({
    required this.latest,
    required this.monthly,
    required this.overall,
  });

  final _Snapshot? latest;
  final _Snapshot monthly;
  final _Snapshot overall;

  List<_Snapshot> get snapshots => [
    if (latest != null) latest!,
    monthly,
    overall,
  ];
}

class _Snapshot {
  const _Snapshot({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.activities,
    required this.rounds,
    required this.arrows,
    required this.bestRoundScore,
    required this.averageRoundScore,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int activities;
  final int rounds;
  final int arrows;
  final int bestRoundScore;
  final double averageRoundScore;
}

class _ActivitySetup {
  const _ActivitySetup({required this.name, required this.targetFaceType});

  final String name;
  final TargetFaceType targetFaceType;
}
