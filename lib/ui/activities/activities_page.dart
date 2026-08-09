import 'package:flutter/material.dart';
import 'package:flutter_album_codex/blocs/settings/settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../blocs/activity/activity_bloc.dart';
import '../../blocs/activity/activity_event.dart';
import '../../blocs/activity/activity_state.dart';
import '../../data/models/activity.dart';
import '../common/activity_card.dart';
import '../common/activity_setup_dialog.dart';
import 'activity_detail_page.dart';
import '../../utils.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  String? _lastOpenedActivityId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<ActivityBloc, ActivityState>(
          listenWhen: (previous, current) =>
              previous.message != current.message ||
              previous.lastCreatedActivityId != current.lastCreatedActivityId,
          listener: (context, state) {
            final message = state.message;
            if (message != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  duration: const Duration(milliseconds: 300),
                ),
              );
            }

            final createdId = state.lastCreatedActivityId;
            if (createdId != null && createdId != _lastOpenedActivityId) {
              final created = state.activities.cast<Activity?>().firstWhere(
                (activity) => activity?.id == createdId,
                orElse: () => null,
              );
              if (created != null) {
                _lastOpenedActivityId = createdId;
                _openActivityDetail(context, created);
              }
            }
          },
          builder: (context, state) {
            if (state.status == ActivityStatus.loading &&
                state.activities.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: () async =>
                  context.read<ActivityBloc>().add(const ActivityRefreshed()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                children: [
                  _ActivitiesHeader(
                    totalActivities: state.activities.length,
                    onCreate: () => _createActivity(context),
                  ),
                  const SizedBox(height: 14),
                  ...state.activities.map(
                    (activity) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ActivityCard(
                        activity: activity,
                        onTap: () => _openActivityDetail(context, activity),
                        onMorePressed: () =>
                            _showActivityActions(context, activity),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _createActivity(BuildContext context) async {
    final activityBloc = context.read<ActivityBloc>();
    final settingsCubit = context.read<SettingsCubit>();
    final settings = settingsCubit.state.settings;
    final defaultName = Utils.formatActivityName(
      settings.defaultActivityNameFormat,
    );
    final setup = await showActivitySetupDialog(
      context,
      defaultName: defaultName,
      defaultDistanceMeters: settings.defaultDistanceMeters,
      title: 'Add Activity',
      autofocusName: false,
    );
    if (setup == null || !context.mounted) return;
    await settingsCubit.rememberDefaultDistance(setup.distanceMeters);
    activityBloc.add(
      ActivityCreated(
        setup.name,
        setup.targetFaceType,
        distanceMeters: setup.distanceMeters,
      ),
    );
  }

  void _openActivityDetail(BuildContext context, Activity activity) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActivityDetailPage(activity: activity)),
    );
  }

  Future<void> _showActivityActions(
    BuildContext context,
    Activity activity,
  ) async {
    final result = await showModalBottomSheet<String>(
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
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename'),
                onTap: () => Navigator.of(sheetContext).pop('rename'),
              ),
              ListTile(
                leading: const Icon(Icons.add_a_photo_outlined),
                title: const Text('Capture photo'),
                onTap: () => Navigator.of(sheetContext).pop('photo'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete activity'),
                textColor: Colors.redAccent,
                iconColor: Colors.redAccent,
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted) return;

    switch (result) {
      case 'rename':
        _renameActivity(context, activity);
        break;
      case 'photo':
        context.read<ActivityBloc>().add(
          ActivityPhotoAdded(id: activity.id, source: ImageSource.camera),
        );
        break;
      case 'delete':
        _deleteActivity(context, activity);
        break;
    }
  }

  void _renameActivity(BuildContext context, Activity activity) {
    final controller = TextEditingController(text: activity.name);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename activity'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Activity name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  context.read<ActivityBloc>().add(
                    ActivityRenamed(id: activity.id, newName: value),
                  );
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteActivity(BuildContext context, Activity activity) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete activity'),
          content: Text(
            'Delete "${activity.name}"? This removes all associated rounds and photos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                context.read<ActivityBloc>().add(ActivityDeleted(activity.id));
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

class _ActivitiesHeader extends StatelessWidget {
  const _ActivitiesHeader({
    required this.totalActivities,
    required this.onCreate,
  });

  final int totalActivities;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.14),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 10),
            color: colorScheme.shadow.withValues(alpha: 0.08),
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
                  color: colorScheme.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.flag_outlined, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activities',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Keep your archery sessions organized with quick actions on each card.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeaderStat(label: 'Sessions', value: totalActivities.toString()),
              const SizedBox(width: 10),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
