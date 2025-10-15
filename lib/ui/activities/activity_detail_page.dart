import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../blocs/activity_detail/activity_detail_cubit.dart';
import '../../blocs/activity_detail/activity_detail_state.dart';
import '../../data/models/activity.dart';
import '../../data/models/photo_entry.dart';
import '../../data/repositories/activity_repository.dart';
import '../common/empty_state.dart';
import '../common/photo_grid.dart';

class ActivityDetailPage extends StatelessWidget {
  const ActivityDetailPage({super.key, required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ActivityRepository>();
    return BlocProvider(
      create: (_) => ActivityDetailCubit(activity: activity, repository: repository)..loadInitial(),
      child: const _ActivityDetailView(),
    );
  }
}

class _ActivityDetailView extends StatelessWidget {
  const _ActivityDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActivityDetailCubit, ActivityDetailState>(
      listenWhen: (prev, curr) => prev.message != curr.message,
      listener: (context, state) {
        final message = state.message;
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        final cubit = context.read<ActivityDetailCubit>();
        final isLoading = state.status == ActivityDetailStatus.loading;
        final photos = state.photos;
        return Scaffold(
          appBar: AppBar(
            title: Text(state.activity.name),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: isLoading ? null : () => _showAddPhotoSheet(context),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('新增照片'),
          ),
          body: isLoading && photos.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: cubit.refresh,
                  child: photos.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: const [
                            SizedBox(height: 160),
                            EmptyState(
                              icon: Icons.photo_outlined,
                              title: '尚未新增照片',
                              message: '使用右下角按鈕拍照或從相簿匯入，開始填滿這個活動吧！',
                            ),
                            SizedBox(height: 160),
                          ],
                        )
                      : PhotoGrid(
                          photos: photos,
                          onOpen: (photo, index) => _openPhoto(context, photo, index),
                        ),
                ),
        );
      },
    );
  }

  Future<void> _showAddPhotoSheet(BuildContext context) async {
    final cubit = context.read<ActivityDetailCubit>();
    final source = await showModalBottomSheet<ImageSource>(
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
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('拍照新增'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('從相簿選擇'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (source != null) {
      await cubit.addPhoto(source);
    }
  }

  void _openPhoto(BuildContext context, PhotoEntry photo, int index) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) {
        return GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Container(
            color: Colors.transparent,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Hero(
              tag: 'photo_${photo.path}_$index',
              child: InteractiveViewer(
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(File(photo.path)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
