import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../blocs/activity/activity_bloc.dart';
import '../../blocs/activity/activity_event.dart';
import '../../blocs/activity/activity_state.dart';
import '../../data/models/activity.dart';
import '../common/activity_grid_tile.dart';
import '../common/empty_state.dart';
import 'activity_detail_page.dart';

class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<ActivityBloc, ActivityState>(
          listenWhen: (previous, current) =>
              previous.message != current.message,
          listener: (context, state) {
            final message = state.message;
            if (message != null) {
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
                      title: 'No activities yet',
                      message:
                          'Use the button below or the Home tab to add your first archery session.',
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async =>
                  context.read<ActivityBloc>().add(const ActivityRefreshed()),
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
                itemCount: state.activities.length,
                itemBuilder: (context, index) {
                  final activity = state.activities[index];
                  return ActivityGridTile(
                    activity: activity,
                    onTap: () => _openActivityDetail(context, activity),
                    onLongPress: () => _showActivityActions(context, activity),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createActivity(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Activity'),
      ),
    );
  }

  void _createActivity(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Activity'),
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
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  context.read<ActivityBloc>().add(ActivityCreated(name));
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
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
            'Delete “${activity.name}”? This removes all associated rounds and photos.',
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
