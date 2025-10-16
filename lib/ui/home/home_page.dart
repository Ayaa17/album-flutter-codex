import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../blocs/activity/activity_bloc.dart';
import '../../blocs/activity/activity_event.dart';
import '../../blocs/activity/activity_state.dart';
import '../../blocs/navigation/navigation_cubit.dart';
import '../../blocs/settings/settings_cubit.dart';
import '../../data/models/activity.dart';
import '../activities/activity_detail_page.dart';
import '../common/activity_card.dart';
import '../common/empty_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
                onRefresh: () async =>
                    context.read<ActivityBloc>().add(const ActivityRefreshed()),
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
              onRefresh: () async =>
                  context.read<ActivityBloc>().add(const ActivityRefreshed()),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                children: [
                  const SizedBox(height: 12),
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
                  final controller = TextEditingController(text: defaultName);
                  final confirmedName = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) {
                      return AlertDialog(
                        title: const Text('Create activity'),
                        content: TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Activity name',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              final value = controller.text.trim();
                              Navigator.of(
                                dialogContext,
                              ).pop(value.isEmpty ? defaultName : value);
                            },
                            child: const Text('Create'),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirmedName != null && context.mounted) {
                    activityBloc.add(ActivityCreated(confirmedName));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.bolt_outlined),
                title: const Text('Quick capture'),
                subtitle: const Text(
                  'Auto-create today’s activity and open the camera',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop('quick');
                  activityBloc.add(ActivityQuickCaptured(defaultName));
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

  String _formatActivityName(String template) {
    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}';
    return template.replaceAll('{date}', formattedDate);
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
