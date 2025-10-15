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
          listenWhen: (previous, current) => previous.message != current.message,
          listener: (context, state) {
            final message = state.message;
            if (message != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
            }
          },
          builder: (context, state) {
            if (state.status == ActivityStatus.loading && state.activities.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.activities.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => context.read<ActivityBloc>().add(const ActivityRefreshed()),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.photo_album_outlined,
                      title: '還沒有活動',
                      message: '透過右下角按鈕新增活動或從首頁快速拍照。',
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => context.read<ActivityBloc>().add(const ActivityRefreshed()),
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
        label: const Text('新增活動'),
      ),
    );
  }

  void _createActivity(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新增活動'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '活動名稱'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  context.read<ActivityBloc>().add(ActivityCreated(name));
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('建立'),
            ),
          ],
        );
      },
    );
  }

  void _openActivityDetail(BuildContext context, Activity activity) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(activity: activity),
      ),
    );
  }

  Future<void> _showActivityActions(BuildContext context, Activity activity) async {
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
                title: const Text('重新命名'),
                onTap: () => Navigator.of(sheetContext).pop('rename'),
              ),
              ListTile(
                leading: const Icon(Icons.add_a_photo_outlined),
                title: const Text('新增照片'),
                onTap: () => Navigator.of(sheetContext).pop('photo'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('刪除活動'),
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
        context
            .read<ActivityBloc>()
            .add(ActivityPhotoAdded(id: activity.id, source: ImageSource.camera));
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
          title: const Text('重新命名活動'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '活動名稱'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  context
                      .read<ActivityBloc>()
                      .add(ActivityRenamed(id: activity.id, newName: value));
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('儲存'),
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
          title: const Text('刪除活動'),
          content: Text('確定要刪除「${activity.name}」？這會移除所有相關照片。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                context.read<ActivityBloc>().add(ActivityDeleted(activity.id));
                Navigator.of(dialogContext).pop();
              },
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
  }
}
