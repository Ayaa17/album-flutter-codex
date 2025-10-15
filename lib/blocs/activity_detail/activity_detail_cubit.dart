import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/activity.dart';
import '../../data/models/photo_entry.dart';
import '../../data/repositories/activity_repository.dart';
import 'activity_detail_state.dart';

class ActivityDetailCubit extends Cubit<ActivityDetailState> {
  ActivityDetailCubit({
    required Activity activity,
    required ActivityRepository repository,
  })  : _repository = repository,
        super(ActivityDetailState(activity: activity));

  final ActivityRepository _repository;

  Future<void> loadInitial() async {
    await _loadPhotos(showSpinner: true);
  }

  Future<void> refresh() async {
    await _loadPhotos(showSpinner: false);
  }

  Future<void> addPhoto(ImageSource source) async {
    emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    try {
      final updated = await _repository.addPhotoToActivity(state.activity.id, source);
      final photos = await _repository.loadPhotos(state.activity.id);
      emit(
        state.copyWith(
          activity: updated,
          photos: photos,
          status: ActivityDetailStatus.success,
          message: '照片已新增',
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: ActivityDetailStatus.failure, message: '新增照片失敗。'));
    }
  }

  Future<void> _loadPhotos({required bool showSpinner}) async {
    emit(state.copyWith(
      status: showSpinner ? ActivityDetailStatus.loading : state.status,
      message: null,
    ));
    try {
      final refreshedActivity = await _repository.loadActivities().then(
        (activities) => activities.firstWhere(
          (activity) => activity.id == state.activity.id,
          orElse: () => state.activity,
        ),
      );
      final photos = await _repository.loadPhotos(refreshedActivity.id);
      emit(
        state.copyWith(
          activity: refreshedActivity,
          photos: photos,
          status: ActivityDetailStatus.success,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: ActivityDetailStatus.failure, message: '載入照片失敗。'));
    }
  }
}
